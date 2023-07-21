// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @notice The contract verifies an arbitrarily signed message using a private key.
 * @dev It uses the built-in function ecrecover().
 */
contract SignatureVerifier {
    /// @notice The prefix to indicate that this signature will be used only within the Ethereum network.
    bytes32 constant public PREFIX = "\x19Ethereum Signed Message:\n32";

    /// @notice Verifies whether the signature was made by the address "signer."
    function isValid(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s) external pure returns (bool) {
        return _recover(hash, v, r, s) == signer;
    }

    /// @notice Recovers the public address of the private key that was used to make the given signature.
    function _recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) private pure returns (address) {
        bytes32 prefixedHash = keccak256(abi.encodePacked(PREFIX, hash));

        return ecrecover(prefixedHash, v, r, s);
    }
}
