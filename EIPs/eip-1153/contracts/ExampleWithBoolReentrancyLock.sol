// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/**
 * ///////////////////////////////////////////////////////////////
 *                            IMPORTANT!
 * ///////////////////////////////////////////////////////////////
 *
 * @notice The code is written to demonstrate the capabilities of transient storage.
 * It is intended solely for this purpose and has not been audited.
 * Do not use on mainnet with real funds!
 */
contract ExampleWithBoolReentrancyLock {
    // Create the variable _lock
    bool private _lock;

    // Initialize a mapping to track balances
    mapping(address account => uint256 amount) private _balances;

    error InsufficientBalance();
    error ReentrancyAttackPrevented();
    error TransferFailed();

    function withdraw(uint256 amount) external {
        // Before executing the function, ensure it's not a reentrant call
        if (_lock) {
            revert ReentrancyAttackPrevented();
        }
        // Lock the function to protect against reentrancy
        _lock = true;

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

        // Disable the function lock
        _lock = false;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    receive() external payable {
        _balances[msg.sender] += msg.value;
    }
}
