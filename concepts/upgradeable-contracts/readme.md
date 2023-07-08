# Smart Contract Upgrades

By default, smart contracts on the Ethereum network are immutable. However, there are scenarios where it is desirable to have the ability to modify them.

A smart contract upgrade involves changing the business logic of the contract while preserving the contract's state. The codebase can be updated, while the contract's address, state, and balance remain unchanged.

**Why is it needed?**
Firstly, smart contracts may contain bugs or potential vulnerabilities that need to be fixed.

Secondly, there may be a need to introduce improvements or new features.

_Important!_ Control over upgrades should be decentralized to avoid malicious actions.

There are several ways to modify the executable code:

1. Creating multiple versions of smart contracts and migrating the state from the old contract to the new contract. [Learn more](./method-1/readme.md).
2. Creating multiple smart contracts to separate state and business logic. [Learn more](./method-2/readme.md).
3. Using **Proxy patterns** to delegate function calls from an immutable proxy contract to a mutable logic contract. [Learn more](./method-3/readme.md).
4. Using the **Strategy pattern**. Creating an immutable main contract that interacts with flexible auxiliary contracts and relies on them to perform certain functions. [Learn more](./method-4/readme.md).
5. Using the **Diamond pattern** to delegate function calls from a proxy contract to logical contracts. [Learn more](./method-5/readme.md).

## Pros and Cons of Smart Contract Upgrades

### Pros

1. Allows for vulnerability fixes post-deployment. It can be argued that this enhances security by enabling vulnerability patches.
2. Enables adding functionality to the contract's logic after deployment.
3. Opens up new possibilities for designing and building decentralized systems with isolation of different parts of the application and access control.

### Cons

1. Contradicts the immutability principle of blockchain. From a security standpoint, this is not ideal, as users have to trust developers not to make arbitrary changes to smart contracts.
2. To gain user trust, additional layers of protection, such as a DAO, may be needed to guard against unauthorized changes.
3. Allowing for contract upgrades can significantly increase the complexity of the contract.
4. Insecure access control or centralization in smart contracts can make it easier for malicious actors to perform unauthorized upgrades.

## Links
1. [Upgrading smart contracts](https://ethereum.org/en/developers/docs/smart-contracts/upgrading/)
2. [Upgradable Smart Contracts: What They Are and How To Deploy Your Own](https://blog.chain.link/upgradable-smart-contracts/)
3. [Upgrading smart contracts by OpenZeppelin](https://docs.openzeppelin.com/learn/upgrading-smart-contracts#whats-in-an-upgrade)
