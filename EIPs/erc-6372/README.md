# ERC-6372: Contract Clock

**Author:** [Pavel Naydanov](https://github.com/PavelNaydanov) 🕵️‍♂️

_Important!_ At the time of writing this article, the standard was in the "**Review**" phase.

This EIP proposes a standard interface for contracts to implement "**clocks**" within a smart contract. **By clocks**, it means any business logic of a smart contract that is tied to the storage or verification of time.

Usually, within a smart contract, [block properties](https://docs.soliditylang.org/en/latest/units-and-global-variables.html#block-and-transaction-properties) are used for working with time in the code: `block.timestamp` - the time of the current block in seconds, or `block.number` - the number of the current block. The standard proposes to standardize this experience.

## Implementation of the Standard

To use the standard, it is enough to implement an interface in your contract, which will contain just two functions: `clock()` and `CLOCK_MODE()`.


```solidity
interface IERC6372 {
  function clock() external view returns (uint48);
  function CLOCK_MODE() external view returns (string);
}
```

### CLOCK_MODE()

The `CLOCK_MODE()` function should return the **mode**. The mode determines the mechanism for using time in the contract. Smart contract logic can be based on `block.timestamp`, `block.number`, or another variant of custom time-binding implementation.

**Examples of return values:**

- The contract uses the block number
  > If the block number is used based on the EVM opcode "NUMBER" ([0x43](https://www.evm.codes/#43?fork=shanghai)) => **mode=blocknumber&from=default**
  > If the block number is based on another blockchain => **mode=blocknumber&from=[CAIP-2-ID]**, where [CAIP-2-ID] is the blockchain identifier [CAIP-2](https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-2.md), for example, eip155:1
- The contract uses timestamp
  > **mode=timestamp**
- The contract uses another mode
  > **mode=[Any mode name]**

### clock()

The `clock()` function should return the current time on the smart contract for the set **mode** (CLOCK_MODE). This can be any integer value that can define the block number, timestamp, etc.

_Important!_ The `clock` function returns `uint48`.

The standard's authors believe that the type `uint48` is sufficient for the return value. They provide calculations for the **timestamp** mode. At a block creation rate of 10,000 blocks per second, the size of the return value will be sufficient until the year 2861. Using a type smaller than `uint256` significantly reduces the cost of writing and reading from storage, which helps save on gas.

## Application

The authors of the standard are developers working on the [OpenZeppelin](https://www.openzeppelin.com/) library. Therefore, the standard is primarily applied to contracts of the library.

For example, for **governance**, the standard has been implemented starting with version 4.9.0. It can be found in the [GovernorVotes](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/governance/extensions/GovernorVotes.sol) extension for the Governor contract.


```solidity
function clock() public view virtual override returns (uint48) {
    try token.clock() returns (uint48 timepoint) {
        return timepoint;
    } catch {
        return SafeCast.toUint48(block.number);
    }
}
```
This piece of code is tied to the `clock()` function call of the voting token contract. To understand what the returned `timepoint` value represents, one needs to look at the [ERC20Votes](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/token/ERC20/extensions/ERC20Votes.sol) extension of the ERC-20 contract. This extension turns a regular token into a voting token and implements the ERC-6372 interface. That's what we are here for. 😅


```solidity
/**
  * @dev Clock used for flagging checkpoints.
  * Can be overridden to implement timestamp based checkpoints (and voting).
  */
function clock() public view virtual override returns (uint48) {
    /// returns current block's number
    return SafeCast.toUint48(block.number);
}

/**
  * @dev Description of the clock
  */
function CLOCK_MODE() public view virtual override returns (string memory) {
/// Checks that the standard is not overridden and works as expected
    require(clock() == block.number, "ERC20Votes: broken clock mode");

/// Returns the set mode for the clock, which indicates working with the block number
    return "mode=blocknumber&from=default";
}
```

In the global concept of **governance**, the "clocks" function participates in implementing the **snapshot** mechanism. This mechanism records the number of available votes for users tied to the current block number. This allows a user to vote on new proposals in the **governance** system, where it is first checked that the user has enough tokens for voting at the start of the voting period.

## Links

1. [ERC-6372: Contract clock](https://eips.ethereum.org/EIPS/eip-6372)
2. [ERC20 Votes: ERC5805 and ERC6372](https://www.rareskills.io/post/erc20-votes-erc5805-and-erc6372)
