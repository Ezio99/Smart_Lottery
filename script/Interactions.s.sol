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
        address account = helperConfig.getNetworkConfigByChainId().account;
        return createVRFSubscription(vrfCoordinator, account);
    }

    function createVRFSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256) {
        console.log("Creating VRF Subscription on: ", vrfCoordinator);
        console.log("Creating VRF Subscription on chain id: ", block.chainid);
        //This account is the sender
        vm.startBroadcast(account);
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
    //Fund for subscription, has no relation to raffle balance etc.
    uint256 public constant FUND_AMOUNT = 0.05 ether; // 0.05 link

    function fundVRFSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getNetworkConfigByChainId()
            .vrfCoordinator;
        uint256 subsciptionId = helperConfig
            .getNetworkConfigByChainId()
            .subscriptionId;
        address linkToken = helperConfig.getNetworkConfigByChainId().link;
        address account = helperConfig.getNetworkConfigByChainId().account;
        fundVRFSubscription(vrfCoordinator, subsciptionId, linkToken, account);
    }

    function fundVRFSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        address account
    ) public {
        console.log("Funding VRF Subscription coordinator:", vrfCoordinator);
        console.log("Funding VRF Subscription id:", subscriptionId);
        console.log("Funding VRF Subscription on chain id:", block.chainid);

        if (block.chainid == LOCAL_ANVIL_CHAIN_ID) {
            vm.startBroadcast();
            // Not new, using the existing deployed mock contract
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT * 10000000
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
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
        address account = helperConfig.getNetworkConfigByChainId().account;
        addVRFConsumer(
            mostRecentlyDeployedContract,
            vrfCoordinator,
            subsciptionId,
            account
        );
    }

    function addVRFConsumer(
        address contractToAddToVRF,
        address vrfCoordinator,
        uint256 subscriptionId,
        address account
    ) public {
        console.log(
            "Adding VRF Consumer to contract: ",
            contractToAddToVRF,
            " on chain id: ",
            block.chainid
        );
        console.log("Adding consumer using VRF Coordinator: ", vrfCoordinator);
        console.log("Adding consumer using Subscription ID: ", subscriptionId);

        vm.startBroadcast(account);
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
