# Data Separation

Creating multiple smart contracts for separate storage of state and business logic.

This approach can be called a **data separation** pattern. It involves users interacting with a logic contract, while data is stored in a separate storage contract.

The logic contract contains code that executes when users interact with the application. It also contains the address of the storage contract and interacts with it to get and set data.

The storage contract contains the state associated with the logic smart contract, such as balances and user addresses.

_Important!_ Only the designated logic contract should write data to the storage contract and no one else.

By default, the storage contract should be immutable, but it has the capability to change the logic contract to any other contract.

## Examples
In the folder ``` /contracts ```, there are three contracts. ``` TokenLogic ``` is a contract that lacks state variables. All state variables are moved to the ```BalanceStorage``` and ```TotalSupplyStorage``` contracts. These two contracts have public methods for managing states. These public methods can only be called by the designated logic contract.

More details on the logic contract [here.](./contracts/TokenLogic.sol)
More details on storage contract 1 [here.](./contracts/BalanceStorage.sol)
More details on storage contract 2 [here.](./contracts/TotalSupplyStorage.sol)
