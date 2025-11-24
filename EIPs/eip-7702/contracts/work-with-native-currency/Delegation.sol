// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Delegation
 * @author Pavel Naydanov
 * @notice Demonstrate how native currency is handled
 */
contract Delegation {
    /// Leave the native currency on the user's address
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
