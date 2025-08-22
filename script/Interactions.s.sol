// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mock/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

//Programmatic way to create a VRF subscription, fund it, and add a consumer to it.
//Can also be done manually on the website

contract CreateVRFSubscription is Script {
    function createVRFSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getNetworkConfigByChainId()
            .vrfCoordinator;

        return createVRFSubscription(vrfCoordinator);
    }

    function createVRFSubscription(
        address vrfCoordinator
    ) public returns (uint256) {
        console.log("Creating VRF Subscription on: ", vrfCoordinator);
        console.log("Creating VRF Subscription on chain id: ", block.chainid);
        vm.startBroadcast();
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Created VRF Subscription with ID: ", subscriptionId);

        return subscriptionId;
    }

    function run() external {
        createVRFSubscriptionUsingConfig();
    }
}

contract FundVRFSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // 0.03 link

    function fundVRFSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getNetworkConfigByChainId()
            .vrfCoordinator;
        uint256 subsciptionId = helperConfig
            .getNetworkConfigByChainId()
            .subscriptionId;
        address linkToken = helperConfig.getNetworkConfigByChainId().link;
        fundVRFSubscription(vrfCoordinator, subsciptionId, linkToken);
    }

    function fundVRFSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken
    ) public {
        console.log("Funding VRF Subscription coordinator:", vrfCoordinator);
        console.log("Funding VRF Subscription id:", subscriptionId);
        console.log("Funding VRF Subscription on chain id:", block.chainid);

        if (block.chainid == LOCAL_ANVIL_CHAIN_ID) {
            vm.startBroadcast();
            // Not new, using the existing deployed mock contract
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT*100
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundVRFSubscriptionUsingConfig();
    }
}

contract AddVRFConsumer is Script {
    function addVRFConsumerUsingConfig(
        address mostRecentlyDeployedContract
    ) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subsciptionId = helperConfig
            .getNetworkConfigByChainId()
            .subscriptionId;
        address vrfCoordinator = helperConfig
            .getNetworkConfigByChainId()
            .vrfCoordinator;
        addVRFConsumer(
            mostRecentlyDeployedContract,
            vrfCoordinator,
            subsciptionId
        );
    }

    function addVRFConsumer(
        address contractToAddToVRF,
        address vrfCoordinator,
        uint256 subscriptionId
    ) public {
        console.log(
            "Adding VRF Consumer to contract: ",
            contractToAddToVRF,
            " on chain id: ",
            block.chainid
        );
        console.log("Using VRF Coordinator: ", vrfCoordinator);
        console.log("Using Subscription ID: ", subscriptionId);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            contractToAddToVRF
        );
        vm.stopBroadcast();
        console.log(
            "Added VRF Consumer to contract: ",
            contractToAddToVRF,
            " successfully."
        ); 
    }

    function run() external {
        address mostRecentlyDeployedContract = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);
        addVRFConsumerUsingConfig(mostRecentlyDeployedContract);
    }
}
