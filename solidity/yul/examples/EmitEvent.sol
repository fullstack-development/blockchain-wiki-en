// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice An example fromt the Events chapter
 */

contract EmitEvent {
    event SomeLog(uint256 indexed a, uint256 indexed b, bool c);

    function emitEvent() external {
        assembly {
            // event's hash - keccak256("SomeLog(uint256,uint256,bool)")
            let signature := 0x39cf0823186c1f89c8975545aebaa16813bfc9511610e72d8cff59da81b23c72

            // Obtain a pointer to free memory
            let ptr := mload(0x40)

            // Write the number 1 to this address (0x80)
            mstore(ptr, 1)

            // create event SomeLog(2, 3, true)
            log3(0x80, 0x20, signature, 2, 3)
        }
    }
}
