// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Delegation
 * @author Pavel Naydanov
 * @notice Demonstrate how storage and call context work when delegating calls through an EOA
 */
contract Delegation {
    uint256 private _value;

    constructor(uint256 initialValue) {
        _value = initialValue;
    }

    // Write a value to storage
    function setValue(uint256 newValue) external {
        _value = newValue;
    }

    // Read the value from storage
    function getValue() external view returns (uint256) {
        return _value;
    }
}
