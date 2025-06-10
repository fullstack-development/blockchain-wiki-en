# ERC-6909: Minimal Multi-Token Interface

**Author:** [Pavel Naydanov](https://github.com/PavelNaydanov) 🕵️‍♂️

The [ERC-6909](https://eips.ethereum.org/EIPS/eip-6909) standard is an alternative to the [ERC-1155: Multi Token Standard](https://eips.ethereum.org/EIPS/eip-1155) for managing multiple tokens from a single smart contract.

Key differences from ERC-1155:
- The interface doesn't require implementing a callback mechanism for the token recipient.
- No support for batch calls, where multiple token operations occur in a single transaction.
- The token approval system for third-party usage has been redesigned.

The ERC-6909 interface provides minimal functionality, which helps reduce the smart contract code size and transaction execution costs.

_Important!_ Any smart contract implementing ERC-6909 must support [ERC-165: Standard Interface Detection](https://eips.ethereum.org/EIPS/eip-165) by default.

_Interesting!_ [Vectorized](https://github.com/Vectorized), the developer behind projects like [solady](https://github.com/Vectorized/solady), [ERC721A](https://github.com/chiru-labs/ERC721A), and [multicaller](https://github.com/Vectorized/multicaller), participated in the development of the standard.

## Reference Implementation

The [reference implementation](https://eips.ethereum.org/EIPS/eip-6909#reference-implementation) is taken from the ERC-6909 specification and simplified by me for quick understanding by developers. I recommend reviewing the reference first, then continuing with the rest of the article.

```solidity
contract ERC6909 {
    /// @notice Owner Balances
    mapping(address owner => mapping(uint256 id => uint256 amount)) public balanceOf;

    /// @notice Granted permissions for third-party token usage
    mapping(address owner => mapping(address spender => mapping(uint256 id => uint256 amount))) public allowance;

    /// @notice Operator permissions
    mapping(address owner => mapping(address spender => bool)) public isOperator;

    /// @notice Token transfer on behalf of the owner
    function transfer(address receiver, uint256 id, uint256 amount) public returns (bool) {
        if (balanceOf[msg.sender][id] < amount) revert InsufficientBalance(msg.sender, id);

        balanceOf[msg.sender][id] -= amount;
        balanceOf[receiver][id] += amount;

        emit Transfer(msg.sender, msg.sender, receiver, id, amount);
        return true;
    }

    /// @notice Token transfer by third parties, requires granted permission
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public returns (bool) {
        if (sender != msg.sender && !isOperator[sender][msg.sender]) {
            uint256 senderAllowance = allowance[sender][msg.sender][id];

            if (senderAllowance < amount) revert InsufficientPermission(msg.sender, id);
            if (senderAllowance != type(uint256).max) {
                allowance[sender][msg.sender][id] = senderAllowance - amount;
            }
        }

        if (balanceOf[sender][id] < amount) revert InsufficientBalance(sender, id);

        balanceOf[sender][id] -= amount;
        balanceOf[receiver][id] += amount;

        emit Transfer(msg.sender, sender, receiver, id, amount);
        return true;
    }

    /// @notice Granting permission for third-party token transfer with a token amount limit
    function approve(address spender, uint256 id, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
        return true;
    }

    /// @notice Granting permission for token transfer by an operator without a token amount limit
    function setOperator(address spender, bool approved) public returns (bool) {
        isOperator[msg.sender][spender] = approved;
        emit OperatorSet(msg.sender, spender, approved);
        return true;
    }

    function _mint(address receiver, uint256 id, uint256 amount) internal {
      balanceOf[receiver][id] += amount;
      emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(address sender, uint256 id, uint256 amount) internal {
      balanceOf[sender][id] -= amount;
      emit Transfer(msg.sender, sender, address(0), id, amount);
    }
}
```

## Changing the Balance Storage Structure

The balance storage structure is the first thing to pay attention to. Unlike ERC-1155, there are changes.

```solidity
// ERC-1155 из OpenZeppelin
mapping(uint256 id => mapping(address account => uint256)) private _balances;

// ERC-6909 из OpenZeppelin
mapping(address owner => mapping(uint256 id => uint256)) private _balances;
```

The mapping responsible for storing an account's balance starts with the owner's address, not the token ID.

This fundamentally only affects the interaction interface. To retrieve all user balances, you still need to implement additional functions in the smart contract or index the data off-chain. This is because you need to know all token IDs owned by the account, and the base implementation doesn’t store this information by default.

## No Callback

According to the ERC-1155 standard, a smart contract that acts as a token recipient must implement the `ERC1155TokenReceiver` interface.

This interface requires implementing one of the functions depending on the chosen token transfer method (single or batch):
```solidity
-  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4);
-  function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4);
```

In ERC-6909, developers can still use callbacks, but the implementation is entirely up to them and can be arbitrary.

ERC-6909 does not define a callback mechanism. This helps reduce the size of the base smart contract implementation and the number of operations during execution, making it more efficient in terms of gas and complexity.

## Changes in Token Transfers

Similar to callbacks, the standard takes the same approach with batch operations.

ERC-1155 requires the implementation of additional functions:
```solidity
- function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;
- function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);
```

ERC-6909 no longer mandates batch operations and doesn’t require their implementation just for the sake of standard compliance.

Batch operations can be added at the developer's discretion and tailored to the specific needs of the project.

**Token Transfer Functions**

The transfer is as close as possible to the ERC-20 standard implementation, with slight modifications.

```solidity
- function transfer(address receiver, uint256 id, uint256 amount) public returns (bool);
- function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public returns (bool);
```

`Sender` and `receiver` are the familiar `from` and `to`. An `id` is added to specify the token identifier involved in the transfer. The addition of `id` is very reminiscent of ERC-721 and ERC-1155.

## Flexible Approval System

In ERC-1155, approvals can only be granted to an operator via a function call:

```solidity
function setApprovalForAll(address _operator, bool _approved) external;
```

ERC-6909 introduces a hybrid approval system. There are two ways to grant approval:
- **To an operator**, allowing unlimited use of tokens on behalf of the user. The operator can manage any of the user’s tokens (with any `id`).
- **To an arbitrary account**, with a limit on the number of tokens it can use on behalf of the user.

Таким образом интерфейс ERC-6909 предоставляет две функции для реализации работы с апрувом:

```solidity
- function setOperator(address spender, bool approved) public returns (bool);
- function approve(address spender, uint256 id, uint256 amount) public returns (bool);
```

This mechanism is quite flexible, but there’s a nuance when an account is granted approval through both functions. In such cases, the standard performs checks in the following order:
1. Check if the account is an operator.
2. If not an operator, check the `allowance` granted via the `approve()` call.

Approval is only checked when using the `transferFrom()` function.

```solidity
function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public returns (bool) {
    // If the sender is transferring tokens themselves or has been granted operator rights, the tokens are sent immediately.
    // Otherwise, adjust the remaining allowance available to the caller.
    if (sender != msg.sender && !isOperator[sender][msg.sender]) {
        uint256 senderAllowance = allowance[sender][msg.sender][id];
        if (senderAllowance < amount) revert InsufficientPermission(msg.sender, id);

        if (senderAllowance != type(uint256).max) {
            allowance[sender][msg.sender][id] = senderAllowance - amount;
        }
    }

    // Balance updates and event emission

    return true;
}
```

Thus, for an operator who has been granted a limited approval (via the `approve()` function), the `allowance` will not be changed.

## Token Metadata

With the ERC-6909 standard, you can implement both fungible and non-fungible tokens simultaneously.  
The metadata implementation for such tokens is moved outside the core standard into a separate extension and is optional.

**Why optional?** The answer is simple: for managing LP tokens (or other types of tokens), properties like `name`, `symbol`, or `URI` might not be important. That’s why metadata is optional and excluded from the base implementation, but its usage is still standardized.

Currently, only the OpenZeppelin library implements metadata as an extension to the standard. (Solmate doesn’t have smart contracts for metadata, and in [Solady the metadata is hardcoded into the base implementation](https://github.com/Vectorized/solady/blob/main/src/tokens/ERC6909.sol#L97C1-L112C79)).

Next, let’s take a look at how metadata smart contracts are implemented in OpenZeppelin.

_Important!_ At the time of writing, everything related to ERC-6909 in OpenZeppelin is marked as draft.

**ERC6909Metadata.sol**

```solidity
contract ERC6909Metadata {
    struct TokenMetadata {
        string name;
        string symbol;
        uint8 decimals;
    }

    mapping(uint256 id => TokenMetadata) private _tokenMetadata;

    function name(uint256 id) public view virtual returns (string memory) {
        return _tokenMetadata[id].name;
    }

    function symbol(uint256 id) public view virtual override returns (string memory) {
        return _tokenMetadata[id].symbol;
    }

    function decimals(uint256 id) public view virtual override returns (uint8) {
        return _tokenMetadata[id].decimals;
    }
}
```

There are two things of interest here:
1. All functions — `name()`, `symbol()`, `decimals()` — take a single `id` argument. This means each token will have its own parameters.
2. OpenZeppelin uses a combination of `mapping` and `struct` to store data — a classic approach for optimizing data storage.

**ERC6909TokenSupply.sol**

```solidity
contract ERC6909TokenSupply {
    mapping(uint256 id => uint256) private _totalSupplies;

    function totalSupply(uint256 id) public view virtual override returns (uint256) {
        return _totalSupplies[id];
    }

    /// @dev Override the `_update` function to update the total supply of each token id as necessary.
    function _update(address from, address to, uint256 id, uint256 amount) internal virtual override {
      ...
    }
}
```

`Total supply`, just like `name`, `symbol`, and so on, is individual for each token.

**ERC6909ContentURI.sol**

```solidity
contract ERC6909ContentURI is ERC6909, IERC6909ContentURI {
    string private _contractURI;
    mapping(uint256 id => string) private _tokenURIs;

    function contractURI() public view virtual override returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return _tokenURIs[id];
    }
}
```

This contract stores metadata required for NFTs. `contractURI` is used to declare general collection data. `tokenURI` is used to declare individual metadata for each token.

**Thus, by using a combination of metadata contract extensions — ERC6909Metadata, ERC6909TokenSupply, and ERC6909ContentURI — the standard can manage both fungible and non-fungible tokens at the same time.**

## Removal of "safe" Naming

The naming conventions `safeTransfer()` and `safeTransferFrom()` can be misleading, especially in the context of ERC-1155 and ERC-721 standards, since they require external calls to recipient addresses (if the recipient is a smart contract). This means control is passed to an arbitrary contract.

According to the ERC-6909 standard, removing the word "safe" from all function names is considered less misleading.

## Real-World Usage

Unlike many proposed token standards, ERC-6909 was immediately tested in Uniswap v4.

ERC-6909 serves as proof of a user's assets within the protocol.

It works quite simply: after performing an operation (swap, removing liquidity), the user can leave their asset inside the protocol and receive an ERC-6909 token in return. Next time, to use the asset within the protocol, it's enough to burn the equivalent amount of ERC-6909.

For example, a user swaps `USDT` for `USDC`. They send `USDT`, but instead of receiving `USDC`, they mint an equivalent amount of ERC-6909. The `USDC` stays inside the protocol.  
Later, the user decides to swap back to `USDT` using `USDC`. To do this, they simply burn the ERC-6909 token, and the protocol returns `USDT`.

In this way, ERC-6909 significantly reduces gas costs when moving assets.  
Minting an ERC-6909 token is cheaper than transferring `USDC` in terms of gas. That’s because minting involves a single storage write and a `Mint()` event, while most tokens add extra checks during transfers—like whitelists or other custom logic.

This technology is especially useful for traders who perform many operations in a short period of time, and for liquidity providers who rebalance their positions.

More details in the [official Uniswap documentation](https://docs.uniswap.org/contracts/v4/concepts/erc6909).

## Conclusion

ERC-6909 is one of those rare standards that simplifies the system instead of making it more complex. Thanks to this simplification, any implementation of the standard is easier to understand, has a smaller footprint, and is cheaper to use with multiple tokens.

ERC-6909 is **not** backward compatible with ERC-1155!

That said, I want to highlight the ability to seamlessly combine management of both fungible and non-fungible tokens.  
A single ERC-6909 smart contract can manage both ERC-20 tokens and NFTs.

_Important!_ This comes with the caveat that all NFTs must be implemented within a single collection, since the `contractURI()` function does not support multiple collections.

## Links

1. [ERC-6909: Minimal Multi-Token Interface](https://eips.ethereum.org/EIPS/eip-6909#reference-implementation)
2. [Имплементация в solady](https://github.com/Vectorized/solady/blob/main/src/tokens/ERC6909.sol)
3. [Имплементация в solmate](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC6909.sol)
4. [Имплементация в OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC6909/draft-ERC6909.sol)
5. [ERC-6909 Minimal Multi-Token Standard](https://www.rareskills.io/post/erc-6909) от RareSkills
