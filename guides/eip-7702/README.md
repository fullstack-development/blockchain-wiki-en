# Guide to Creating a Wallet for Use with EIP-7702

**Author:** [Pavel Naydanov](https://github.com/PavelNaydanov) 🕵️‍♂️

[EIP-7702: Set Code for EOAs](https://eips.ethereum.org/EIPS/eip-7702) is a standard that proposes adding a **new type** of transaction that allows attaching smart contract code to Externally Owned Accounts (EOAs).

In this guide, we’ll implement the smart contract [Wallet.sol](./contracts/src/Wallet.sol), which can be used to attach to an EOA account.

The `Wallet.sol` smart contract must meet the following requirements:
- support batch operations (e.g., approve + call another smart contract in a single transaction)
- be able to manage any assets stored on the EOA
- interact with other smart contracts
- support gasless operations, meaning a trusted third party can execute the operation

>_Important!_ The **Wallet** smart contract is implemented for educational purposes and is not intended for production use.

## How does EIP-7702 work?

Traditionally, in the Ethereum blockchain, there are two types of accounts:
- **EOA** (Externally Owned Accounts). Can initiate transactions but does not store code.
- **Smart Contract**. Stores code as a set of instructions but cannot initiate transactions.

Both types of accounts have their own address on the network.

According to EIP-7702, a new type of transaction sent to the blockchain will attach a smart contract to an EOA.

After attaching the smart contract, the EOA changes its behavior. Any calls to the EOA will be delegated to the attached smart contract for execution. In this way, the EOA gains behavior very similar to that of a smart contract account.

![](./images/eip-7702-flow.png)

Technically, the **code** field of the EOA entity is updated on the blockchain. It stores the address of the attached smart contract with a special prefix (**0xef0100** || address). The prefix is a sort of magic value that helps distinguish it as a delegate address rather than actual smart contract bytecode.

## Getting Started with Creating Wallet.sol

**Requirements**

1. Basic knowledge of blockchain development.
2. Experience with Solidity (the programming language for smart contracts on EVM-compatible blockchains).
3. Basic conceptual understanding of EIP-7702.

> If you’ve never written smart contracts before, I strongly recommend starting with simpler examples before trying to follow this guide.

To create the `Wallet.sol` smart contract, I’ll be using [Foundry](https://getfoundry.sh/). At the time of writing this guide, [Hardhat](https://hardhat.org/) does not support working with EIP-7702.

To get started:
1. [Install Foundry](https://getfoundry.sh/introduction/installation)
2. [Set up a basic project](https://getfoundry.sh/introduction/getting-started)
3. Create a simple smart contract `Wallet.sol`
    ```solidity
    // SPDX-License-Identifier: MIT
    pragma solidity 0.8.30;

    contract Wallet {
      // This is where we’ll write the code
      ...
    }
    ```

Now we’re ready to build! 😎

## Attaching Code to an EOA for Testing

Even at this stage, we can attach the `Wallet.sol` smart contract to an EOA, and all calls to the EOA will be executed on the EOA.

We’ll do this in tests. Tests in Foundry are written in Solidity, and special cheat codes are used to simulate attaching to an EOA.

```solidity
function signDelegation(address implementation, uint256 privateKey)
    external
    returns (SignedDelegation memory signedDelegation);

function attachDelegation(SignedDelegation calldata signedDelegation) external;

function signAndAttachDelegation(address implementation, uint256 privateKey)
    external
    returns (SignedDelegation memory signedDelegation);
```

To make EIP-7702 work, you need to ensure that the code is compiled for an EVM version no lower than **"prague"**. This can be set in `foundry.toml`. This is required because EIP-7702 was introduced with the Pectra upgrade (Prague + Electra).

```solidity
// foundry.toml
evm_version = "prague"
```

Thus, the simplest example of a test that attaches code to an EOA would look like this:

```solidity
function test_attachCode() external {
    // We check whether the EOA `user` has code (the `user` is created using the `vm.addr` cheat code)
    console.logBytes(user.addr.code); // 0x

    // We simulate the user signing a transaction to attach the code
    Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

    vm.startBroadcast(operator.key);

    // We send a transaction to attach the code to `user`. Note that this is done by the `operator`, not the `user`. The operator is created using the built-in `makeAccount()` function.
    vm.attachDelegation(signedDelegation);

    vm.stopBroadcast();

    console.logBytes(user.addr.code); //0xef0100...
}
```

More details about testing can be found in the [official documentation](https://getfoundry.sh/reference/cheatcodes/sign-delegation#signdelegation) Foundry.

## Supporting Receipt of Various Assets by the Wallet Smart Contract

An EOA changes its behavior after attaching a smart contract. From that moment, when any asset is sent to the EOA’s address, it will behave like a smart contract.

Accordingly, to be able to receive native currency in the smart contract, you need to implement the `receive()` function, which allows the EOA to receive native tokens like Ether.

```solidity
contract Wallet {
    receive() external payable {}
}
```

The same goes for ERC-721 and ERC-1155 tokens, which require the implementation of *callback functions* in the smart contract to receive the token.

```solidity
function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
    return this.onERC721Received.selector;
}

function onERC1155Received(
    address,
    address,
    uint256,
    uint256,
    bytes memory
) public virtual override returns (bytes4) {
    return this.onERC1155Received.selector;
}
```

To do this, we’ll install the OpenZeppelin library and inherit the Wallet from two smart contracts: [ERC1155Holder](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Holder.sol) and [ERC721Holder.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol)

Run the command: `forge install https://github.com/OpenZeppelin/openzeppelin-contracts` to install OpenZeppelin, then configure the *remappings* and update the `Wallet.sol` smart contract code as follows.

```solidity
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Wallet is ERC1155Holder, ERC721Holder {
    receive() external payable {}
}
```

Now the smart contract can receive ERC-721, ERC-1155, and native currency. Write tests to verify this — you have all the knowledge to do it. As an experiment, you can also try adding support for the [ERC-777](https://eips.ethereum.org/EIPS/eip-777) token.

An example of my tests can be found in the file [Wallet.t.sol](./contracts/test/wallet/Wallet.t.sol).

## Executing Batch Operations

This is a common task, and many Abstract Account providers have already solved it in their smart contracts.  
So here, you can look to smart contracts from the [delegation framework](https://github.com/MetaMask/delegation-framework/blob/main/src/EIP7702/EIP7702DeleGatorCore.sol) by MetaMask or the [reference implementation](https://github.com/erc7579/erc7579-implementation/tree/main) of the [ERC-7579: Minimal Modular Smart Accounts](https://eips.ethereum.org/EIPS/eip-7579) standard.

ERC-7579 was developed as an alternative implementation to [ERC-6900](https://eips.ethereum.org/EIPS/eip-6900) by Alchemy, and was created by a number of companies including OKX, Biconomy, ZeroDev, Rhinestone, and others.

You can easily get lost in the history of account abstraction, but the key point here is that for batch operations, all these teams use another standard called [ERC-7821: Minimal Batch Executor Interface](https://eips.ethereum.org/EIPS/eip-7821).

The standard proposes implementing the `execute()` functions:

```solidity
function execute(bytes32 mode, bytes calldata executionData)
    external
    payable;
```

The ERC-7579 implementation defines the parameters of the `execute()` function in the [ModeLib.sol](https://github.com/erc7579/erc7579-implementation/blob/main/src/lib/ModeLib.sol) library. We’ll use it as well to avoid reinventing the wheel.

**Parameters of the `execute()` function**

`bytes32 mode` describes the following parameters of the operation:
| CALLTYPE  | EXECTYPE  |   UNUSED   | ModeSelector  |  ModePayload  |
|-----------|-----------|------------|---------------|---------------|
| 1 byte    | 1 byte    |   4 bytes  | 4 bytes       |   22 bytes    |

- **CALLTYPE** defines the type of call: single, batch, static, or delegatecall  
- **EXECTYPE** defines execution behavior. By default, the transaction will revert if the call data causes a revert. There’s also a "try" mode that wraps the call in a `try/catch` structure — meaning if a revert happens inside the call, the transaction will still succeed.  
- **UNUSED** reserved bytes for future use  
- **ModeSelector** is optional and defines special behavior for the account  
- **ModePayload** contains the data needed to execute the `executionData`

`executionData` is a byte array that encodes a call to an address using the following structure:

```solidity
struct Call {
    address to;
    uint256 value;
    bytes data;
}
```

Depending on the CALLTYPE, `executionData` can encode either a single operation or a batch of operations.

**Adding the `execute()` Function to `Wallet.sol`**

Now it’s time to add the `execute()` function to the `Wallet.sol` smart contract.

```solidity
import {ModeLib} from "@erc7579/lib/ModeLib.sol";

contract Wallet is ERC1155Holder, ERC721Holder {
    using ModeLib for ModeCode;

    /**
     * @notice Executing an operation on the account
     * @param mode Execution mode of the encoded data
     * @param executionCalldata Encoded data for execution
     */
    function execute(ModeCode mode, bytes calldata executionCalldata) external payable {
        _execute(mode, executionCalldata);
    }
}
```

The main execution logic will be implemented in the private function `_execute()`.

Basically, we could implement a low-level **call** here and come up with our own logic for executing batch operations.

But instead, we’ll follow the ERC-7579 approach:

```solidity
import {ModeLib} from "@erc7579/lib/ModeLib.sol";

contract Wallet is ERC1155Holder, ERC721Holder {
    using ModeLib for ModeCode;

    /**
     * @notice Executing an operation on the account
     * @param mode Execution mode of the encoded data
     * @param executionCalldata Encoded data for execution
     */
    function execute(ModeCode mode, bytes calldata executionCalldata) external payable {
        _execute(mode, executionCalldata);
    }

    // We actively use the ModeLib library
    function _execute(ModeCode mode, bytes calldata executionCalldata) private {
        (CallType callType, ExecType execType,,) = mode.decode();

        // If a batch of operations is encoded
        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions_ = executionCalldata.decodeBatch();
            if (execType == EXECTYPE_DEFAULT) {
                _execute(executions_);
            } else if (execType == EXECTYPE_TRY) {
                _tryExecute(executions_);
            } else {
                revert UnsupportedExecType(execType);
            }
        // If a single operation is encoded
        } else if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) = executionCalldata.decodeSingle();
            if (execType == EXECTYPE_DEFAULT) {
                _execute(target, value, callData);
            } else if (execType == EXECTYPE_TRY) {
                bytes[] memory returnData_ = new bytes[](1);
                bool success_;
                (success_, returnData_[0]) = _tryExecute(target, value, callData);
                if (!success_) emit TryExecuteUnsuccessful(0, returnData_[0]);
            } else {
                revert UnsupportedExecType(execType);
            }
        } else {
            revert UnsupportedCallType(callType);
        }

        emit Executed(msg.sender, mode, executionCalldata);
    }
}
```

The functions `_execute(executions_)`, `_tryExecute(executions_)`, `_execute(target, value, callData)`, and `_tryExecute(target, value, callData)` are taken from the ERC-7579 implementation.  
They are implemented in a helper smart contract called [ExecutionHelper.sol](https://github.com/erc7579/erc7579-implementation/blob/main/src/core/ExecutionHelper.sol).

All we need to do is inherit from `ExecutionHelper.sol`. Additionally, we’ll use another library from their repo — [ExecutionLib.sol](https://github.com/erc7579/erc7579-implementation/blob/main/src/lib/ExecutionLib.sol) — to decode the **executionCalldata** parameter.

```solidity
import {ExecutionHelper} from "@erc7579/core/ExecutionHelper.sol";
import {ExecutionLib} from "@erc7579/lib/ExecutionLib.sol";
import {ModeLib} from "@erc7579/lib/ModeLib.sol";

contract Wallet is ExecutionHelper, ERC1155Holder, ERC721Holder {
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;

    function execute(ModeCode mode, bytes calldata executionCalldata) external payable {
        _execute(mode, executionCalldata);
    }

    function _execute(ModeCode mode, bytes calldata executionCalldata) private {
        ...
    }
}
```

At this stage, we have the ability to execute both batch operations and regular operations. It's worth clarifying that an operation can mean asset management (like transferring a token) stored on the EOA, or making calls to other smart contracts.

Even now, we can encode an approve + smart contract call via `execute()` to perform them within a single transaction.

## Modifier onlySelf

**But!** Right now, there's a direct risk to a user's assets if they attach the `Wallet.sol` smart contract.  
The `execute()` function is public and can be called by anyone — which means someone could drain the user's assets.

Let’s add the `onlySelf` modifier to ensure that only the EOA itself can make the call.

```solidity
...

contract Wallet is ExecutionHelper, ERC1155Holder, ERC721Holder {
    ...

    modifier onlySelf() {
        if (msg.sender != address(this)) {
            revert OnlySelf();
        }

        _;
    }

    function execute(ModeCode mode, bytes calldata executionCalldata) external payable onlySelf {
        _execute(mode, executionCalldata);
    }

    ...
}
```

The check ```msg.sender != address(this)``` might seem strange to a developer unfamiliar with EIP-7702.  
But this is exactly what allows us to verify that the call is being made by the EOA to itself, since in a delegated call, `address(this)` will point to the account it's attached to. So, `msg.sender` must be the EOA account itself.

## Gasless Execution

In this section, we’ll implement an `execute()` function that accepts a signature from the EOA account that attached the `Wallet.sol` smart contract. This way, anyone with a valid signature from the EOA will be able to execute operations on its account.

> Let’s pause here for a quick note. In practice, gasless execution is much more complex. Often, the entity executing the transaction on behalf of the user wants compensation for their work — for example, in an ERC-20 token. That’s why most AA providers still implement gasless flows using the battle-tested ERC-4337.
>
> In our case, let’s assume a simplified scenario: some random protocol is performing transactions for the user free of charge. At the same time, it can’t do anything with the user’s account without their signature.

Let’s add another `execute()` function as an overload in `Wallet.sol`. This version will accept a signature as a parameter.

```solidity
...

contract Wallet is ExecutionHelper, ERC1155Holder, ERC721Holder {
    struct ExecutionRequest {
      ModeCode mode;
      bytes executionCalldata;
      bytes32 salt;
      uint64 deadline;
    }

    mapping(bytes32 salt => bool isUsed) _isSaltUsed;

    ...

    function execute(ExecutionRequest calldata request, bytes calldata signature) external payable {
        WalletValidator.checkRequest(request, signature, _isSaltUsed);

        _isSaltUsed[request.salt] = true; // Note that the signature is used to protect against replay attacks
        _execute(request.mode, request.executionCalldata);
    }
}
```

In the `ExecutionRequest` struct, we’ve wrapped the parameters required to execute a user operation, and added a `salt` (as a unique identifier for the signature) and a `deadline` (the expiration time after which the signature becomes invalid).

I intentionally used `salt` instead of `nonce` because I wanted the user to be able to issue multiple signatures at the same time, and even after using one, the others would still remain valid.

Ideally, we could use an additional hash of the `ExecutionRequest` structure to identify the signature, but for an educational smart contract, that would be overkill.

All the magic lies in the signature verification, which is moved into a separate library — [WalletValidator.sol](./contracts/src/libraries/WalletValidator.sol) — and can be implemented however you like.

My version looks as follows:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ModeCode} from "@erc7579/lib/ModeLib.sol";

struct ExecutionRequest {
    ModeCode mode;
    bytes executionCalldata;
    bytes32 salt;
    uint64 deadline;
}

library WalletValidator {
    bytes32 public constant WALLET_OPERATION_TYPEHASH = keccak256(
        abi.encodePacked(
            "WalletSignature(bytes32 mode,bytes executionCalldata,bytes32 salt,uint64 deadline,address sender)"
        )
    );

    // Entry point
    function checkRequest(
        ExecutionRequest memory request,
        bytes calldata signature,
        mapping(bytes32 salt => bool isUsed) storage isSaltUsed
    ) internal view {
        // Check that the signature has not expired
        if (block.timestamp > request.deadline) {
            revert RequestExpired();
        }

        // Check that the signature hasn’t been used
        if (isSaltUsed[request.salt]) {
            revert SaltAlreadyUsed();
        }

        // Check that the signature was given by the owner of the EOA
        bool isValid = _isValidSignature(request, signature);
        if (!isValid) {
            revert InvalidSignature();
        }
    }

    function _isValidSignature(ExecutionRequest memory request, bytes calldata signature) private view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), _getDigest(request)));
        return ECDSA.recover(digest, signature) == address(this);
    }

    function _domainSeparator() private view returns (bytes32) {
        uint256 chainId;

        assembly {
            chainId := chainid()
        }

        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Wallet"),
                keccak256("1"),
                chainId,
                address(this)
            )
        );
    }

    function _getDigest(ExecutionRequest memory request) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                WALLET_OPERATION_TYPEHASH,
                request.mode,
                keccak256(request.executionCalldata),
                request.salt,
                request.deadline,
                msg.sender
            )
        );
    }
}
```

## Storage Collision

Before we added the `execute()` function for gasless execution, we didn’t use any storage in the `Wallet.sol` smart contract. Now, however, we have a mapping `_isSaltUsed`.

But it’s important to understand that EIP-7702 operates in the context of the EOA. This means that once a smart contract is attached for delegation, **we’ll be working with the storage of the EOA itself**.

An EOA can both attach a smart contract for delegate calls and later detach it. After that, nothing stops it from attaching a different smart contract — but at that point, the first storage slot might already contain leftover data from the previous contract.

This kind of storage collision issue can be solved using another standard: [ERC-7201: Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201). This standard defines a special way to organize storage access in any smart contract, and it’s widely used in OpenZeppelin and proxy-based contracts.

To handle storage properly, I’ve created a separate helper contract: [StorageHelper.sol](./contracts/src/utils/StorageHelper.sol).

```solidity
abstract contract StorageHelper {
    // We encode the slot where the `Storage` struct will be located. All data will be written only into this struct
    bytes32 private constant _STORAGE_LOCATION = 0xa3c7fb5ee0843e27cf3d06e1a75ae4fe5241c2d945da24d804adf753e5643900;

    // We move our mapping into this struct
    struct Storage {
        mapping(bytes32 salt => bool isUsed) isSaltUsed;
    }

    // A helper function that will provide access to our storage
    function _getStorage() internal pure virtual returns (Storage storage $) {
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}
```

This way, our `Wallet.sol` smart contract inherits from `StorageHelper` and updates how it interacts with storage.

```solidity
import {StorageHelper} from "./utils/StorageHelper.sol";
...

contract Wallet is ExecutionHelper, StorageHelper, ERC1155Holder, ERC721Holder {
    ...

    function execute(ExecutionRequest calldata request, bytes calldata signature) external payable {
        Storage storage $ = _getStorage();
        WalletValidator.checkRequest(request, signature, $.isSaltUsed, $.isSaltCancelled);

        $.isSaltUsed[request.salt] = true;
        _execute(request.mode, request.executionCalldata);
    }
}
```

I borrowed the dollar-sign syntax from OpenZeppelin.

## Practice

You’ve probably noticed that the user currently has no way to “change their mind” after giving a signature to a third party. In the current implementation, only the `deadline` protects the user — once it passes, the signature becomes invalid and the operation can't be executed.

But that’s not enough. So, think it through and implement a `cancelSignature()` function. This function should only be callable by the EOA — and no one else.

_Hint!_ The `cancelSignature()` function should accept the order’s `salt` and store it in a separate mapping.  
When validating the signature, make sure to check that it hasn’t been canceled.

## ERC-165 and ERC-1271

Since our `Wallet.sol` smart contract is likely to interact with various protocols, we need to declare which interfaces it supports. To do this, we’ll use [ERC-165: Standard Interface Detection](https://eips.ethereum.org/EIPS/eip-165).

Also, to let other protocols verify whether a signature is valid and truly comes from our EOA with the attached `Wallet.sol` code, we’ll implement support for [ERC-1271: Standard Signature Validation Method for Contracts](https://eips.ethereum.org/EIPS/eip-1271).

```solidity
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
...

contract Wallet is IERC165, IERC1271, ExecutionHelper, StorageHelper, ERC1155Holder, ERC721Holder {
    ...

    // We declare all interfaces that the smart contract provides.
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165, ERC1155Holder) returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC1271).interfaceId || interfaceId == type(IERC7821).interfaceId;
    }

    // Allows verification of whether the signature was truly issued by our EOA.
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        override(IWallet, IERC1271)
        returns (bytes4 magicValue)
    {
        bool isValid = WalletValidator.isValidERC1271Signature(hash, signature);
        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }
        return 0xffffffff;
    }
}
```

It’s important to understand that if the Wallet is updated, any new interfaces must be added to the `supportsInterface()` function.

## Conclusion

> Once again, I want to emphasize that `Wallet.sol` is not production-ready — it’s an educational example. The code has not been audited.

And that’s it! We’ve implemented a minimal working example of the `Wallet.sol` smart contract, which can be attached to an EOA according to EIP-7702. Most importantly, the contract is useful for batch operations and follows modern best practices. Adding new logic — like social recovery, pseudo-multisig, and so on — is straightforward.

Full example of the smart contract: [Wallet.sol](./contracts/src/Wallet.sol)  
Complete test suite: [Wallet.t.sol](./contracts/test/wallet/Wallet.t.sol)

Supporting smart contracts can be found nearby in the [/contracts](./contracts/) folder. As for setting up the Foundry project — that part you’ll need to do yourself. The path is made by walking it!

## Links

1. [EIP-7702: Set Code for EOAs](https://eips.ethereum.org/EIPS/eip-7702)
2. [ERC-7579: Minimal Modular Smart Accounts](https://eips.ethereum.org/EIPS/eip-7579)
3. [ERC-7821: Minimal Batch Executor Interface](https://eips.ethereum.org/EIPS/eip-7821)
4. [ERC-7201: Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201)
5. [EIP-7702: DeleGatorCore by MetaMask](https://github.com/MetaMask/delegation-framework/blob/main/src/EIP7702/EIP7702DeleGatorCore.sol)
6. [EIP-7702. Guide for testing in Foundry](https://getfoundry.sh/reference/cheatcodes/sign-delegation#signdelegation) 
