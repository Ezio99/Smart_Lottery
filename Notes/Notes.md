CHain link brownie installation guide and repo - https://github.com/smartcontractkit/chainlink-brownie-contracts

`forge install smartcontractkit/chainlink-brownie-contracts `



The raffles contract is inheriting VRFConsumerBaseV2Plus whose constructor requires an address for vrfCoordinator , so we provide that in the following manner
`constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator) VRFConsumerBaseV2Plus(vrfCoordinator) `

`
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
`

Here we craft a request to be sent to the VRF coordinator

`uint256 requestId = s_vrfCoordinator.requestRandomWords(request);`
On sending it we get a request id to track our request

The VRFCooridinator then hits our contract's `rawFulfillRandomWords()` (inherited from VRFConsumerBaseV2Plus) which then calls our overrided `fulfillRandomWords` function to perform any action with the returned random word (number).


Coding pattern : CEI (Checks, Effects (State changes), Interactions (External contract interactions)) - Try following this structure in your functions

Also a best practice would be to emit events before interactions and after effects

`forge coverage --report debug > coverage.txt` - gives a report of coverage

Fuzz testing
If we have a test where a parameter could be any random number we can try using fuzz testing
e.g.  function testFulFillRandomWordsOnlyCalledAfterPerformUpKeep(uint256 randomRequestId), when we pass randomRequestId as a param foundry will try running the test with different randomnumbers in that parameter
By default its 256 times
When we run we see -  testFulFillRandomWordsOnlyCalledAfterPerformUpKeep(uint256) (runs: 256, μ: 82375, ~: 82375) (It tested 256 times with different random numbers)

We can change this by specifying the number of runs in foundry.toml
`[fuzz]
runs=1000`

