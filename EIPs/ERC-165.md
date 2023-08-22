# ERC-165: Standard Interface Detection

Sometimes, when interacting with an external contract, it can be useful to determine whether the smart contract supports certain "standard interfaces," such as the ERC-721 token interface, and if it does, which version of the interface it supports. To achieve this there is the EIP-165: Standard Interface Detection, which defines how to perform such checks.


**EIP-165** is a standard for Ethereum blockchain smart contracts that allows the identification of supported interfaces by smart contracts. This is accomplished by having a smart contract implement a special function called `supportsInterface(bytes4 interfaceID)`, which takes an interface identifier as input and returns a boolean value indicating whether the contract implements the corresponding interface. This approach simplifies interaction with smart contracts, as users can check whether a specific function or capability is supported by the smart contract before invoking it.

The **interface identifier (ID)** for ERC-165 is a four-byte value computed as the keccak-256 hash of the interface function's signature. The function signature is a string consisting of the function name and the types of its parameters in a specific format.

For example, the function signature for `supportsInterface` in ERC-165 is `"supportsInterface(bytes4)"`. This string is then passed through the keccak-256 hash function, resulting in a 32-byte hash value. The first four bytes of this hash value are taken as the interface identifier.

The function signature should be in the format `"functionName(type1, type2, ...)"`, with types specified in their canonical Solidity representation, such as `address` instead of `address payable` and `bytes32[]` instead of `array`.

It is also important to note that the interface identifier is the same for the selector of the same function. This means it is unique across all smart contracts, helping to prevent naming conflicts.

**Let's consider an example of the interfaceId for ERC-721:**

To compute the interface identifier for ERC-721, you need to take the keccak-256 hash of the selector for each function and then take the first 4 bytes of the result. Each function has its own unique interface identifier.

To combine all the hashes, the XOR (exclusive OR) operation is used. This ensures that the same `interfaceId` is obtained regardless of the order in which the function selectors are passed.

Therefore, to compute the interface identifier using EIP-165, you need to obtain the selector for each function in the smart contract's interface and then use XOR to combine them.

```js
    bytes4(keccak256('balanceOf(address)')) == 0x70a08231
    bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
    bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
    bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
    bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
    bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
    bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
    bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
    bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde

    => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^ 0xa22cb465 ^ 0xe985e9c ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd

    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
```
In the Solidity language, there is a built-in capability to compute the `interfaceId` using `type(T).interfaceId`. Let's consider the example of the aforementioned interface:

```js
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC721 {
	function balanceOf(address _owner) external view returns (uint256);
	function ownerOf(uint256 _tokenId) external view returns (address);
	function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) external payable;
	function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
	function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
	function approve(address _approved, uint256 _tokenId) external payable;
	function setApprovalForAll(address _operator, bool _approved) external;
	function getApproved(uint256 _tokenId) external view returns (address);
	function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

contract Selector {
	function getInterfaceId() external pure returns (bytes4) {
		return type(IERC721).interfaceId; // 0x80ac58cd
	}
}
```

Since `interfaceId` should only include standard function signatures, it does not include optional methods. Separate interfaces are defined for such optional methods. For example, for ERC721 metadata, it would look like the following:

```js
    bytes4(keccak256('name()')) == 0x06fdde03
    bytes4(keccak256('symbol()')) == 0x95d89b41
    bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd

    => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f

    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;
```

The final version of the ERC721 token smart contract would look like this:

```js
	function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
	return
		interfaceId == type(IERC721).interfaceId ||
		interfaceId == type(IERC721Metadata).interfaceId ||
		super.supportsInterface(interfaceId);
}
```

In the verifying smart contract, it is common to specify a constant for checking the called smart contracts. This significantly saves gas costs on computations.

```js
	bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
```

#### References:
- [EIP-165: Standard Interface Detection](https://eips.ethereum.org/EIPS/eip-165)
- [Example with ERC721](https://ethereum.stackexchange.com/questions/82822/obtaining-erc721-interface-ids)
- [Purpose of interfaceId](https://ethereum.stackexchange.com/questions/71560/erc721-interface-id-registration)
- [OpenZeppelin Documentation](https://docs.openzeppelin.com/contracts/4.x/api/utils#introspection)
- [Explanation of EIP165](https://medium.com/@chiqing/ethereum-standard-erc165-explained-63b54ca0d273) - Open in incognito mode
