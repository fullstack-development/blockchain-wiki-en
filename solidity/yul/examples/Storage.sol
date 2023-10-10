// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

/**
 * @notice This smart contract showcases examples provided in the Storage section.
 */
contract Storage {
    uint256 x; // slot 0

    uint128 a; // slot 1
    uint96 b; // slot 1
    uint16 c; // slot 1
    uint8 d; // slot 1
    uint8 e; // slot 1

    uint256[5] arr = [11, 22, 33, 44, 55]; // slot 2 - 6
    uint256 amount; // slot 7
    uint128[2] packedArr = [21, 42]; // slot 8
    uint256 amount2; // slot 9

    uint256[] dynamicArr = [123, 345, 678]; // slot 10

    mapping(uint256 => uint256) map; // slot 11
    mapping(uint256 => mapping(uint256 => uint256)) nestedMap; // slot 12
    mapping(address => uint256[]) arrayInMap; // slot 13

   // All three lines are handled by one function, so simply uncomment the one you need
    string str = "Hello, world!"; // slot 14
    // string str = "Hello, this is a test phrase 02";
    // string str = "Hello, this is a test phrase for wiki";

    constructor() {
        map[42] = 21;
        nestedMap[4][2] = 21;
        arrayInMap[msg.sender] = [11, 22, 33];
    }

    // region - Simple value

    function setStorageValue(uint256 _x) public {
        assembly {
            sstore(x.slot, _x)
        }
    }

    function getStorageValue() public view returns (uint256 ret) {
        assembly {
            ret := sload(x.slot)
        }
    }

    // endregion

    // region - Packed values

    function setCToPackedSlot(uint16 _c) public {
        assembly {
            // Load data from the slot
            let data := sload(c.slot)

            // Reset the bits of the variable where the value is stored.
            // Since it's uint16, it occupies 2 bytes.
            let cleared := and(data, 0xffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

            // Shift the new value to the left by the offset of the variable multiplied by 8 (1 byte = 8 bits).
            // The offset is in bytes, but we perform the shift in bits.
            let shifted := shl(mul(c.offset, 8), _c)

            // Combine the cleared slot and the shifted value
            let newValue := or(shifted, cleared)

            // Save the new value in the slot
            sstore(c.slot, newValue)
        }
    }

    function getCFromPackedSlot() public view returns (uint16 ret) {
        assembly {
            // Load data from the slot
            let data := sload(c.slot)

            // Shift right using the offset of the desired variable
            let shifted := shr(mul(c.offset, 8), data)

            // Apply a mask to obtain the value of the variable
            ret := and(shifted, 0xffff)
        }
    }

    // endregion

    // region - Array, packed array

    function getValueFromArray(uint256 index) public view returns (uint256 value) {
        assembly {
            value := sload(add(arr.slot, index))
        }
    }

    function getPackedValueFromArray() public view returns (uint128 value) {
        bytes32 packed;

        assembly {
            // Load packed data
            packed := sload(packedArr.slot)

            // Shift right by 16 bytes (128 bits) to obtain the value of the array at index 1
            value := shr(mul(16, 8), packed)
        }
    }

    // endregion

    // region - Dynamic array

    function getValueFromDynamicArray(uint256 index) external view returns (uint256 value) {
        uint256 slot;

        assembly {
            // Obtain the slot where the length of the array is stored
            slot := dynamicArr.slot

            // Calculate a hash that points to the slot where the array values are stored
            // Equivalent to the Solidity code:
            // bytes32 ptr = keccak256(abi.encode(slot));
            mstore(0x00, slot)
            let ptr := keccak256(0x00, 0x20)

            // Load the required array element by index
            value := sload(add(ptr, index))
        }
    }

    function getDynamicArrayLength() external view returns (uint256 length) {
        assembly {
            length := sload(dynamicArr.slot)
        }
    }

    // endregion

    // region - Mappings
    function getValueFromMapping(uint256 key) public view returns (uint256 value) {
        bytes32 slot;

        assembly {
            // Obtain the mapping slot
            slot := map.slot

            // Calculate a hash that points to the slot where the mapping values are stored
            // Equivalent to the Solidity code:
            // bytes32 ptr = keccak256(abi.encode(key, uint256(slot)));
            mstore(0x00, key)
            mstore(0x20, slot)
            let ptr := keccak256(0x00, 0x40)

            // Load the required mapping element
            value := sload(ptr)
        }
    }

    function getValueFromNestedMapping(uint256 key1, uint256 key2) public view returns (uint256 value) {
        bytes32 slot;
        assembly {
            slot := nestedMap.slot

            // bytes32 ptr2 = keccak256(abi.encode(key2, keccak256(abi.encode(key1, uint256(slot)))));
            mstore(0x00, key1)
            mstore(0x20, slot)
            let ptr1 := keccak256(0x00, 0x40)

            mstore(0x00, key2)
            mstore(0x20, ptr1)
            let ptr2 := keccak256(0x00, 0x40)

            value := sload(ptr2)
        }
    }

    function getValueFromArrayNestedInMapping(address key, uint256 index)
        public
        view
        returns (uint256 value, uint256 length)
    {
        bytes32 slot;

        assembly {
            slot := arrayInMap.slot
        }

        bytes32 arrSlot = keccak256(abi.encode(key, slot));
        bytes32 ptr = keccak256(abi.encode(arrSlot));

        assembly {
            value := sload(add(ptr, index))
            length := sload(arrSlot)
        }
    }

    // endregion

    // region - Strings

    function getStringInfo() external view returns (uint256 length, bytes32 lsb, bytes32 strBytes, bytes32 slot) {
        assembly {
            // Cache the slot
            slot := str.slot
           // Load the contents of the slot
            strBytes := sload(slot)
            // Copy the contents to obtain the least significant bit
            let _arr := strBytes
            // Obtain the value of the least significant bit
            lsb := and(_arr, 0x1)

           // Check if it is equal to 0
            if iszero(lsb) {
                // Take the least significant byte and divide by 2 to obtain the length of the string
                length := div(byte(31, strBytes), 2)
            }

            // Check if it is greater than 0
            if gt(lsb, 0) {
                // Subtract 1 and divide by 2 to obtain the length of the string
                length := div(sub(strBytes, 1), 2)

                // Write the slot number to memory
                mstore(0x00, slot)
                // Get the slot hash to find out where the string is actually located
                slot := keccak256(0x00, 0x20)
            }
        }
    }

    // endregion
}
