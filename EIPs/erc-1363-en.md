# ERC-1363: Payable Token

The ERC-1363 standard extends the functionality of the ERC-20 token by allowing the execution of code immediately after the `transfer()`, `transferFrom()`, or `approve()` functions within a single transaction. This standard helps to avoid double gas payment, as the additional call is made within the same transaction of the token transfer or approval.

Important! The ERC-1363 standard is an extension of the ERC-20 standard and is fully backward compatible. This means it does not override the standard functions `transfer()`, `transferFrom()`, or `approve()`.

The `IERC1363.sol` standard extends the token implementation of `ERC-20` with new functions.

```solidity
interface IERC1363 is IERC20, IERC165 {
  function transferAndCall(address to, uint256 amount) external returns (bool);
  function transferAndCall(address to, uint256 amount, bytes calldata data) external returns (bool);
  function transferFromAndCall(address from, address to, uint256 amount) external returns (bool);
  function transferFromAndCall(address from, address to, uint256 amount, bytes calldata data) external returns (bool);
  function approveAndCall(address spender, uint256 amount) external returns (bool);
  function approveAndCall(address spender, uint256 amount, bytes calldata data) external returns (bool);
}
```

|```transferAndCall()```|```transferFromAndCall()```|```approveAndCall()```|
|-|-|-|
|Under the hood, it makes a standard function call to `transfer()`, and then makes an additional function call to the address of the **token recipient**.|Under the hood, it makes a standard function call to `transferFrom()`, and then makes an additional function call to the address of the **token recipient**.|Under the hood, it makes a standard function call to `approve()`, and then makes an additional function call to the address of the **entity granted permission** to use the token.|

>To execute code after calling `transfer()` or `transferFrom()`, the token recipient must be a **contract** and implement the `IERC1363Receiver.sol` interface.

>```solidity
>interface IERC1363Receiver {
>  function onTransferReceived(address spender, address sender, uint256 amount, bytes ?calldata data) external returns (bytes4);
>}
>```

>To execute code after calling `approve()`, the address that is granted permission to spend the token must be a **contract** and implement the `IERC1363Spender.sol` interface.
>```solidity
>interface IERC1363Spender {
>  function onApprovalReceived(address sender, uint256 amount, bytes calldata data)  external returns (bytes4);
>}
>```

## Examples
1. [Repo](https://github.com/vittominacori/erc1363-payable-token) и [документация](https://vittominacori.github.io/erc1363-payable-token/#ierc1363receiver) with some examples of standard implementation by Vittorio Minacori, the author of the ERC-1363: Payable Token standard:
2. [LinkToken от Chainlink](https://github.com/smartcontractkit/LinkToken/blob/f307ea6d4c/contracts/v0.4/ERC677Token.sol). The implementation is based on ERC677Token, which inspired the creation of ERC-1363. The idea is very similar, but unfortunately, the standard has not been officially adopted.

## Links
1. [ERC-1363: Payable Token](https://eips.ethereum.org/EIPS/eip-1363)
2. [Implementation of IERC1363 interface by OpenZeppelin](https://docs.openzeppelin.com/contracts/4.x/api/interfaces#IERC1363)
