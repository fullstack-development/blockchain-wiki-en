# Intro

If you are completely new to blockchain development, I suggest starting from the very beginning and reading the article "How does Ethereum work?" by Preethi Kasireddy. However, even experienced developers may find it useful. I'm sure they can find interesting things in this article. 🙃

## Ethereum

Ethereum is a network where each participant stores a copy of the state of a single canonical computer called the Ethereum Virtual Machine (EVM). Any participant in the network can submit a request to this computer to perform arbitrary computations.

Requests for computations are called **transactions**. All transactions and the current state of the EVM are recorded on the blockchain, which is agreed upon by all network participants.

You can read more about Ethereum [here](https://ethereum.org/developers/docs/intro-to-ethereum/#what-is-ethereum).

You can read more about the anatomy of transactions [here](https://medium.com/remix-ide/the-anatomy-of-a-transaction-receipt-d935aacc9fcd).

## Account-based Model

We know that Ethereum, unlike Bitcoin, supports an [account-based strategy](https://jcliff.medium.com/intro-to-blockchain-utxo-vs-account-based-89b9a01cd4f5).

Accounts are used to store users' balances. Accounts and their balances are stored in a large table in the EVM. They are part of the overall state of the EVM.

An **account** entity contains the following fields:
1. **Balance**: The amount of ether in Wei.
2. **Nonce**: The transaction counter of this account.
3. **Storage Root**: Also known as the hash of the storage.
4. **Code Hash**: This hash refers to the **code** of the account in the virtual machine. Essentially, it is a 256-bit hash of the root of the "Merkle Patricia Tree" encoding the contents of the account's storage.

![Account](./images/account.png)

In the EVM, accounts are divided into two types:
1. External Owned Account (EOA)
2. Smart Contract

Both types of accounts can not only receive, store, and send ether but also interact with other smart contracts.

The **key difference** between "EOA" and "Smart Contract" accounts is as follows:
1. The EOA address is generated based on the user's private key, while the contract address is generated based on the deploying address, bytecode, and nonce.
2. The **code hash** and **storage root** fields are filled only for smart contract accounts. For EOA accounts, these fields are empty.

![Account Types](./images/account-types.png)

You can read more about accounts [here](https://ethereum.org/developers/docs/accounts/).

## EVM

The Ethereum Virtual Machine (EVM) is a global virtual computer whose state is stored by and agreed upon by each participant in the Ethereum network. Any participant can request the execution of arbitrary code in the EVM.

In terms of **opcodes**, the EVM is a Turing-complete [stack-based machine](https://en.wikipedia.org/wiki/Stack_machine) responsible for executing smart contract code.

A **smart contract** is a set of instructions. Each instruction represents code operations (with their convenient mnemonics, a kind of textual representation of the values assigned to them from 0 to 255). When the EVM executes a smart contract, it sequentially reads and executes each instruction.

## Simplified Architecture of EVM

We can simplify the internal structure of the EVM with the following diagram. Note that the objects **EVM code** and **Storage** are what the **code hash** and **storage** of an account refer to. I mentioned them in the previous section when talking about accounts.

![EVM](./images/evm.png)
*// Simple stack-based architecture of the EVM*

In the diagram above, we see two major areas:
- **Machine state** (volatile): This area contains non-permanent objects that will be created within the context of a call. A call context can be understood as the execution of any set of instructions obtained from the bytecode of a smart contract.
- **World state** (persistent): This area contains objects that are independent of the call context.

The **Machine state** includes:
- **PC (Program Counter)**: Determines which instruction from the **code** area of the EVM should be read next. The PC usually increments by one byte to point to the next instruction, except for a few commands like `JUMP` and `JUMPI`.
- **Stack**: A list of instructions in a smart contract. It can contain a maximum of **1024** instructions, and each instruction is 32 bytes in size. A new stack is created for each call within a context and is destroyed when the call context ends.
- **Memory**: Similar to the stack, it is created at the beginning of a call within a context and cleared when the call ends.

The **World state** includes:
- **Code**: This area stores the instructions. The code is the data bytes read, interpreted, and executed by the EVM during the execution of a smart contract. The code in this area is immutable. It is indicated by the abbreviation ROM (Read-only memory).
- **Storage**: The storage is responsible for storing the state of the blockchain. Essentially, it is a mapping of 32-byte slots to 32-byte values. The storage is persistent for a smart contract. Any value written by the code of a smart contract is saved after the call ends. Each contract has its own storage and cannot read or modify the storage of another contract.

For a simpler understanding, we can make the following analogies:
- **Stack**: Stores function arguments and executes operations.
- **Memory**: Short-term storage for declared variables within the context of a single function call.
- **Storage**: Long-term storage for data throughout the life of the blockchain. The data is accessible within any function call context and for external read operations.

You can view all of this from the perspective of the official implementation of the Ethereum protocol in Go:
1. [Opcodes](https://github.com/ethereum/go-ethereum/blob/master/core/vm/instructions.go)
2. [Stack](https://github.com/ethereum/go-ethereum/blob/master/core/vm/stack.go)
3. [Memory](https://github.com/ethereum/go-ethereum/blob/master/core/vm/memory.go)

## Instruction Execution

Remember that the EVM is a stack machine, and the stack plays a key role here. The diagram below illustrates the execution of a set of instructions.

![Execution Model](./images/execution-model.png)

This algorithm can be described as follows:
1. Within the call context, the following **machine state** objects are created: **memory**, **stack**, and **program counter**.
2. The **program counter** receives the command to initialize the instruction execution.
3. Instructions are fetched from the **EVM code** and parsed into operations (**opcodes**).
4. Each operation is pushed onto the **stack**.
5. Operations in the **stack** begin execution.
6. The execution of each operation may involve the **storage** or **memory**.

_Important!_ In this diagram, we omit the gas check. Each opcode has a gas cost. Gas helps maintain the security of the Ethereum network. Gas calculation is beyond the scope of this diagram.

## Key Points

> Solidity code is transformed into bytecode, which consists of opcodes.

> There are two types of accounts: EOA and smart contracts. Only smart contracts have code.

> Understanding how the EVM works. **Memory** and **Stack** are created for each call context. **EVM code** is immutable. **Storage** is persistent but can be modified.

## Links

1. [Ethereum Virtual Machine](https://ethereum.org/en/developers/docs/evm/)
2. [About the EVM](https://www.evm.codes/about)
3. [Interesting Illustration Collection](https://takenobu-hs.github.io/downloads/ethereum_evm_illustrated.pdf)
