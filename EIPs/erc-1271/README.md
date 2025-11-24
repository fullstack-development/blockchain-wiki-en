# ERC-1271: Standard Signature Validation Method for Contracts

**Author:** [Pavel Naydanov](https://github.com/PavelNaydanov) 🕵️‍♂️

The ERC-1271 standard offers a universal interface for signature verification. A smart contract that implements this interface is considered a signer and confirms the validity of a signature.

This is the key idea of the standard — to allow contracts to act as `signers` despite not having private keys to generate signatures. Instead, the smart contract provides the `isValidSignature()` method, which external protocols and applications can use to verify the validity of a signature.

![](./images/erc-1271-flow.png)

The diagram shows that the EOA, which is the owner of the **Wallet** smart contract, signs the transaction, and the application sends this signature along with the call to the **Target** smart contract, which could represent an exchange, lending protocol, or other DApps. The **Target** validates the EOA’s signature through the **Wallet** smart contract, which acts as the `Signer` according to the ERC-1271 standard.

_Important!_ It's worth noting that in our case the signature is generated using the EOA's private key, but other types of verification can also be used.

The Wallet smart contract must implement the following function:
```solidity
function isValidSignature(bytes32 _hash, bytes calldata _signature) external view returns (bytes4)
```

This is a `view` function, meaning it must not modify the state. Also, pay attention to the return value: on success, it returns `bytes4` — the function selector of `isValidSignature()` (a selector of itself). This is a classic approach where a boolean value is not returned. Returning `bytes4` adds more certainty, because a smart contract that does not support EIP-1271 might fall back to the `fallback()` function when `isValidSignature()` is called, and unintentionally return **true**.

The code example below is taken from the specification [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271).

```solidity

  // bytes4(keccak256("isValidSignature(bytes32,bytes)")
  bytes4 constant internal MAGICVALUE = 0x1626ba7e;

  /**
   * @dev Should return whether the signature provided is valid for the provided hash
   * @param _hash      Hash of the data to be signed
   * @param _signature Signature byte array associated with _hash
   *
   * MUST return the bytes4 magic value 0x1626ba7e when function passes.
   * MUST NOT modify state (using STATICCALL for solc < 0.5, view modifier for solc > 0.5)
   * MUST allow external calls
   */
  function isValidSignature(
    bytes32 _hash,
    bytes memory _signature)
    public
    view
    returns (bytes4 magicValue);
}
```

_Important!_ The implementation of the `isValidSignature()` function is not strictly regulated and may include complex signature verification logic under the hood, depending on:
  - the context (e.g., time or state)
  - the EOA (e.g., the signer’s authorization level in the smart wallet)
  - the signature scheme (e.g., ECDSA, multisig, BLS), etc.

Therefore, some implementations may consume more gas than expected. It's important not to manually set the amount of gas sent when calling the function from the Target contract, as this could cause the transaction to fail.

Basically, that's all you need to know about this standard.

## Issues with ERC-1271

Many protocols that address account abstraction issues support ERC-1271 under the hood of their smart contracts that implement abstract accounts.

In 2023, the company Alchemy discovered a vulnerability in its `LightAccount` smart contract. The issue was the possibility of replaying an ERC-1271 signature. EOAs that created multiple `LightAccounts` would, by signing for one of them, unintentionally allow the same signature to be used with the other `LightAccount` as well.

![](./images/erc-1271-replay-attack.png)

The diagram shows that with the same signature, the `Recipient` can receive two payouts from different user accounts.

A similar issue was also found in a number of other AA protocols: Zerodev, Biconomy, Soul Wallet, EIP4337Fallback for Gnosis Safes by eth-infinitism, AmbireAccount, SmartAccount by OKX, BaseWallet by Argent, and Fuse Wallet.

The issue involved cases where a signature allowed Permit2 smart contracts to transfer tokens. This also applies to other similar smart contracts, such as Cowswap, the Lens protocol, and others.

The guys from Alchemy raised the alarm and, together with other AA experts, came up with two solutions.

**Solution 1. Use the domain from EIP-712**

Using the domain structure from [EIP-712](https://eips.ethereum.org/EIPS/eip-712), define which smart contract the signature can be verified on.

```solidity
function isValidSignature(bytes32 digest, bytes calldata sig) external view returns (bytes4) {
	bytes32 domainSeparator =
		keccak256(
			abi.encode(
				_DOMAIN_SEPARATOR_TYPEHASH,
				_NAME_HASH,
				_VERSION_HASH,
				block.chainid,
				address(walletA) // Defines which smart wallet contract the signature can be validated on
			)
		);

	bytes32 wrappedDigest = keccak256(abi.encode("\x19\x01", domainSeparator, digest));

	return ECDSA.recover(wrappedDigest, sig);
}
```

**Solution 2. Add the smart contract address to the data hash**

The signature hash is used, and the address of the smart contract where the signature can be validated is added to it. This solution is more lightweight, but it means wallet clients will have to display a non-transparent hash for user signatures.

```solidity
function isValidSignature(bytes32 digest, bytes calldata sig) external view returns (bytes4) {
  bytes32 wrappedDigest = keccak256(abi.encode(digest, address(SCA));
	return ECDSA.recover(wrappedDigest, sig);
}
```

## Conclusion

ERC-1271 is a very simple ERC, but it's crucial for establishing a standard for signature verification using smart contracts.

Many people think the standard is just about allowing smart contracts to give approvals via signatures on their behalf. But I would look at it more broadly — in my opinion, this standard can be applied in any situation where you need to verify a signature on smart contracts. So, if your smart contracts implement any form of gasless interaction through signatures, or validate fees set by the backend, and so on, you can safely use this ERC-1271 interface.

## Links

1. [ERC-1271: Standard Signature Validation Method for Contracts](https://eips.ethereum.org/EIPS/eip-1271)
2. [ERC-1271 Signature Replay Vulnerability](https://www.alchemy.com/blog/erc-1271-signature-replay-vulnerability)
3. [Clarifying ERC-1271: Smart Contract Signature Verification](https://medium.com/taipei-ethereum-meetup/clarifications-on-erc-1271-smart-contract-signature-verification-and-signing-cd5c2fb7ac1b)
