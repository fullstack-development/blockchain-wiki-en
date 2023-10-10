// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

/**
 * @notice In the smart contract, control flow templates are depicted in Yul.
 */
contract ControlFlow {
    function ifStatement(uint256 n) external {
        assembly {
            if iszero(n) {
                // If true, perform the action.
            }
        }
    }

    function switchStatement(uint256 n) external {
        assembly {
            switch n
            case 0 {
                // If n equals 0, perform the action.
            }
            case 1 {
                // If n equals 1, perform the action.
            }
            default {
                // If none of the options have been triggered,
                // perform the default action.
            }
        }
    }

    function forLoop(uint256 n) external {
        assembly {
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                // Perform the action.
            }
        }
    }

    function forLoopWithAnotherCondition(uint256 n) external {
        assembly {
            let i := 0
            for {} lt(i, n) {} {
                // Perform the action.
                i := add(i, 1)
            }
        }
    }
}
