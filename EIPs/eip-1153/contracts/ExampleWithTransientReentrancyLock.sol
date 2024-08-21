// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * ///////////////////////////////////////////////////////////////
 *                            IMPORTANT!
 * ///////////////////////////////////////////////////////////////
 *
 * @notice The code is written to demonstrate the capabilities of transient storage.
 * It is intended solely for this purpose and has not been audited.
 * Do not use on mainnet with real funds!
 */
contract ExampleWithTransientReentrancyLock {
    // Define a constant value for addressing in transient storage
    // keccak256("REENTRANCY_GUARD_SLOT");
    bytes32 constant REENTRANCY_GUARD_SLOT = 0x167f9e63e7ffa6919d959c882a4da1182dccfb0d790328477621b65d1978856b;

    mapping(address account => uint256 amount) private _balances;

    error InsufficientBalance();
    error ReentrancyAttackPrevented();
    error TransferFailed();

    modifier nonReentrant() {
        // Before executing the function, ensure it's not a reentrant call
        if (_tload(REENTRANCY_GUARD_SLOT) == 1) {
            revert ReentrancyAttackPrevented();
        }
        // Write the value 1 to the REENTRANCY_GUARD_SLOT key
        _tstore(REENTRANCY_GUARD_SLOT, 1);

        _;

        // Clear the value of the key in transient storage after the external call
        _tstore(REENTRANCY_GUARD_SLOT, 0);
    }

    function withdraw(uint256 amount) external nonReentrant {
        // Check the current state
        if (_balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        // Update the state
        _balances[msg.sender] -= amount;

        // Transfer the requested funds
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /// @notice Helper function for writing to transient storage
    function _tstore(bytes32 location, uint256 value) private {
        assembly {
            tstore(location, value)
        }
    }

    /// @notice Helper function for reading from transient storage
    function _tload(bytes32 location) private view returns (uint256 value) {
        assembly {
            value := tload(location)
        }
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    receive() external payable {
        _balances[msg.sender] += msg.value;
    }
}
