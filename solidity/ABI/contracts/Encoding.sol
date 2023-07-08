// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract TestContract {
    function someFunc(uint256 amount, address addr) public {}
}

// Useful Notes
// 1. ABI - Binary interface of a contract, the standard way to interact with contracts within the ecosystem.
//    Function selector - The first 4 bytes define the function selector.
//    Starting from the 5th byte, the function arguments are encoded.
//    Following that, types are encoded (uint<M>, int<M>, address, uint, int, bool, ..., bytes<M, function>).
//    Some types are not directly supported by ABI (address payable, contract, enum, struct). These types are supported through standard types.
//
//    There are dynamic types (bytes, string, T[]).
//    There are static types (all others).
//
//    Events can be indexed or non-indexed. It's a bit complicated.
//    Indexed events are logged into a special log and are hard to read but easy to search.
//    Non-indexed events are logged in-place, easy to read but hard to search.
//
//    Errors are encoded as functions.
//
//    encode - A method of the global ABI object for encoding.
//    encodePacked - An unconventional encoding method where types are tightly packed.
//                   Dynamic types are encoded in-place without length.
//                   Array elements are padded but encoded in-place.
//
//    Documentation reference: [Solidity ABI Specification](https://docs.soliditylang.org/en/v0.8.16/abi-spec.html#abi)

// 2. For string concatenation, you can use abi.encodePacked.
//    Example: string(abi.encodePacked("Hi mom! ", "Miss you"));

//    Important: Starting from Solidity version 0.8.12, the `concat` method is available.
//      Example: string.concat(strA, strB);

// 3. The methods encodeStringPacked and encodeStringsBytes produce the same visible result.
//    The difference is described here: [Difference between abi.encodePacked(string) and bytes(string)](https://forum.openzeppelin.com/t/difference-between-abi-encodepacked-string-and-bytes-string/11837)
//    The first one involves memory copying, while the second one is simply a pointer type conversion.
//    Important: Pointer type conversion is cheaper in terms of gas usage.

contract Encoding {
    // String Contactination
    function combineStrings() public pure returns (string memory) {
        return string(abi.encodePacked("Hi mom! ", "Miss you"));
    }

    // Encoding multiple strings
    function combineBytesStrings() public pure returns (bytes memory) {
        return abi.encodePacked("Hi mom! ", "Miss you");
    }

    // Encoding a number
    function encodeNumber() public pure returns(bytes memory) {
        bytes memory number = abi.encode(1);
        return number;
    }

    // String encoding
    function encodeString() public pure returns(bytes memory) {
        bytes memory someString = abi.encode("some string");
        return someString;
    }

    // Another way of string encoding
    function encodeStringPacked() public pure returns(bytes memory) {
        bytes memory someString = abi.encodePacked("some string");
        return someString;
    }

    // Another way of string encoding
    function encodeStringsBytes() public pure returns(bytes memory) {
        bytes memory someString = bytes("some string");
        return someString;
    }

    // String decoding
    function decodeString() public pure returns (string memory) {
        string memory someString = abi.decode(encodeString(), (string));
        return someString;
    }

    // Encoding multiple strings
    function multiEncode() public pure returns(bytes memory) {
        bytes memory someString = abi.encode("some string", "it's bigger");
        return someString;
    }

    // Decoding multiple strings
    function multiDecode() public pure returns (string memory, string memory) {
        (string memory someString, string memory someOtherString) = abi.decode(multiEncode(), (string, string));
        return (someString, someOtherString);
    }

    // Alternative way of Encoding multiple strings
    function multiEncodePacked() public pure returns(bytes memory) {
        bytes memory someString = abi.encodePacked("some string", "it's bigger");
        return someString;
    }

    // Alternative way of dencoding multiple strings
    // "This approach cannot be implemented. Multiple decoding in the reverse direction will not work.
// This is because with this encoding method, we eliminate information about spaces and other unnecessary things."
    function multiDecodePacked() public pure returns (string memory, string memory) {
        (string memory someString, string memory someOtherString) = abi.decode(multiEncodePacked(), (string, string));
        return (someString, someOtherString);
    }

    // Alternative way of dencoding multiple strings
    // This option is working one.
    function multiStringCastPacked() public pure returns (string memory) {
        string memory someString = string(multiEncodePacked());
        return someString;
    }

    //========= Obtaining the function selector and arguments ========

    // Example: obtaining the function call selector and arguments from encoded data.
// A real case scenario that I had to deal with, where I needed to separately extract the function call selector and function arguments from the call data.
    function getFuncSelectorAndArgs() public view returns (bytes4 selector, bool isSelecor, uint, address) {
// Encoding the function selector with the argument uint256.

        bytes4 _selector = bytes4(keccak256("someFunc(uint256,address)"));
        bytes memory data = abi.encodeWithSelector(_selector, 100, msg.sender);

// Obtaining the function selector.

        selector = this.decodeFuncSelector(data);
        // Verifying that the function selector is correct
        isSelecor = selector == TestContract.someFunc.selector;

// Obtaining the function arguments.
        (uint256 argument1, address argument2) = this.decodeFuncArguments(data);

        return (selector, isSelecor, argument1, argument2);
    }

// Obtaining the function selector.
    function decodeFuncSelector(bytes calldata data) public pure returns (bytes4) {
        bytes4 selector = bytes4(data[:4]);
        return selector;
    }

// Obtaining arguments.
    function decodeFuncArguments(bytes calldata data) public pure returns(uint amount, address addr) {
        (amount, addr) = abi.decode(data[4:], (uint256, address));
        return (amount, addr);
    }
}
