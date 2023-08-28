# Contract Migration

Versioning smart contracts and migrating states from one version to another.

The main idea is to create a new contract and transfer the state from the old contract to the new one. Initially, the newly deployed contract will have an empty storage.

The process of transitioning to a new version can be done as follows:
1. Create a new instance of the contract.
2. Transfer the state or migrate the data. This can be done in two ways:
   - **On-chain migration:** Migration using smart contracts.
   - **Off-chain migration:** Gathering data from the old contract outside the blockchain, and finally, storing the collected data at the address of the new contract.
3. Update the address of the new contract for all contracts, services, and client applications. In other words, replace the old address with the new one.
4. Encourage users to switch to using the new contract. If it is a token contract, you also need to reach out to exchanges to deprecate the old contract and use the new contract instead.

_Important!_ Data migration is a relatively straightforward operation, but it can take a significant amount of time and require significant gas costs. It's also important to note that not all users will want to migrate to the new version, so support measures for such users and old contract versions should be carefully considered.

## On-chain Migration
Migration using smart contracts can be implemented in two ways:
- **User-Paid Migration:** When we ask the user to pay for the gas. We implement a migration functionality that determines the user upon invocation and transfers the functionality to the new contract.
- **Migrator-Paid Migration:** We can perform the migration on behalf of the protocol by manually transferring the states or using another contract. In this case, the gas costs are covered by the company (contract owners, protocol).

## Off-chain Migration
Read all data from the blockchain. If there was a hack or failure, it is necessary to read the data until the block with the failure. If possible, it's recommended to pause the operation of the current smart contract. All public primitives can be easily read. For private variables, it's a bit more challenging, but you can rely on events or use the `getStorageAt()` method to read such variables from storage. Arrays can also be easily restored since the number of elements is known. However, with mappings, it's more complex as the keys are not stored, so you can only rely on events. After collecting all the data, it needs to be stored in the new contract.

To recover data from events, you need to understand how events are stored, indexed, and filtered outside of the blockchain. This is well described [here](https://medium.com/mycrypto/understanding-event-logs-on-the-ethereum-blockchain-f4ae7ba50378).

One way to collect data is by using the [Google BigQuery API](https://cloud.google.com/blog/products/data-analytics/ethereum-bigquery-public-dataset-smart-contract-analytics) service.

For more details and examples, refer to [here](./big-quiery.md).

# Links

1. [How contract migration works](https://blog.trailofbits.com/2018/10/29/how-contract-migration-works/)
2. [EthersJS. Events. Logs and filtering](https://docs.ethers.io/v5/api/providers/provider/#Provider--events)
3. [Solidity documentation. Events](https://docs.soliditylang.org/en/v0.8.18/contracts.html#events)
4. [Understanding event logs on the Ethereum blockchain](https://medium.com/mycrypto/understanding-event-logs-on-the-ethereum-blockchain-f4ae7ba50378)
