# Smart Contract Migration

Versioning of smart contracts and migration of states from one version to another.

The main idea is to create a new contract and transfer the state from the old contract to it. Initially, the newly deployed contract will have an empty storage.

The process of moving to a new version can look like this:
1. Creating a new contract instance.
2. Transferring state or migrating data. This can be implemented in two ways:
   - **On-chain.** Migration using smart contracts.
   - **Off-chain.** Data collection from the old contract happens outside the blockchain. In the final stage, the collected data is written to the address of the new contract.
3. Update the address of the new contract for all contracts, services, and client applications. That is, replace the old address with the new one.
4. Convince users to switch to using the new contract. If it's a token contract, you also need to contact exchanges to abandon the old contract and use the new contract.

_Important!_ Data transfer is relatively simple and straightforward, but it can take a significant amount of time and require substantial gas costs. Also, remember that not all users will want to switch to the new version, so it is necessary to think about support measures for such users and old versions of contracts.

## On-chain
Migration using smart contracts. Such migration can be implemented in two ways:
- **At the user's expense.** When we ask the user to pay for the gas. We write some migration functionality that, when called, identifies the user and transfers functionality to the new contract.
- **At the migrator's expense.** We can do this at the protocol's expense and transfer states manually or with the help of another contract. In this case, the gas costs are covered by the company (owners of the contracts, protocol).

## Off-chain
Read all data from the blockchain. If there was a hack or failure, it is necessary to read up to the block with the failure. In this case, it is better to suspend the operation of the active smart contract (if possible). All public primitives are easily read. For private variables, it's a bit more complicated, but you can rely on events (Events) or use the ```getStorageAt()``` method to read such variables from storage. Arrays are also easily restored, as the number of elements is known. With mappings, it's much more complicated because the keys are not stored, so you can only rely on events (Event). After collecting all the data, it is necessary to write it to the new contract.

To restore data from events, it is necessary to understand how events are stored, indexed, and filtered outside the blockchain. This is well described [here](https://medium.com/mycrypto/understanding-event-logs-on-the-ethereum-blockchain-f4ae7ba50378).

One option for data collection is to use the [Google BigQuery API](https://cloud.google.com/blog/products/data-analytics/ethereum-bigquery-public-dataset-smart-contract-analytics) service.

For more details and examples, see [here](./big-query.md).

# Links

1. [How contract migration works](https://blog.trailofbits.com/2018/10/29/how-contract-migration-works/)
2. [EthersJS. Events. Logs and filtering](https://docs.ethers.org/v5/concepts/events/#events--filters)
3. [Solidity documentation. Events](https://docs.soliditylang.org/en/v0.8.18/contracts.html#events)
4. [Understanding event logs on the Ethereum blockchain](https://medium.com/mycrypto/understanding-event-logs-on-the-ethereum-blockchain-f4ae7ba50378)
