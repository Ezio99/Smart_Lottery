// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Raffle} from "src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    //Have to copy events we want to test
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    modifier raffleEntered() {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getNetworkConfigByChainId();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        ) = (
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(Raffle.RaffleState.OPEN == raffle.getRaffleState());
    }

    function testRaffleRevertsIfNotEnoughEthSent() public {
        //Arrange
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        //Act
        raffle.enterRaffle{value: entranceFee - 1}();
        //Assert
    }

    function testRaffleTracksPlayers() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        assertEq(raffle.getPlayerFromIndex(0), PLAYER, "Player not tracked");
    }

    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //only 1 indexed arg
        vm.expectEmit(true, false, false, false, address(raffle));
        //This is the event we are expecting to be emitted by contract raffle
        emit RaffleEntered(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
    }

    function testPlayersCantEnterWhenRaffleNotOpen() public {
        //Arrange
        vm.startPrank(PLAYER);
        //Setting up Playerupkeep to pass so that raffle is calculating
        raffle.enterRaffle{value: entranceFee}();
        //Sets block timestamp
        vm.warp(block.timestamp + interval + 1);
        //Sets block number
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
        //Assert
    }

    /* Check upkeep tests */

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.startPrank(PLAYER);
        // No player entered so no balance
        //Sets block timestamp
        vm.warp(block.timestamp + interval + 1);
        //Sets block number
        vm.roll(block.number + 1);
        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upKeepNeeded);
        vm.stopPrank();
    }

    function testCheckUpkeepReturnsFalseWhenRaffleIsNotOpen()
        public
        raffleEntered
    {
        //Arrange
        //Closes raffle
        raffle.performUpkeep("");

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upKeepNeeded);
    }

    /* Perform upkeep tests */
    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue()
        public
        raffleEntered
    {
        //Arrange
        //Act
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 currentPlayers = 0;
        Raffle.RaffleState currentState = raffle.getRaffleState();
        vm.startPrank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        currentBalance += entranceFee;
        currentPlayers++;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                currentBalance,
                currentPlayers,
                currentState
            )
        );
        //Act
        raffle.performUpkeep("");
        vm.stopPrank();
    }

    //Get data from events into test
    function testPerformUpKeepUpdatesRaffleStateAndEmitsEvent()
        public
        raffleEntered
    {
        //Arrange

        //Act
        //Keep track of logs/events emitted by next function
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // string memory sample = string(abi.encode(entries[0].topics[0]));
        // console.log(sample);
        bytes32 requestId = entries[1].topics[1];

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assertEq(
            uint256(raffleState),
            uint256(Raffle.RaffleState.CALCULATING_WINNER),
            "Raffle state not updated to calculating winner"
        );
    }

    /* Fulfill Random Words tests */

    //Stateless Fuzz test
    //When we run we see testFulFillRandomWordsOnlyCalledAfterPerformUpKeep(uint256) (runs: 256, μ: 82375, ~: 82375)
    //It tested 256 times with different random numbers
    function testFulFillRandomWordsOnlyCalledAfterPerformUpKeep(
        uint256 randomRequestId
    ) public raffleEntered {
        //Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    //One giant end-to-end test
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
