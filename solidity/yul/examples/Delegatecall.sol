// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

/**
 * @notice Smart contract for demonstrating the invocation of one smart contract from another
 * using inline assembly instructions.
 * @dev First, the Implementation contract is deployed.
 * Then, the Proxy contract is deployed.
 * We pass the encoded call to the increment() function with some argument in the Proxy contract's calldata.
 * If you are using Remix, you can pass them in low-level iterations.
 * For example, here is the data: 0x7cf5dab0000000000000000000000000000000000000000000000000000000000000002a
 * Use the debugger to see what happens in this transaction.
 */
contract Implementation {
    uint256 public sum;

    function increment(uint256 amount) external returns (uint256) {
        require(amount > 0, "Amount is zero");

        sum += amount;
        return sum;
    }
}

contract Proxy {
    uint256 public sum;
    address private immutable _implementation;

    constructor(address implementation) {
        _implementation = implementation;
    }

    fallback() external {
        _delegatecall(_implementation);
    }

    function _delegatecall(address impl) private {
        assembly {
            // Take everything that was passed with msg.data (starting from position 0)
            // Copy this data into memory, also starting from position 0
            calldatacopy(0, 0, calldatasize())

            // Make a call to the implementation and pass all the data from msg.data (starting from position 0)
            // Specify the size of the returned data as 0, as we assume
            // that we do not know the exact size of the data that will be returned

            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

            // Since in the previous step we specified 0 for the returned data,
            // manually copy them into memory (also from position 0 of returndata to position 0 of memory)
            returndatacopy(0, 0, returndatasize())

            // Check if the transaction was executed
            switch result
            case 0 {
                // If not, revert the transaction and return error data
                // if it was returned from the call
                revert(0, returndatasize())
            }
            default {
                // If everything is fine, return everything we received from the call
                return(0, returndatasize())
            }
        }
    }
}
