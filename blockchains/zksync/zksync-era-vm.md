# Era Virtual Machine (zkEVM)

**Author:** [Roman Yarlykov](https://github.com/rlkvrv) 🧐

_Important!_ The protocol team is actively working on improving compatibility, so some (or all) of the features described below may become outdated or lose relevance over time.

_Note:_ The opcodes below are described in more detail in the [official documentation](https://era.zksync.io/docs/reference/architecture/differences-with-ethereum.html#create-create2).

## CREATE, CREATE2

In zkEVM, deployment code (creationCode) and execution code (runtimeCode) are combined, which leads to adjustments in `datasize` and `dataoffset`.
There are a couple of key points to keep in mind here:

-   Check how the `bytecode` was obtained

If `create` or `create2` (via Yul) is explicitly used in the contract or library code (not through `new`), then the bytecode of the deployed contract must be obtained in the same contract or in another contract but through a call to `type(T).creationCode`.

The reason is that the `zksolc` compiler modifies the `bytecode` for the system contract `ContractDeployer`. If you take the `bytecode` obtained using the standard `solc`, it will not work. Examples are shown in the [documentation](https://era.zksync.io/docs/reference/architecture/differences-with-ethereum.html#create-create2:~:text=the%20bytecode%20itself.-,The%20code%20below%20should%20work%20as%20expected%3A,-MyContract%20a%20%3D).

Furthermore, the bytecode from `artifacts-zk`, which was precompiled using `zksolc`, will not work either. Here are two examples of bytecode for the same contract:

This one is taken from the `.json` file in the `artifacts-zk` folder.


```
0x0000008003000039000000400030043f0000000102200190000000120000c13d000000000201001900000009022001980000001a0000613d000000000101043b0000000a011001970000000b0110009c0000001a0000c13d0000000001000416000000000101004b0000001a0000c13d0000002a01000039000000800010043f0000000c010000410000001d0001042e0000000001000416000000000101004b0000001a0000c13d00000020010000390000010000100443000001200000044300000008010000410000001d0001042e00000000010000190000001e000104300000001c000004320000001d0001042e0000001e000104300000000000000000000000020000000000000000000000000000004000000100000000000000000000000000000000000000000000000000fffffffc000000000000000000000000ffffffff00000000000000000000000000000000000000000000000000000000f2c9ecd80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000008000000000000000000000000000000000000000000000000000000000000000000000000000000000fe656f219dacf5ce8b73b813cb9203d0f8598845700707ab67bcbac593600ec9
```

If you pass it to this function, the contract will not be created:

```solidity
    function createContract(bytes memory bytecode) external returns (address addr) {
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "Create: Failed on deploy");
    }
```

And here's the `bytecode` of the same contract obtained through a call to the `type(T).creationCode` function:

```
0x0000000000000000000000000000000000000000000000000000000000000000000000000100000fad4cfc3855d0e61bd17ecca835f2a2f01ddfdeb9a48d4d5ced5cf98a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
```

Obtained by calling the function:

```solidity
    function getCreationCode() external pure returns (bytes memory) {
        return type(Implementation).creationCode;
    }
```

This bytecode will work in the `createContract` function.

- Check if there is a call to `type(T).runtimeCode` in contracts.

It’s easier with runtimeCode. If somewhere in smart contracts there is a call to this function, the `zksolc` compiler will throw an error and the contracts will not be compiled.

- [Address derivation](https://era.zksync.io/docs/reference/architecture/differences-with-ethereum.html#address-derivation)

Since the zkSync bytecode is different from Ethereum, because zkSync uses a modified version of the EVM the address obtained from the bytecode hash will also be different. This means that the same bytecode deployed to Ethereum and zkSync will have different addresses, and the Ethereum address will still be accessible and not used by zkSync.

Important! In the future, parity with Ethereum in address derivation may be achieved.

## CALL, STATICCALL, DELEGATECALL

There are a couple of features here.

In Yul function calls like `call` (`call`, `callcode`, `delegatecall`, `staticcall`), you can pass the size of the returned data as the last argument, and if it differs from the actual `returndatasize` in EVM, you will get a `Panic` error. In zkEVM, this won't happen because memory is allocated only after calling another contract.

This is a relatively common case because after the Byzantium hard fork, you don't need to specify the size of the returned data (`outsize`).

The second feature is that Ether transfer under the hood is handled by the `MsgValueSimulator` smart contract, but developers don't need to do anything for it; all the logic with `msg.value` will work as in the regular EVM environment.

## MSTORE, MLOAD

There are three peculiarities here:

1. Memory growth is in bytes, not words. Remember that a word is 32 bytes. So, in the EVM, when we write a value at address 100 (`0x64`), due to the 4-byte offset relative to the word, memory will be extended by another 28 bytes, resulting in a final size of 160 bytes (`0x64` + `0x20` + `0x1c` = `0xa0`). In zkSync, this growth won't happen, and in a similar situation, when writing at address 100 (`0x64`), the memory size will be 132 bytes (`0x64` + `0x20` = `0x84`).

2. Due to the first peculiarity, the zksolc compiler can automatically remove unused memory, which would cause a "Panic" error in the EVM but not in zkEVM.

3. The gas cost when working with memory in the EVM has quadratic growth, while in zkEVM, this growth will be linear.

## CALLDATALOAD, CALLDATACOPY

In this section, it's simple: the size of calldata is limited to 2^32 bytes.

## RETURN, STOP

`immutable` variables will not be initialized if there is an assembly insertion with a call to `return(p, s)` or `stop()` in the constructor because it will override the array of `immutable` variables.

## TIMESTAMP, NUMBER, HASH

In zkSync Era, there are two concepts of blocks: L2 blocks and L1 packages. L2 blocks are blocks created at the L2 level (in the zkSync Era network). They are created every few seconds and are not included in the Ethereum chain. On the other hand, L1 packages are sequences of consecutive L2 blocks that contain all transactions in the same order, from the first block to the last block in the package.

Before this update, `block.timestamp`, `block.number`, and `block.hash` displayed data from L1 blocks. After the update, they will transmit data from L2 packages, and additional methods at the smart contract level will be added for L1 values (currently these methods are only available via the API).

## CODECOPY

Using CODECOPY with [new Yul codegen](https://docs.soliditylang.org/en/latest/ir-breaking-changes.html#solidity-ir-based-codegen-changes) will lead to a compilation error.

## EXTCODECOPY

EXTCODECOPY always results in a compilation error in the zkEVM compiler.

## DATASIZE, DATAOFFSET, DATACOPY

Contract deployment is handled by two parts of the zkEVM protocol: the compiler interface and the system contract called ContractDeployer. So, if deployment is done using Yul instead of `new`, this peculiarity must be taken into account.

## SETIMMUTABLE, LOADIMMUTABLE

In zkEVM, there is no access to the contract's bytecode, so `immutable` values (immutable variables) are simulated using system contracts. The deployment code (constructor) collects an array of immutable values in auxiliary memory and returns it as data to `ContractDeployer`. Then, the array is passed to a special system contract called `ImmutableSimulator`, where it is stored in a mapping with the contract's address as the key. To access immutable values from contract's executable code, contracts call `ImmutableSimulator` using the address and value index.

## COINBASE, DIFFICULTY, PREVRANDAO, BASEFEE, SELFDESTRUCT, CALLCODE, PC, CODESIZE

The changes are straightforward; see [here](https://era.zksync.io/docs/reference/architecture/differences-with-ethereum.html#coinbase).

## Libraries and Precompiles

### Libraries

In zkEVM, [libraries](https://era.zksync.io/docs/reference/architecture/differences-with-ethereum.html#libraries) work a bit differently than in the traditional EVM:

Embedding Libraries: The Solidity compiler optimizer must inline a library for it to be usable without deployment. Inlining means that the library's code is directly inserted into the bytecode of the contract, eliminating the need for separate deployment.

Deployed Libraries: If a library is not inlined and is deployed, its address must be specified in the project's configuration. During compilation, these addresses are used to replace placeholders in the Intermediate Representation (IR): linkersymbol in Yul or PUSHLIB in the outdated EVM assembly.

Compile-Time Linking: All library linking, which is the process of integrating library code with contract code, happens at compile-time. zkEVM does not support runtime linking, where library addresses are set during contract deployment rather than during compilation.

### Precompiles

Not all cryptographic functions available in the regular EVM are accessible in zkEVM. For example, functions for working with elliptic curves and RSA are currently unavailable, but adding support for elliptic curves is a development priority to enable using some protocols without code changes.

However, basic cryptographic operations such as recovering an address from a signature (ecrecover), hash functions like keccak256 and sha256, are already supported as precompiled functions. This means you can use them just like in the regular Ethereum network, and the compiler will automatically handle all calls to these functions for you.
