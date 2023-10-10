// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @notice This smart contract contains examples provided in the Memory section.
 * Please refer to the debugger to view these examples.
 */
contract Memory {
    uint256 value = 42;

    struct S {
        uint256 a;
        uint256 b;
    }

    // region - Read storage value

    function getValue() external view returns (uint256) {
        assembly {
            // Obtain the value for 'value,' which is located in the corresponding slot
            let _value := sload(value.slot)

            // Then obtain a "pointer" to free memory in memory
            let ptr := mload(0x40)

            // Write our number there
            mstore(ptr, _value)

            // Return this number
            return(ptr, 0x20)
        }
    }

    // endregion

    // region - Memory allocation

    function allocateMemory() external pure {
        assembly {
            // Perform some operations in memory using 3 slots
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, 1)
            mstore(add(freeMemoryPointer, 0x20), 2)
            mstore(add(freeMemoryPointer, 0x40), 3)

            // Call the function to update the pointer
            allocate(0x60)

            // Function that gets the memory size we used earlier
            // and updates the pointer to free memory
            function allocate(length) {
                let pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }
        }
    }

    // endregion

    // region - Struct

    function getStructValuesAndFreeMemoryPointer()
        external
        pure
        returns (uint256 a, uint256 b, bytes32 freeMemoryPointer)
    {
        // Create a structure and add values to it
        S memory s = S({a: 21, b: 42});

        assembly {
            a := mload(0x80) // вернет a (21), потому что по умолчанию указатель на свободную память в solidity - 0x80
            b := mload(0xa0) // вернет b (42), второе значение в структуре размещается следом за первым

            // New pointer to free memory - 0xc0 (0x80 + 32 байт * 2)
            freeMemoryPointer := mload(0x40)
        }
    }

    // endregion

    // region - Fixed array

    function getFixedArrayValues() external pure returns (uint256 a, uint256 b) {
        uint256[2] memory arr;
        arr[0] = 21;
        arr[1] = 42;

        assembly {
            a := mload(0x80) // Returns the value at index 0
            b := mload(0xa0) // Returns the value at index 1

        }
    }

    // endregion

    // region - Dynamic array

    function getDynamicArrayValues(uint256[] memory arr) external pure returns (uint256 a, uint256 b, uint256 length) {
        assembly {
            // The location is the first available pointer: 0x80
            let ptr := arr
            // It contains the length of the array
            length := mload(ptr)

            a := mload(add(ptr, 0x20)) // The next cell will contain the value at index 0
            b := mload(add(ptr, 0x40)) // Then the one at index 1, and so on
        }
    }

    function setValuesToDynamicArray() external pure returns (uint256[] memory) {
        uint256[] memory arr;

        // Create an array in memory = [42, 43]
        assembly {
            // Currently, arr points to 0x60

            // First, assign it a pointer to free memory
            arr := mload(0x40)
            // Write the length of the future array - 2 elements
            mstore(arr, 2)
            // Add values to the array

            mstore(add(arr, 0x20), 42)
            mstore(add(arr, 0x40), 43)

            // Update the pointer to free memory
            mstore(0x40, add(arr, 0x60))
        }

        return arr;
    }

    // endregion

    // region - Strings

    function getStringInfo() external pure returns (uint256 len, bytes21 strInBytes) {
        string memory str = "Hello, this is a test"; // 21 symbols (0x15 в hex)

        assembly {
            len := mload(0x80) // // In this slot, there will be the length of the array
            strInBytes := mload(0xa0) // // And in the next slot, there will be the array itself
        }
    }

    function getString() external pure returns (string memory str) {
        str = "Hello, this is a test";
    }

    function getSeaport() external pure returns (string memory, uint256 len, bytes7 arr) {
        assembly {
            mstore(0x20, 0x20) // The second slot is used for similarity with the original example
            mstore(0x40, 0x07) // Here, we explicitly specify the length
            mstore(0x60, 0x536561706f727400000000000000000000000000000000000000000000000000) // Here, we only write values
            return(0x20, 0x60) // Returning 96 bytes as well
        }
    }

    function getSeaportSecondVariant() external pure returns (string memory, uint256 len, bytes7 arr) {
        assembly {
            // Commenting out the old code for reference
            // mstore(0x20, 0x20)
            // mstore(0x47, 0x07536561706f7274)
            // return(0x20, 0x60)

            mstore(0x25, 0x20) // 0x20 + 5 = 0x25
            mstore(0x4c, 0x07536561706f7274) // 0x47 + 5 = 0x4c
            return(0x25, 0x60) // 0x20 + 5 = 0x25
        }
    }

    // endregion

    // region - ABI

    function abiEncode() external pure {
        abi.encode(uint256(1), uint256(2));

        assembly {
            let length := mload(0x80) // 0x0000...000040 (64 bytes)
            let arg1 := mload(0xa0) // 0x0000...000001 (32 bytes)
            let arg2 := mload(0xc0) // 0x0000...000002 (32 bytes)
        }
    }

    function abiEncodePacked() external pure {
        abi.encodePacked(uint256(1), uint128(2));

        assembly {
            let length := mload(0x80) // 0x0000...000030 (48 bytes)
            let arg1 := mload(0xa0) // 0x0000...000001 (32 bytes)
            let arg2 := mload(0xc0) // 0x00...0002 (16 bytes)
        }
    }

    // endregion

    // region - Return, revert

    function returnValues() external pure returns (uint256, uint256) {
        assembly {
            // Write values to slots 0x80 and 0xa0
            mstore(0x80, 1)
            mstore(0xa0, 2)
            // Return data starting from offset 0x80 with a size of 0x40 (64 bytes)
            return(0x80, 0x40)
        }
    }

    function revertExecution() external {
        assembly {
            if iszero(eq(mul(2, 2), 5)) { revert(0, 0) }
        }
    }

    // endregion

    // region - Keccak256

    function getKeccak() external pure {
        assembly {
            // Write values to slots 0x80 and 0xa0
            mstore(0x80, 1)
            mstore(0xa0, 2)

            // Hash the data starting from 0x80 with a size of 0x40 and store them in slot 0xc0
            mstore(0xc0, keccak256(0x80, 0x40))
        }
    }

    // endregion
}
