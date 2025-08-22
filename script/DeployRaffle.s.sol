// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateVRFSubscription, FundVRFSubscription, AddVRFConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getNetworkConfigByChainId();

        //Create subscription if it doesn't exist
        if (networkConfig.subscriptionId == 0) {
            CreateVRFSubscription createSubscription = new CreateVRFSubscription();
            networkConfig.subscriptionId = createSubscription
                .createVRFSubscription(networkConfig.vrfCoordinator);
        }

        //Fund subscription
        FundVRFSubscription fundSubscription = new FundVRFSubscription();
        fundSubscription.fundVRFSubscription(
            networkConfig.vrfCoordinator,
            networkConfig.subscriptionId,
            networkConfig.link
        );

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        //Add consumer to subscription (Latest deployed raffle contract)
        //Dont need to broadcast as broadcast is in addVRFConsumer
        AddVRFConsumer addConsumer = new AddVRFConsumer();
        addConsumer.addVRFConsumer(
            address(raffle),
            networkConfig.vrfCoordinator,
            networkConfig.subscriptionId
        );

        return (raffle, helperConfig);
    }
}
