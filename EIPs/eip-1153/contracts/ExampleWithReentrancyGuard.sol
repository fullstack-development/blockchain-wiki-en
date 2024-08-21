// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * ///////////////////////////////////////////////////////////////
 *                            IMPORTANT!
 * ///////////////////////////////////////////////////////////////
 *
 * @notice The code is written to demonstrate the capabilities of transient storage.
 * It is intended solely for this purpose and has not been audited.
 * Do not use on mainnet with real funds!
 */
contract ExampleWithReentrancyGuard is ReentrancyGuard {
    mapping(address account => uint256 amount) private _balances;

    error InsufficientBalance();
    error ReentrancyAttackPrevented();
    error TransferFailed();

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

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    receive() external payable {
        _balances[msg.sender] += msg.value;
    }
}
