# EIP-7702: Set Code for EOAs

**Author:** [Pavel Naydanov](https://github.com/PavelNaydanov) 🕵️‍♂️

**EIP-7702: Set Code for EOAs** is a standard that proposes adding a **new transaction type** according to the specification described in [EIP-2718: Typed Transaction Envelope](https://eips.ethereum.org/EIPS/eip-2718), which would allow attaching smart contract code to Externally Owned Accounts (EOAs).

EIP-7702 is the next step in account abstraction as part of the Ethereum upgrade called ["Pectra"](https://ethereum.org/en/roadmap/pectra/).

Attaching a smart contract to an EOA allows executing code in its context. For example, it can use the user's balance to send funds to another user. Technically, this is implemented using the delegate call mechanism (`delegateCall`), but applied not to a smart contract, rather to an EOA.

![](./images/eip-7702-flow.png)

The account entity in Ethereum has always had a **code** field. Previously, this field was empty for EOAs, while for smart contracts it contained bytecode.

Now, for EOAs, the **code** field stores the address of the attached smart contract with a special prefix (**0xef0100** || address). Basically, the prefix is a kind of magic value that clearly indicates this is a delegate address, not smart contract bytecode.

Globally, EIP-7702 is aimed at improving application UX through minor changes within Ethereum. With the help of this standard, the following tasks can be addressed:
- **Batching transactions**: Combining multiple atomic operations into a single transaction. For example, `approve` and `transfer` in one transaction. This is something wallet users have been waiting for a long time.
- **Gasless transactions or sponsorship**: Gas fees can be paid by a third-party account or in ERC-20 tokens. This improves the experience for new wallet users who don’t yet have native tokens to pay for gas.
- **Role and access management**: Granting permissions to third parties to manage the account.
- **Recovery mechanisms**: Can include asset withdrawal or a backup address that can take control of the wallet’s assets.
- **And so on.**

## Transaction for attaching code

In this section, we’ll break down the structure of a transaction that attaches a smart contract to an EOA.

The transaction body is similar to any other transaction type according to [EIP-2718: Typed Transaction Envelope](https://eips.ethereum.org/EIPS/eip-2718):

- **TransactionType** – the transaction type is `0x04`.
- **TransactionPayload** – the encoded data differs by including a new field called `authorization_list`.

![](./images/eip-7702-set-eoa-code-tx.png)

The `authorization_list` field is a tuple defined as:

```js
authorization_list = [[
  chain_id, // The network identifier for which the delegation is valid
  address, // The address of the smart contract to which the call will be delegated
  nonce, // The current nonce of the EOA
  y_parity, // The signature data of the EOA account
  r, // The signature data of the EOA account
  s // The signature data of the EOA account
], ...]
```

Like any other transaction, the user can sign it, and it can be sent to the network later.

That’s why it’s important to understand that if the `chain_id` in the `authorization_list` is set to 0, it means the EOA allows the transaction to be used on all EVM-compatible networks that support EIP-7702.

**Interesting points**

1. For the signature that authorizes attaching to an EOA to be valid across multiple networks, the `nonce` must be the same in those networks. Otherwise, the signature will be invalid on some of them. This can be convenient when creating a new account — the owner can provide just one signature to attach code to the EOA across multiple networks at once.

2. The `authorization_list` field in the transaction can contain a list of data signed by multiple different EOAs. At the same time, the transaction can be initiated by a third party, which allows implementing gasless smart contract code attachment to multiple EOAs.

3. To make your EOA regular again (detach the smart contract), it's enough to set the `address` field in the `authorization_list` to 0.

4. If one of the items in the `authorization_list` is invalid, it is skipped, the valid items are applied, and the transaction is not reverted.

## How it works for the user

The user signs a message to add code to their account, which includes: the chain ID, a one-time nonce, and the delegate address. Nothing else depends on them.

This message can be delivered to the network with a transaction, and after that, delegation will start working.

Technically, the EOA doesn’t disappear and nothing happens to it. The user’s funds are not moved, and the user still controls the account’s private key. That’s why it’s still important to keep it safe and not let it be compromised.

Attaching code to the account will give the user more functionality.

You can already see this in action — for example, MetaMask has integrated EIP-7702 into its "[Smart Account](https://support.metamask.io/configure/accounts/what-is-a-smart-account/)" feature. For this, MetaMask developed its own smart contracts, so when a user switches their EOA to a Smart Account, they delegate execution to MetaMask’s smart contracts.

![](./images/eip-7702-metamask-switch-page.png)
![](./images/eip-7702-metamask-confirm-set-code.png)

## Non-obvious points for smart contracts

In this section, we'll go over the nuances of how EIP-7702 works. We'll write working examples using Foundry, which provides the necessary cheatcodes for testing.

```solidity
function signDelegation(address implementation, uint256 privateKey)
    external
    returns (SignedDelegation memory signedDelegation);

function attachDelegation(SignedDelegation calldata signedDelegation) external;

function signAndAttachDelegation(address implementation, uint256 privateKey)
    external
    returns (SignedDelegation memory signedDelegation);
```

These cheatcodes allow you to sign a code attachment transaction for an EOA (`signDelegation`) and send transactions to the network (`attachDelegation`) directly in tests.

To make sure EIP-7702 works, you need to ensure that the code is compiled for an EVM version no lower than "prague". This can be set in `foundry.toml`.

```solidity
// foundry.toml
evm_version = "prague"
```

Thus, the simplest example that attaches code to an EOA in Foundry tests would look like this:

```solidity
// Declare `StdCheats.Account public user;`
...

function test_attachCode() external {
    // Check if the EOA `user` has any code
    console.logBytes(user.addr.code); // 0x

    // Simulate the user signing a transaction to attach code
    Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

    vm.startBroadcast(operator.key);

    // Send the transaction to attach code to `user`. Note that this is done by the `operator`, not the `user`
    vm.attachDelegation(signedDelegation);

    vm.stopBroadcast();

    console.logBytes(user.addr.code); //0xef01005615deb798bb3e4dfa0139dfa1b3d433cc23b72f
}
```

Basically, the test implements just two steps to attach the code.

![](./images/eip-7702-foundry-test-flow.png)

Full test example `test_attachCode` can be found in [Delegation.t.sol](./contracts/attachCode/Delegation.t.sol).

### Storage of the delegated smart contract

The storage of a delegated smart contract is not accessible through calls made by the EOA.

Moreover, the constructor of such a smart contract cannot be called in the context of an EOA, so it's not possible to set data in storage via the constructor from the EOA’s context.

Changes to storage variables during a call remain in the context of the EOA. In other words, the storage of the smart contract itself will not be modified.

To test how storage works, we’ll implement a simple smart contract [Delegation.sol](./contracts/).

```solidity
contract Delegation {
    uint256 private _value;

    constructor(uint256 initialValue) {
        _value = initialValue;
    }

    function setValue(uint256 newValue) external {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }
}
```

In the test, we’ll work with the smart contract’s storage both directly and in the context of the EOA:

```solidity
// Delegation.t.sol
function test_workWithStorage(uint256 value) external {
    // Attach the `Delegation` smart contract code to the `user` EOA
    ...

    // Step 1. Verify that the `user` storage is empty and the `delegation` smart contract has no data set

    // Calling `getValue` through `user` will return 0, since the `user`'s storage is empty
    assertEq(Delegation(user.addr).getValue(), 0);
    // Calling `getValue` through `delegation` will return `_INITIAL_VALUE`, since `delegation`'s storage hasn’t changed and was set via the constructor during deployment
    assertEq(delegation.getValue(), _INITIAL_VALUE);

    // Step 2. Set a value in the user's storage
    Delegation(user.addr).setValue(value);

    // Calling `getValue` through `user` will return the set `value`
    assertEq(Delegation(user.addr).getValue(), value);
    // Calling `getValue` through `delegation` will return `_INITIAL_VALUE`, as the storage hasn't changed
    assertEq(delegation.getValue(), _INITIAL_VALUE);
}
```

The test shows that the constructor of the `Delegation` smart contract didn’t set anything in the EOA’s storage. In general, the EOA's storage and the smart contract's storage are separate.

![](./images/eip-7702-storage-example.png)

Full example of the `test_workWithStorage` test can be found in [Delegation.t.sol](./contracts/storageExample/Delegation.sol).

_Important!_ In fact, the constructor of the smart contract can still be used for `immutable` variables, since such variables become part of the contract’s bytecode after deployment.

```solidity
contract Delegation {
    uint256 immutable private _value;

    constructor(uint256 value) {
        _value = value;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }
}
```

A validation test might look like this:

```solidity
function test_workWithStorage(uint256 initialValue) external {
    StdCheats.Account memory user = makeAccount("User");
    StdCheats.Account memory operator = makeAccount("Operator");

    // Deploy the `Delegation` smart contract
    Delegation delegation = new Delegation(initialValue);

    // Attach the `Delegation` smart contract code to the user
    vm.startBroadcast(operator.key);
    vm.signAndAttachDelegation(address(delegation), user.key);
    vm.stopBroadcast();

    // Verify that the user's storage is not empty
    assertEq(Delegation(user.addr).getValue(), initialValue);
}
```

### Checks like msg.sender == tx.origin

Previously, smart contracts used the condition `tx.origin == msg.sender` for two purposes:
1. To verify that the code is being executed on behalf of an EOA, since `tx.origin` cannot be a smart contract.
2. To protect against reentrancy. This is based on the assumption that a second call must come from a smart contract.

_Important!_ If a delegated smart contract, in the context of an EOA, makes a call to another smart contract, then `msg.sender` equals the EOA’s address. And in this case, `tx.origin` still equals `msg.sender`.

![](./images/eip-7702-sender-and-origin-case-1.png)

The diagram shows the call flow from the user to the `Target` smart contract through the attached `Delegation` smart contract. The user signs a call to their own address with their private key, execution is delegated to the `Delegation` smart contract, which then calls the `Target` smart contract. In all cases, the user's address is equal to both `msg.sender` and `tx.origin`.

But now, how can we bypass the condition so that `tx.origin` changes? EIP-7702 allows for any smart contract implementation. This means it can be called by any other account, unless restricted otherwise. As a result, `msg.sender` will not match `tx.origin` if the original call comes from an external EOA.

![](./images/eip-7702-sender-and-origin-case-2.png)

In the diagram, the operator signs the transaction with their private key, which does not match the user’s address. As a result, `tx.origin` will not be equal to `msg.sender`.

This is easy to verify. You’ll need a smart contract like [Target](./contracts/condition/Delegation.sol), which allows setting a value only if `tx.origin != msg.sender`.

```solidity
// Target
function setValue(uint256 newValue) external {
    if (tx.origin == msg.sender) {
        revert EOACallIsNotAllowed();
    }

    _value = newValue;
}
```

We will attach the [Delegation](./contracts/condition/Delegation.sol) smart contract to the EOA, which will make a `setValue()` call to the `Target` smart contract.

```solidity
contract Delegation {
    function setValue(address target, uint256 value) external {
        Target(target).setValue(value);
    }
}
```

The verification test will look as follows:

```solidity
function test_checkCondition(uint256 value) external {
    Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

    // Simulate the user calling the target contract directly — the transaction reverts
    vm.expectRevert(Target.EOACallIsNotAllowed.selector);
    vm.prank(user.addr, user.addr);
    target.setValue(value);

    // The operator attaches the `Delegation` smart contract to the user
    vm.startBroadcast(operator.key);
    vm.attachDelegation(signedDelegation);
    vm.stopBroadcast();

    // The operator calls the `setValue()` function on the `Delegation` contract on behalf of the user
    // which sets the `value` on the `Target` smart contract
    vm.prank(operator.addr, operator.addr);
    Delegation(user.addr).setValue(address(target), value);

    // Verify that the value was set (the check was bypassed)
    assertEq(target.getValue(), value);
}
```

As a result, the test shows that a smart contract attached to an EOA can be called by another EOA, and therefore `tx.origin` will be a different address.

Full example of the `test_checkCondition` test can be found in [Delegation.t.sol](./contracts/condition/Delegation.t.sol).

### Checking if an address is a smart contract

You can no longer rely on the check `address(contract).code > 0` to determine if an address is a smart contract and not an EOA. Now, an EOA with an attached smart contract also returns a value greater than 0.

![](./images/eip-7702-code-length-example.png)

According to the diagram, a user who has attached a smart contract to their address will be identified as a code-bearing account when calling other smart contracts (i.e. when they are the `msg.sender`).

You can verify that `msg.sender` is a smart contract attached to the user’s account as follows:

```solidity
assembly {
    // Load the code of `msg.sender`
    let ptr := mload(0x40)
    extcodecopy(caller(), ptr, 0, 32)
    let prefix := shr(232, mload(ptr))

    // Check that `prefix == 0xef0100`
    isDelegated := eq(prefix, 0xef0100)
}
```

To do this, you need to extract the special prefix, which is the magic number `0xef0100` and will always appear at the beginning of the bytecode of a delegated smart contract.

### Receiving any type of token that requires a callback function if the recipient is a smart contract

An EOA that has attached a smart contract starts behaving like a smart contract when it comes to ERC-721, ERC-777, and native currency.

This means the EOA won’t be able to receive assets unless the attached smart contract implements the following functions:

```js
receive() external payable {}
```
or
```js
function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) external returns(bytes4);
```

and so on.

![](./images/eip-7702-callback-functions-example.png)

To verify this, you can attach an empty smart contract [Delegation.sol](./contracts/receiveNativeCurrency/Delegation.sol) to any account, which does not implement the `receive()` function.

```solidity
contract Delegation {}
```

The verification test will look like this:

```solidity
function test_checkSendNativeCurrency(uint256 value) external {
    Vm.SignedDelegation memory signedDelegation = vm.signDelegation(address(delegation), user.key);

    // The operator attaches the `Delegation` smart contract to the user
    vm.startBroadcast(operator.key);
    vm.attachDelegation(signedDelegation);
    vm.stopBroadcast();

    // Attempt to send native currency — the transaction will revert
    (bool success,) = user.addr.call{value: value}(""); // success == false

    assertFalse(success);
}
```

Full example of the `test_checkSendNativeCurrency` test can be found in [Delegation.t.sol](./contracts/receiveNativeCurrency/Delegation.t.sol).

### Storage variable conflicts for EOAs

An EOA can delegate execution to different smart contracts by attaching and detaching them. A newly attached smart contract can easily overwrite storage variables that were set by the previous smart contract.

![](./images/eip-7702-collisions-example.png)

To test this hypothesis, we will sequentially attach two smart contracts [DelegationFirst.sol](./contracts/storageCollision/Delegation.sol) and [DelegationSecond.sol](./contracts/storageCollision/Delegation.sol), which both use the first storage slot: the first sets a `uint256`, the second sets a `bytes32`.

```solidity
contract DelegationFirst {
    uint256 private _value;

    function setValue(uint256 newValue) external {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }
}

contract DelegationSecond {
    bytes32 private _hashValue;

    function setHash(bytes32 hashValue) external {
        _hashValue = hashValue;
    }

    function getHash() external view returns (bytes32) {
        return _hashValue;
    }
}
```

The verification test will look as follows:

```solidity
function test_storageCollision(uint256 value, bytes32 hashValue) external {
    // Attach the first smart contract
    vm.startBroadcast(operator.key);
    vm.signAndAttachDelegation(address(delegationFirst), user.key);
    vm.stopBroadcast();

    // Set a value in the smart contract's storage
    DelegationFirst(user.addr).setValue(value);
    assertEq(DelegationFirst(user.addr).getValue(), value);

    // Attach the second smart contract
    vm.startBroadcast(operator.key);
    vm.signAndAttachDelegation(address(delegationSecond), user.key);
    vm.stopBroadcast();

    // Set a hash value in the smart contract's storage
    DelegationSecond(user.addr).setHash(hashValue);
    assertEq(DelegationSecond(user.addr).getHash(), hashValue);

    // Reattach the first smart contract
    vm.startBroadcast(operator.key);
    vm.signAndAttachDelegation(address(delegationFirst), user.key);
    vm.stopBroadcast();

    assertNotEq(DelegationFirst(user.addr).getValue(), value); // This proves that the original value was overwritten
}
```

Full example of the `test_test_storageCollision` test can be found in [Delegation.t.sol](./contracts/storageCollision/Delegation.t.sol).

**How to handle collisions?**

The only solution here may be to introduce a special namespace for variables to prevent slot conflicts.

The idea is that instead of using consecutive storage slots (which Solidity does by default), you can use [ERC-7201 Storage Namespaces Explained](https://eips.ethereum.org/EIPS/eip-7201) or other similar solutions.

To use this pattern, the developer needs to come up with a base identifier, which will be used to generate a hash that serves as the identifier for the storage slot.

```solidity
contract Delegation {
    struct MainStorage {
        uint256 value;
    }

    // keccak256(abi.encode(uint256(keccak256("MetaLampIsTheBest")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant MAIN_STORAGE_LOCATION = 0xd66e0df2d96f7ee8f3c31d9f50f7a36abdf7b3a8a2cbbfbe615a3abcc8b5af00;

    function _getMainStorage() private pure returns (MainStorage storage $) {
        assembly {
            $.slot := MAIN_STORAGE_LOCATION
        }
    }

    function getValue() external view returns (uint256) {
        MainStorage storage $ = _getMainStorage();

        // Retrieve a value from storage that is stored in a special slot
        return $.value;
    }
}
```

_Important!_ EIP-7201 will not protect you if a user attaches a malicious smart contract to their account, which deliberately overwrites a specific slot in your correct storage.

Similarly, no one is immune from signing a transaction that attaches unknown code to an EOA.

### Working with native currency

Let's consider two cases for an account that has attached a smart contract:
1. A `payable` function was called on the attached smart contract in the context of the user's account.
2. A `payable` function was called on the attached smart contract in the context of the user's account, which sent native currency to another smart contract.

![](./images/eip-7702-work-with-native-currency.png)

In the first case, the native currency remains in the user's balance; in the second case, it goes to the balance of the smart contract that is the final recipient.

To test this hypothesis, we’ll attach the [Delegation.sol](./contracts/work-with-native-currency/Delegation.sol) smart contract to the user.

```solidity
contract Delegation {
    /// Leave the native currency on the `user`'s address
    function buy() external payable {}

    /// @notice Send the native currency to the `target` smart contract
    function buyAndSendToTarget(address target) external payable {
        (bool success, ) = target.call{value: msg.value}("");

        if (!success) {
            revert();
        }
    }
}

contract Target {
    // Allow receiving native currency
    receive() external payable {}
}
```

There will be two verification tests:

```solidity
function test_workWithNativeCurrency_buy(uint256 value) external {
    deal(operator.addr, value);

    vm.startBroadcast(operator.key);
    vm.signAndAttachDelegation(address(delegation), user.key);
    vm.stopBroadcast();

    vm.prank(operator.addr);
    Delegation(user.addr).buy{value: value}();

    // The native currency remains in the user's balance
    assertEq(user.addr.balance, value);
}

function test_workWithNativeCurrency_buyAndSendToTarget(uint256 value) external {
    deal(operator.addr, value);

    vm.startBroadcast(operator.key);
    vm.signAndAttachDelegation(address(delegation), user.key);
    vm.stopBroadcast();

    vm.prank(operator.addr);
    Delegation(user.addr).buyAndSendToTarget{value: value}(address(target));

    // The native currency remains in the balance of the `target` smart contract
    assertEq(address(target).balance, value);
}
```

Full examples of the tests `test_workWithNativeCurrency_buy` and `test_workWithNativeCurrency_buyAndSendToTarget` can be found in [Delegation.t.sol](./contracts/work-with-native-currency/Delegation.t.sol).

## Compatibility

One of the most interesting points is how EIP-7702 will interact with previous account abstraction solutions, particularly [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337).

Surprisingly, very well! Anyone who has abstract accounts based on ERC-4337 can continue using them. The point is that for ERC-4337, the transaction initiator is not critical; it’s enough that the verification criteria (user operation signature) are valid.

Meanwhile, the folks at eth-infinitism almost immediately proposed an account design where ERC-4337 and ERC-7702 work together in one setup. The first standard handles gas sponsorship, the second handles batching of operations.

Such an account looks as follows:

```solidity
contract Simple7702Account is BaseAccount, IERC165, IERC1271, ERC1155Holder, ERC721Holder {
    /// The entrypoint address that can call transactions on the user’s account
    function entryPoint() public pure override returns (IEntryPoint) {
        return IEntryPoint(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);
    }

    /// Here it will be verified that the operation is signed with the user’s private key
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {

        return _checkSignature(userOpHash, userOp.signature) ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }

    ...
}
```

A schematic of how ERC-4337 and EIP-7702 work together is shown in the diagram below.

![](./images/eip-7702-and-erc-4337.png)

The user delegates execution to **Simple7702Account** (attaches the code of this smart contract). After that, they can sign operation data and send it for execution through a **bundler**.

[Full example of such an account](https://github.com/eth-infinitism/account-abstraction/blob/releases/v0.8/contracts/accounts/Simple7702Account.sol).

EIP-7702 has caught the attention of everyone interested in account abstraction: viem, MetaMask, ZeroDev, Biconomy, Alchemy, Trust Wallet, Ambire, and others. They have all integrated EIP-7702 into their solutions in one way or another, so there are plenty of reference implementations available.

## Etherscan

Etherscan also did a great job and immediately supported EIP-7702. To do this, it displays all fourth-type transactions on a separate [page](https://etherscan.io/txnAuthList).

![](./images/eip-7702-etherscan-list-of-transactions.png)

Etherscan also shows that the transaction was executed through the attached smart contract to which the EOA delegated execution.

![](./images/eip-7702-etherscan-1.png)

You can see that the transaction was executed on the attached smart contract in the separate "Delegated Address" field, and the transaction type in the "Other Attributes" field.

![](./images/eip-7702-etherscan-2.png)

## Limitations

It’s important to understand that EIP-7702 is not a full account abstraction solution; it does not transform an EOA into a "Smart self-sufficient account".

From the perspective of account abstraction, EIP-7702 has several limitations:

- **Private key is still very important**: it retains full control over the account, while also acting as a backdoor. Therefore, protecting the private key is extremely important.

- **Unequal rights for multisig**: it is still not possible to create a full multisig based on EIP-7702, since owners will have different rights. Everyone must trust the original EOA. Its private key grants unlimited authority.

- **Limited account recovery**: if the private key is lost or compromised, regaining full control over the EOA is impossible. The only solution would be to replace the private key, which is a non-trivial task.

- **No quantum resistance**: in the future, fully quantum-resistant accounts will be needed. EOAs remain vulnerable to potential quantum algorithms that could compromise their private keys.

- **Cannot use the account as an escrow**: because the original EOA has unlimited power and can withdraw funds.

## Conclusion

Thus, EIP-7702 is an important, strategic step toward account abstraction, bringing new energy to the Ethereum ecosystem and enabling new use cases. How account abstraction will look in the future is known only to Vitalik.

Also, it’s important not to forget the key issues:
- Collisions when working with account storage
- Challenges when operating across different networks
- The need to support ERC-721 or ERC-777, and native currency
- Inability to implement a full multisig or escrow account
- The private key still remains critical

A full transition of EOAs to smart accounts will require further changes in Ethereum. As the ecosystem evolves, EIP-7702 will play a crucial role in improving wallet UI, enhancing user security, and bringing us closer to the ultimate goal — full account abstraction.

# Links

1. Ethereum Improvement Proposals: [EIP-7702: Set Code for EOAs](https://eips.ethereum.org/EIPS/eip-7702).
2. [EIP-7702](https://www.cyfrin.io/glossary/eip-7702) by Cyfrin.
3. [Solidity и Ethereum, урок #93 | EIP-7702: EOA code](https://www.youtube.com/live/NZQc6bQdW9g). Video by Ilya Krukowski. Here is practical experience of using EIP-7702 from the smart contract perspective.
4. [In-Depth Discussion on EIP-7702 and Best Practices](https://slowmist.medium.com/in-depth-discussion-on-eip-7702-and-best-practices-968b6f57c0d5) by SlowMist. Here it’s more about how this works in Ethereum.
5. [Documentation viem](https://viem.sh/docs/eip7702).
6. [What You Need to Know About EIP-7702 “Smart” Account](https://info.etherscan.com/what-you-need-to-know-about-eip-7702-smart-account/) by etherscan.
7. [Deep Dive into Ethereum 7702 Smart Accounts: security risks, footguns and testing](https://www.youtube.com/watch?v=ZFN2bYt9gNE&ab_channel=TheRedGuild).
8. [Emergency EIP-7702 Wallet Recovery](https://medium.com/@BahadorGh/emergency-eip-7702-wallet-recovery-f4cc865f6341). A story about how a random delegation allowed assets to be stolen from a wallet.
9. [EIP-7702 overview](https://eip7702.io/).
10. [EIP7702: Closing the Gap Between EOAs and Smart Contracts](https://medium.com/valixconsulting/eip7702-closing-the-gap-between-eoas-and-smart-contracts-16b6f05584a9). Here, a historical overview is interesting, showing how standards in account abstraction have evolved.
11. [Awesome EIP-7702](https://github.com/fireblocks-labs/awesome-eip-7702). In case you need even more resources.
