## **Data Separation** refers to the approach of creating multiple smart contracts to separate the storage of data from the business logic.

In this approach, users interact with a logical contract, while the data is stored in a separate storage contract.

The logical contract contains the code that executes when users interact with the application. It also includes the address of the storage contract and interacts with it to retrieve and set data.

The storage contract holds the state related to the logical smart contract, such as user balances and addresses.

## **Important!** Only the specific logic contract should be able to write data to the storage contract, and no one else.

By default, the storage contract should be immutable, but it provides the capability to change the logic contract to any other contract.

In the ```/contracts``` folder, there are three contracts. ```TokenLogic``` is a contract that does not have any state variables. All state variables are moved to the ```BalanceStorage``` and ```TotalSupplyStorage``` contracts. These two contracts have public methods for managing the states. These public methods can only be called by the set logic contract.

For more details, you can refer to the example logic contract [here](./contracts/TokenLogic.sol).
For more details, you can refer to the example storage contract 1 [here](./contracts/BalanceStorage.sol).
For more details, you can refer to the example storage contract 2 [here](./contracts/TotalSupplyStorage.sol).
