// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mock/LinkToken.sol";

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

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 0.03 ether; // 0.03 link

    function fundSubscription() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getNetworkConfigByChainId()
            .vrfCoordinator;
        uint256 subsciptionId = helperConfig
            .getNetworkConfigByChainId()
            .subscriptionId;
        address linkToken = helperConfig.getNetworkConfigByChainId().link;
        fundSubscription(vrfCoordinator, subsciptionId, linkToken);
    }

    function fundSubscription(
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
                FUND_AMOUNT
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

    function run() external {}
}

contract AddVRFConsumer is Script{
    function run() external {}

    
}
