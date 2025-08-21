// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract HelperConfig is Script {
    error HelperConfig__ChainIdNotSupported(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
    }

    uint256 private constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant LOCAL_ANVIL_CHAIN_ID = 31337;

    /* VRF Mocks */
    uint96 private constant MOCK_BASE_FEE = 0.25 ether;
    uint96 private constant MOCK_GAS_PRICE = 1e9;
    int256 private constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getNetworkConfigByChainId() public returns (NetworkConfig memory) {
        if (networkConfigs[block.chainid].vrfCoordinator != address(0)) {
            return networkConfigs[block.chainid];
        } else if (block.chainid == LOCAL_ANVIL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        }

        revert HelperConfig__ChainIdNotSupported(block.chainid);
    }

    //The keyword memory is required here because your function returns a struct
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether, //1e16 wei
                interval: 30, //30 seconds
                // from https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-sepolia-testnet
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                subscriptionId: 0
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        //Deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock mockVrfCorrdinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE,
            MOCK_WEI_PER_UNIT_LINK
        );
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16 wei
            interval: 30, //30 seconds
            // from https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-sepolia-testnet
            vrfCoordinator: address(mockVrfCorrdinator),
            //doesnt matter for local
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0
        });

        return localNetworkConfig;
    }
}
