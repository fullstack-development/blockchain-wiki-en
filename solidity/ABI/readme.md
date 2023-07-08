# ABI

The Contract Application Binary Interface (ABI) is a standard way to interact with contracts in the Ethereum ecosystem. Interaction can occur both from outside the blockchain and within the ecosystem among contracts.

To understand the need for ABI, it's important to grasp the following aspects of Solidity development:
- **EVM**: The Ethereum Virtual Machine (EVM), which is a distributed computer responsible for executing algorithms in the Ethereum network. These algorithms are known as smart contracts.
- **Smart Contract**: Code that performs operations in the Ethereum network.
- **Machine-Readable Code**: The EVM cannot interpret smart contract code written in high-level programming languages, including Solidity. Solidity code, along with any other code, needs to be compiled into machine-readable code or **bytecode**, which contains instructions in binary format.

Thus, in order for smart contract code to be understandable by the EVM, it needs to be compiled into bytecode. The compilation process produces two main outputs:
- **Machine-Readable Code** or bytecode, as mentioned above.
- Application Binary Interface (**ABI**), which is required to understand and interact with the bytecode.

## Encoding Process

We know that there are static and dynamic data types.

Examples of dynamic types:
- bytes
- string
- T[] for any T (array with any data types)

Data is encoded according to its type, as described in this [specification](https://docs.soliditylang.org/en/v0.8.19/abi-spec.html). It can be complex to understand, but it's necessary to read it thoroughly in order to understand how it works.

_Important!_ Static and dynamic types are encoded differently. Static types are encoded in place, while dynamic types are encoded as a "reference" or "offset," which represents the number of bytes. By shifting by this number of bytes, the value for the dynamic data type can be obtained.

### Encoding Function Calls

When calling a function, the first step is to encode the function selector. The function selector consists of the first four bytes of the Keccak-256 hash of the function signature.

```solidity
  bytes4(keccak256("function signature")
```
The function signature is defined as the canonical expression of the base function prototype without any modifiers. Parameter types are separated by a single comma, without spaces.

Example of an encoded function selector:```sum()```:
 ```solidity
    sum(uint256,uint256) => cad0899b
  ```
Starting from the fifth byte, the function arguments are encoded as follows:
- If the argument type is static, its value is encoded directly (in 32 bytes).
- If the argument type is dynamic, a pointer (offset) to the beginning of the argument's value storage is encoded relative to the start of the arguments block. The actual value can be found by applying the offset.

### Illustrating with an example

The specification included several [examples](https://docs.soliditylang.org/en/v0.8.19/abi-spec.html#examples). Below, we will analyze a similar example of encoding a function call.

Let's encode the function ```bar(uint256,uint256[])```. The arguments passed to this function are ```42``` and the array ```[21, 22]```. The encoding algorithm will appear as follows:

1. Encoding the function selector as follows:
   ```solidity
    bytes4(keccak256("bar(uint256,uint256[])") => ae2c7970
  ```
At this stage, we obtain:
 ```solidity
    0xae2c7970
  ```
2. Encoding the first argument ```42```. The argument type ```uint256``` is static, so we encode the value ```42``` directly. The hexadecimal representation of ```42``` is ```2a```. We pad ```2a``` to a 32-byte word.

```solidity
    000000000000000000000000000000000000000000000000000000000000002a
  ```
At this stage, we obtain:

 ```solidity
    0xae2c7970 + 000000000000000000000000000000000000000000000000000000000000002a
  ```

3. Encoding the second argument ```[21, 22]```. The argument type ```uint256[]``` is dynamic. Therefore, we first encode the offset (reference) to the location where the length of the array will be encoded. Remember that we count the number of bytes from the beginning of the argument block ```000000000000000000000000000000000000000000000000000000000000002a => 32 bytes + 32 bytes (value of the future offset)```. Thus, the length of the array will be encoded after 64 bytes. We encode the value ```64```. In hexadecimal, it is ```40```. As customary, we pad it to 32 bytes.

```solidity
  0000000000000000000000000000000000000000000000000000000000000040
```
At this stage, we obtain:
```solidity
    0xae2c7970 + 000000000000000000000000000000000000000000000000000000000000002a + 0000000000000000000000000000000000000000000000000000000000000040
  ```
4. After encoding the offset, we need to encode the length of the array itself. This is done to know when to stop reading the array elements. In this case, the length of the array is ```2```. We encode it as follows:

```solidity
    0000000000000000000000000000000000000000000000000000000000000002
  ```

At this stage, we obtain:
  ```solidity
    0xae2c7970 + 000000000000000000000000000000000000000000000000000000000000002a + 0000000000000000000000000000000000000000000000000000000000000040 + 0000000000000000000000000000000000000000000000000000000000000002
  ```

5. Finally, we just need to encode the two values of the array, which are ```21``` (15 in hexadecimal) and ```22``` (16 in hexadecimal). We pad these values to 32-byte words.
```solidity
    21 => 0000000000000000000000000000000000000000000000000000000000000015
    22 => 0000000000000000000000000000000000000000000000000000000000000016
  ```
At this stage, we obtain:
  ```solidity
    0xae2c7970 + 000000000000000000000000000000000000000000000000000000000000002a + 00000000000000000000000000000000000000000000000000000000000000040 + 0000000000000000000000000000000000000000000000000000000000000002 + 0000000000000000000000000000000000000000000000000000000000000015 + 0000000000000000000000000000000000000000000000000000000000000016
  ```
6. For clarity, we can represent it as follows:
    ```
  Encoded function selector:
  0xae2c7970

  Arguments block:
  0 - 000000000000000000000000000000000000000000000000000000000000002a - encoded 42 value
  1 - 0000000000000000000000000000000000000000000000000000000000000040 - encoded offset for [21, 22]
  2 - 0000000000000000000000000000000000000000000000000000000000000002 - number of items in the array [21, 22]
  3 - 0000000000000000000000000000000000000000000000000000000000000015 - encoded 21 value(the first array item)
  4 - 0000000000000000000000000000000000000000000000000000000000000016 - encoded 22 value(the second array item)
  ```
As a result we're getting the next hash:
  ```solidity
    0xae2c7970000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000150000000000000000000000000000000000000000000000000000000000000016
  ```

## What does ABI look like?

After compilation, ABI is represented as a **JSON file**. You can find an example of an ERC20 token ABI [here](./erc20ABI.json).

The JSON format for ABI contract consists of function, event, and error descriptions.

A function description is represented as a JSON object with the following fields:
- **type**: The type of the function ("function", "constructor", "receive", "fallback").
- **name**: The name of the function.
- **inputs**: An array of input objects (function arguments), each containing *name* (parameter name), *type*, and *components* (for tuples).
- **outputs**: An array of output objects (return values), similar to **inputs**.
- **stateMutability**: The state mutability of the function, which can be "pure", "view", "nonpayable", or "payable".

_Important!_ The return value type of a function is not part of the function signature and therefore is not encoded. However, the ABI contains information about the output values in the **outputs** field.

## Encoding and Decoding

To interact with the bytecode of a smart contract, data needs to be encoded and decoded. This is an ongoing two-way process.

In Solidity, there are special functions for encoding and decoding data:

- ```solidity
  abi.decode(bytes memory encodedData, (...)) returns (...)
  ```
- ```solidity
  abi.encode(...) returns (bytes memory)
  ```

- ```solidity
  abi.encodePacked(...) returns (bytes memory)
  ```

- ```solidity
  abi.encodeWithSelector(bytes4 selector, ...) returns (bytes memory)
  ```
- ```solidity
  abi.encodeWithSignature(string memory signature, ...) returns (bytes memory)
  ```

- ```solidity
  abi.encodeCall(function functionPointer, (...)) returns (bytes memory)
  ```


More details about these functions can be found in the documentation [here](https://docs.soliditylang.org/en/v0.8.19/units-and-global-variables.html#abi-encoding-and-decoding-functions).

A helpful [article](https://coinsbench.com/solidity-abi-encode-and-decode-b339eb52c5b5) provides further explanations for these built-in functions.

## Encode vs encodePacked
```solidity
abi.encode();
```

This is the standard method for encoding arguments according to the specification described above.

```solidity
abi.encodePacked();
```

This is the non-standard, packed encoding mode. Its features include:
- Values with types shorter than 32 bytes are not padded with zeros or signs.
- Dynamic types are encoded in place without their length.
- Array elements are padded with zeros but still encoded in place.
- Structures and nested arrays are not supported.

More details can be found [here](https://docs.soliditylang.org/en/v0.8.19/abi-spec.html#non-standard-packed-mode).

_Important!_ If you use ```keccak256(abi.encodePacked(a, b))```, where ```a``` and ```b``` are dynamic types, it is easy to encounter **hash collisions**. Moreover, the following holds true: ```abi.encodePacked("a", "bc") == abi.encodePacked("ab", "c")```. For such cases involving dynamic types, it is better to use the standard ```abi.encode()```.

You can try out these and other useful techniques for encoding and decoding data using ABI in Remix with our prepared [contract](contracts/Encoding.sol).

## Links

1. [Solidity ABI docs](https://docs.soliditylang.org/en/v0.8.19/abi-spec.html#json)
2. [ABI Encoding and Decoding Functions](https://docs.soliditylang.org/en/v0.8.19/units-and-global-variables.html#abi-encoding-and-decoding-functions)
3. [Everything You Need To Know About Solidity’s Application Binary Interface (ABI)](https://101blockchains.com/solidity-abi/)
4. [ABI encode and decode using solidity](https://medium.com/coinmonks/abi-encode-and-decode-using-solidity-2d372a03e110)
5. [Solidity ABI Encode and Decode](https://coinsbench.com/solidity-abi-encode-and-decode-b339eb52c5b5)
