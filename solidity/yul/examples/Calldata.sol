// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice An example from the Calldata chapter 
 */
contract Calldata {
    function getString(string calldata) external pure returns (string memory, uint256 len) {
        assembly {
            // Getting the string offset, adding 4 bytes for the signature to adjust the offset
            let strOffset := add(4, calldataload(4))
            // get the string's length
            len := calldataload(strOffset)
            // Obtain a pointer to free memory
            let ptr := mload(0x40)
            // Calculating the size of data without the signature
            let dataSize := sub(calldatasize(), 4)
            // Copying all string data to memory except for the signature
            calldatacopy(ptr, 0x04, dataSize)

            // return the string
            return(0x80, dataSize)
        }
    }
}
