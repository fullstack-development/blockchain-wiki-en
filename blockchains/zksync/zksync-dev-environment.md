# zkSync Era Development Environment

**Author:** [Roman Yarlykov](https://github.com/rlkvrv) 🧐

Due to its unique virtual machine, zkEVM, and the complexities of working with zero-knowledge proofs, developing smart contracts for zkSync differs from traditional EVM development.

Always refer to the latest documentation. For instance, check these sections:

-   [Differences from Ethereum](https://era.zksync.io/docs/reference/architecture/differences-with-ethereum.html)
-   [System contracts](https://era.zksync.io/docs/reference/architecture/system-contracts.html)
-   [Security and best practices](https://era.zksync.io/docs/dev/building-on-zksync/best-practices.html)

## Tools

### Foundry

As of this writing, support for the [Foundry](https://book.getfoundry.sh/) framework is somewhat limited. For the latest information, check this [repository](https://github.com/matter-labs/foundry-zksync).

An alpha version has been released with some functionality for forge and cast, called zkforge and zkcast respectively.

Capabilities of forge (more details [here](https://github.com/matter-labs/foundry-zksync/blob/main/docs/dev/zksync/zkforge-usage.md)):

-   You can compile Solidity contracts using `zksolc` (`zk-compile`, `zk-build`), and the output files are placed in the `zkout` folder (seems like the zk prefix will be everywhere 🙄). The maximum compiler version is 0.8.19.
-   You can deploy contracts using `zkforge zkcreate`, `zkforge zk-deploy`.
-   Very simple tests are supported.

Full development and testing of smart contracts using forge are not yet feasible, as cheat codes and complex types of testing (like invariant and fuzzing) do not work.

Capabilities of cast (more details [here](https://github.com/matter-labs/foundry-zksync/blob/main/docs/dev/zksync/zkcast-usage.md)):

-   Getting blockchain information (chain id, client, balance (L2), gas price, latest block).
-   Interacting with deployed contracts, making `call` and `send` (`zk-send`) operations.
-   Actions with the bridge - depositing/withdrawing funds to and from L2 (`zkcast zk-deposit`, `zkcast zk-send --withdraw`).

There is also some functionality with abstract accounts, more details [here](https://github.com/matter-labs/foundry-zksync/blob/main/docs/dev/zksync/zksync-aa-usage.md).

Forge remappings do not work, so you can only use absolute imports in contracts. There's no capability for writing scripts. The `forge debug` module does not work!

_Important!_ Forge and cast modules need to be compiled and built manually, so installing [rust](https://www.rust-lang.org/tools/install) is also required for project deployment.

### zksync-cli

A small console tool that allows you to create projects for Hardhat and Vyper (more details [here](https://github.com/dutterbutter/zksync-devKit/blob/main/docs/tooling/zksync-cli.md)).

### Hardhat

It is created using `zksync-cli`; you need to select a Hardhat + Solidity project. See this [repository](https://github.com/dutterbutter/zksync-devKit/blob/main/docs/test-and-debug/hardhat.md) for setting up a Hardhat project.

_Important!_ Requires Node.js version 18 or higher.

```shell
$ npx zksync-cli@latest create-project test-project
```

The project will be configured for zk-evm (with settings for zkSync Era test environments).

To compile smart contracts:

```shell
$ yarn compile
```

To separately launch an In-Memory node:

```sell
$ era_test_node run
```

Now you can deploy to the local node or in fork mode:

```shell
$ yarn deploy --network inMemoryNode
```

### Online IDE

Compiling smart contracts in Remix is not possible due to the need for `zksolc`, but another online IDE can be used - [Atlas zk](https://app.atlaszk.com/ide). It supports other blockchains as well.

Pros:
- Foundry tests with cheat codes are functional.
- Libraries can be installed.

Cons:
- Very limited documentation.
- Many aspects are not obvious.
- Unclear which compiler is used under the hood.
- Uncertain if deployment to both zk and regular blockchains is possible.

---

## Testing Environments

Currently, there are three environments for testing and debugging: Testnet and two local environments (Docker, In-Memory node).

|                          | Runs Locally | Rich Accounts | Fast Setup | Debugging |
| ------------------------ | :----------: | :-----------: | :--------: | :-------: |
| **Testnet**              |      ❌      |      ❌       |     ✅     |    ❌     |
| **local-setup (Docker)** |      ✅      |      ✅       |     ✅     |    ✅     |
| **In-Memory Node**       |      ✅      |      ✅       |     ✅     |    ✅     |

### Testnet

Goerli is used as Layer 1 for the [Testnet](https://goerli.explorer.zksync.io/). To transfer tokens from Goerli to zkSync Era testnet, you can use the [official bridge](https://portal.txsync.io/bridge/?network=era-goerli). Alternatively, you can use the faucet from [chainstack](https://faucet.chainstack.com/zksync-testnet-faucet) (which requires their API key), or other [faucets](https://era.zksync.io/docs/reference/troubleshooting/faq.html#how-do-i-request-funds-for-testnet).

### Dockerized Local Setup

A comprehensive simulation of the zkSync Era network, including a Postgres database, a local Geth node (acting as Layer 1), and a zkSync node. Suitable for thorough simulations and testing that require interaction between L1 and L2. Offers more flexible configuration than an in-memory node.
More details [here](https://github.com/dutterbutter/zksync-devKit/blob/main/docs/test-and-debug/dockerized-l1-l2-nodes.md).

### In-Memory Node

The In-Memory node is similar to Anvil or Hardhat node for local use. Supports forking state from various networks, including the mainnet and testnet. Best for developing smart contracts that do not require interaction with L1. Also used for replaying transactions in forked network mode.

| 🚫 Limitations                                       | ✅ Features                                                                       |
| ---------------------------------------------------- | --------------------------------------------------------------------------------- |
| No connection between L1 and L2.                     | Can fork state from the mainnet, testnet, or custom networks.                     |
| Some APIs are not yet implemented.                   | Can replay existing transactions from the mainnet or testnet.                     |
| No access to historical data.                        | Uses local bootloaders and system contracts.                                      |
| Only one transaction per L1 batch transaction allowed. | Operates deterministically in non-forking mode.                                   |
| Fixed values returned for zk Gas estimation.         | Quick setup with pre-configured 'rich' accounts.                                  |
| Redeployment requires clearing MetaMask cache.       | Supports debugging through console.log in Hardhat.                                |
|                                                      | Allows ABI function names and event names using openchain.                        |

_Important!_ The In-Memory node is in alpha development and does not support all blockchain functionalities. For final testing, the Dockerized Local Setup or testnet is recommended.

An example of working with an In-Memory node can be seen in [this video](https://www.youtube.com/watch?v=tDFA8cnHoCY) starting from the 5th hour.

### Comparison of Local Environment Features

| Feature                                            |   In-Memory Node   | Dockerized Local Setup |
| -------------------------------------------------- | :---------------: | :-------------------: |
| Quick Start                                        |         ✅         |           ❌          |
| Forking State Support                              |         ✅         |           ❌          |
| Debugging via console.log                          |         ✅         |           ❌          |
| Detailed Call Traces                               |         ✅         |           ❌          |
| Pre-configured 'Rich' Accounts                     |         ✅         |           ✅          |
| Replay Existing Transactions                       |         ✅         |           ❌          |
| Fast Execution of Integration Tests                |         ✅         |           ❌          |
| Interaction between Layer 1 and Layer 2            |         ❌         |           ✅          |
| Multiple Transactions in a Single Batch            |         ❌         |           ✅          |
| Full API Set                                       | ❌ (Basic Only)    |           ✅          |
| WebSocket Support                                  |         ❌         |           ✅          |

### Testing Environment Configuration

|                      | RPC Url                        | chainID | Layer 1 |
| -------------------- | ------------------------------ | ------- | ------- |
| Testnet              | https://testnet.era.zksync.dev | 280     | Goerli  |
| local-setup (Docker) | http://localhost:3050          | 270     | Geth    |
| In-Memory Node       | http://localhost:8011          | 260     | 🟠      |
