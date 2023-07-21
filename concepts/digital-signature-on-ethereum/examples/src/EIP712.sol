// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

/**
 *@notice The contract verifies a message signed with a private key using typed data according to EIP-712.
 * @dev It uses the ECDSA library from OpenZeppelin.
 */
contract EIP712 {
    bytes32 public constant IS_VALID_TYPEHASH = keccak256("isValid(uint256 nonce)");

/// @notice Signature verification counter. Ensures that the same signature is not used twice.
    uint256 public signatureNonce;

    error SignatureIsInvalid();

    /// @notice 32-byte domain delimiter. Used to determine the properties of a specific application.
/// In other words, the signature can only be used for this application.
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("EIP712"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice hashStruct. Used to determine the typed data of the signature.

    function _getDigest(bytes32 typeHash) private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01", // According to EIP-191, it represents a fixed version value that defines "Structured data" EIP-712.
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        typeHash,
                        signatureNonce + 1
                    )
                )
            )
        );
    }

    /**
     * @notice Verifies if the signature was made by the signer's address.
     * @param signer The public address to check, the one that signed the message.
     * @param signature The signature to be verified (abi.encoded(r, s, v)).
     */
    function isValid(address signer, bytes memory signature) public view returns (bool) {
        bytes32 digest = _getDigest(IS_VALID_TYPEHASH);
        address recoveredSigner = ECDSA.recover(digest, signature);

        return signer == recoveredSigner;
    }

    function useSignature(address signer, bytes memory signature) external {
        if (!isValid(signer, signature)) {
            revert SignatureIsInvalid();
        }

        signatureNonce += 1;
    }
}
