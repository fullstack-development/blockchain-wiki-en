# Strategy pattern

The strategy pattern directly influences the classic strategy pattern. Its main idea is to choose a behavior or action algorithm based on runtime conditions.

A simple example can be a class that performs input data validation. Different validation algorithms are applied using the strategy pattern, which employs different data validation algorithms. You can learn more about the strategy pattern [here](https://en.wikipedia.org/wiki/Strategy_pattern).

Applying the strategy pattern to Ethereum development involves creating a smart contract that invokes functions from other contracts. The main contract in this case contains the core business logic but interacts with other smart contracts ("helper contracts") to perform specific functions. This main contract also stores the address for each helper contract and can switch between different implementations of the satellite contract.

You can always create a new helper contract and configure the main contract with the new address. This allows for changing strategies (introducing new logic or, in other words, updating the code) for the smart contract.

_Important!_ The main drawback is that this pattern is primarily useful for deploying minor updates. Additionally, if the main contract is compromised (has been hacked), this method of upgrading is no longer suitable.

## Examples

1. A good example of a simple strategy pattern is Compound, which has different implementations of [RateModel](https://github.com/compound-finance/compound-protocol/blob/v2.3/contracts/InterestRateModel.sol) for interest rate calculation, and its CToken contract can [switch between them](https://github.com/compound-finance/compound-protocol/blob/bcf0bc7b00e289f9b661a0ae934626e018188040/contracts/CToken.sol#L1358-L1366).

2. A slightly more complex implementation of the strategy pattern is "Pluggable Modules." In this approach, the main contract provides a set of core immutable functions and allows registering new modules. These modules add new functions to be called within the main contract. This pattern can be found in the [Gnosis Safe](https://github.com/safe-global/safe-contracts/blob/v1.1.1/contracts/base/ModuleManager.sol#L35-L46) wallet. Users can add new modules to their own wallets, and then each contract call to the wallet will request the execution of a specific function from a specific module.

_Important!_ It's important to note that Pluggable Modules also require the main contract to be error-free. Any errors in the module management itself cannot be fixed by adding new modules to this scheme.

## Links
1. [Strategy pattern](https://en.wikipedia.org/wiki/Strategy_pattern)
