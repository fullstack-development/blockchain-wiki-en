// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Stack
 * @notice Library for implementing the stack data structure
 * @dev It can be used as follows:
 * using Stack for bytes[];
 * bytes[] private _stack;
 */
library Stack {
    /**
     * @notice Add an element to the stack
     * @param stack An array that implements a stack structure
     * @param data Element to add to stack
     */
    function pushTo(bytes[] storage stack, bytes calldata data) external {
        stack.push(data);
    }

    /**
     * @notice Pop an element from the stack
     * @param stack An array that implements a stack structure.
     * @return data The last element in the stack
     */
    function popOut(bytes[] storage stack) external returns (bytes memory data) {
        data = stack[stack.length - 1];
        stack.pop();
    }
}