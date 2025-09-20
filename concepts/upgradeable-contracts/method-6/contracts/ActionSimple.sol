// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @notice Smart contract that performs a simple action
 * @dev This contract is used to demonstrate calling the `execute` function via delegated call from the `Router` smart contract.
 */
contract ActionSimple {
    event Executed(bool success);

    /**
     * @notice Performs an action and emits the `Executed` event
     * @dev This function is called via delegatecall from the `Router` smart contract.
     */
    function execute() external {
        emit Executed(true);
    }
}
