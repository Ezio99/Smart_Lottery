// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A smart contract for managing raffles.
 * @author Vaibhav Deb
 * @notice This contract allows users to create and participate in raffles.
 * @dev Implements ChainLink VRFv2.5 for RNG
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__NotEnoughTimePassedToPickWinner();
    error Raffle__TransferToWinnerFailed();
    error Raffle__NotOpen();

    /*Type Declarations */
    enum RaffleState {
        OPEN, //0
        CALCULATING_WINNER //1
    }

    /* State Variables */
    uint256 private immutable i_entranceFee;

    // Payable address array to store players
    //Payable because we want to send ETH to winner
    address payable[] private s_players;

    //@dev Duration of lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    RaffleState private s_raffleState;

    address private s_recentWinner;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }

        // Not very gas efficient to use require and string
        // require(msg.value >= i_entranceFee, "Did not enough ETH sent!");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_players.push(payable(msg.sender));

        // Emit an event to log the entry
        //A good rule of thumb is to emit events for state changes
        emit RaffleEntered(msg.sender);
    }

    //1. Get a random number
    //2. Use that random number to pick a winner
    //3. Be automatically called after a certain time period
    function pickWinner() external {
        //Chec if enough time has passed
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Raffle__NotEnoughTimePassedToPickWinner();
        }

        s_raffleState = RaffleState.CALCULATING_WINNER;

        //Get Random Number
        //We cant get one from blockhash because it is a deterministic function
        //We will use ChainLink VRF to get a random
        // 1. Request RNG

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        //s_vrfCoordinator is inherited from VRFConsumerBaseV2Plus
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        // 2. Get RNG
    }

    //Internal because the external contract calls raw fulfillRandomWords which then calls this
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        s_recentWinner = s_players[winnerIndex];

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);

        //Transfer the balance to the winner
        (bool success, ) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferToWinnerFailed();
        }

        emit WinnerPicked(s_recentWinner);

    }

    /** Getter funcs */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
