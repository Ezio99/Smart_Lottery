// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Raffle} from "src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

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
        vm.roll(block.number+1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
        //Assert
    }
}
