CHain link brownie installation guide and repo - https://github.com/smartcontractkit/chainlink-brownie-contracts

`forge install smartcontractkit/chainlink-brownie-contracts `



The raffles contract is inheriting VRFConsumerBaseV2Plus whose constructor requires an address for vrfCoordinator , so we provide that in the following manner
`constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator) VRFConsumerBaseV2Plus(vrfCoordinator) `