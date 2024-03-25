# Smart Contract Upgrades

**Author:** [Pavel Naydanov](https://github.com/PavelNaydanov) 🕵️‍♂️

Smart contracts on the Ethereum network are immutable by default. However, for some scenarios, it is desirable to have the ability to modify them.

Upgrading a smart contract is the modification of the contract's business logic while preserving the state of the contract. You can update the codebase, while the contract address, state, and balance should remain unchanged.

**Why is this necessary?**

Firstly, errors or potential vulnerabilities that need to be corrected may be discovered in a smart contract.

Secondly, there may be a scenario where enhancements or new functionalities are needed.

_Important!_ Control over updates should be decentralized to avoid malicious actions.

The executable code can be changed in several ways:

1. Creating multiple versions of smart contracts and migrating the state from the old contract to the new contract. [More details](./method-1/readme.md).
2. Creating multiple smart contracts for separate storage of state and business logic. [More details](./method-2/readme.md).
3. Using **Proxy patterns** to delegate function calls from an immutable proxy contract to a mutable logic contract. [More details](./method-3/readme.md).
4. Using **Strategy pattern**. Creating an immutable main contract that interacts with flexible auxiliary contracts and relies on them to perform certain functions. [More details](./method-4/readme.md).
5. Using **Diamond pattern** to delegate function calls from a proxy contract to logic contracts. [More details](./method-5/readme.md).

## Pros and Cons of Updating Smart Contracts

### Pros

1. Provides the ability to fix vulnerabilities after deployment. It could even be argued (although controversially) that this enhances security because vulnerabilities can be fixed.
2. Provides the ability to add functionality to the contract logic after deployment.
3. Opens up new possibilities for designing and building a decentralized system with isolation of individual parts of the application and delineation of access and control.

### Cons
1. Cancels the blockchain idea of code immutability. Therefore, from a security perspective, this is bad. Users must trust developers not to change smart contracts arbitrarily.
2. To gain user trust, additional layers of protection are needed, for example, a DAO to protect against unauthorized changes.
3. Implementing the possibility of updating a contract can significantly increase its complexity.
4. Unsafe access control or centralization in smart contracts can make it easier for attackers to perform unauthorized updates.

## Links
1. [Upgrading smart contracts](https://ethereum.org/en/developers/docs/smart-contracts/upgrading/)
2. [Upgradable Smart Contracts: What They Are and How To Deploy Your Own](https://blog.chain.link/upgradable-smart-contracts/)
3. [Upgrading smart contracts by OpenZeppelin](https://docs.openzeppelin.com/learn/upgrading-smart-contracts#whats-in-an-upgrade)
4. [yAcademy Proxies Research](https://proxies.yacademy.dev/)
