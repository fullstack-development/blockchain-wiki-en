// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * ///////////////////////////////////////////////////////////////
 *                            IMPORTANT!
 * ///////////////////////////////////////////////////////////////
 *
 * @notice The code is written to demonstrate the capabilities of transient storage.
 * It is intended solely for this purpose and has not been audited.
 * Do not use on mainnet with real funds!
 */
contract ERC20WithTempApprove is ERC20 {
    error ExternalCallFailed();

    constructor() ERC20("Test", "T") {}

    /// @notice Function to call an external smart contract, granting it permission to withdraw tokens
    function approveAndCall(address spender, uint256 value, bytes memory data) external {
        // Grant temporary approval only for the amount intended to be spent
        _temporaryApprove(spender, value);

        // Perform an external call to the smart contract that will withdraw the tokens
        (bool success,) = address(spender).call(data);
        if (!success) {
            revert ExternalCallFailed();
        }
    }

    /// @notice Function to grant temporary approval
    function _temporaryApprove(address spender, uint256 value) private {
        // Form a key for writing to transient storage
        // Record the token owner's address,
        // the address of the contract that will withdraw them
        // and the value itself
        bytes32 key = keccak256(abi.encode(msg.sender, spender, value));

        // Store the approved token amount using the generated key
        assembly {
            tstore(key, value)
        }
    }

    /**
     * @notice When the target smart contract calls transferFrom,
     * transferFrom will invoke the _spendAllowance function.
     * Here, we check if temporary approval was granted.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal override {
        // First, reconstruct the key
        bytes32 key = keccak256(abi.encode(owner, spender, value));

        // Retrieve the value using the key
        uint256 temporaryApproval;
        assembly {
            temporaryApproval := tload(key)
        }

        // If approval exists, the token transfer will proceed
        // If not, delegate to the standard function
        // to check previously granted permissions
        if (temporaryApproval > 0) {
            // Checking if the temporary approval matches the value
            // being spent is unnecessary,
            // because in such a case, the key won't match

            // Make sure to clear the transient storage!
            assembly {
                tstore(key, 0)
            }
        } else {
            super._spendAllowance(owner, spender, value);
        }
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
