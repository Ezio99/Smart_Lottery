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
    error Raffle__UpKeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        RaffleState raffleState
    );

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
    event RequestedRaffleWinner(uint256 indexed requestId);

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

    // Chainlink Automation functions
    //When should winner be picked?
    /**
     *
     * @dev This function is called by the Chainlink Automation Node to check if upkeep is needed (time to pick winner).
     * The following conditions must be met:
     * 1. Enough time has passed since the last winner was picked.
     * 2. The raffle must be in the OPEN state.
     * 3. The contract has ETH. (has players)
     * 4. Implicitly, the subscription must be funded with LINK.
     * @return upkeepNeeded
     * @return
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = (address(this).balance > 0);
        bool hasPlayers = (s_players.length > 0);
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);

        return (upkeepNeeded, "");
    }

    //1. Get a random number  -Done
    //2. Use that random number to pick a winner -Done
    //3. Be automatically called after a certain time period - Use chain link automation (chain link keepers)
    function performUpkeep(bytes calldata /* performData */) external {
        //Checks
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                s_raffleState
            );
        }
        // //Check if enough time has passed
        // if (block.timestamp - s_lastTimeStamp < i_interval) {
        //     revert Raffle__NotEnoughTimePassedToPickWinner();
        // }

        //Effects
        s_raffleState = RaffleState.CALCULATING_WINNER;

        //Get Random Number
        //We cant get one from blockhash because it is a deterministic function
        //We will use ChainLink VRF to get a random
        // 1. Request RNG

        //Interactions
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
        //Returns a requestId but we don't need it here
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        //VRFCoordinator also emits an event but we emit our own to make it easy to track and test
        emit RequestedRaffleWinner(requestId);

       
    }

    //Internal because the external contract calls raw fulfillRandomWords which then calls this
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        //Effects
        uint256 winnerIndex = randomWords[0] % s_players.length;
        s_recentWinner = s_players[winnerIndex];

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        emit WinnerPicked(s_recentWinner);

        //Interactions
        //Transfer the balance to the winner
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferToWinnerFailed();
        }
    }

    /** Getter funcs */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayerFromIndex(uint256 index) external view returns (address) {
        return s_players[index];
    }
}
