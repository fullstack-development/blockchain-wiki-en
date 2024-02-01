# EIP-140: REVERT Instruction

**Author:** [Pavel Naydanov](https://github.com/PavelNaydanov) 🕵️‍♂️

The EIP-140 standard proposes adding the `REVERT` instruction, which has found wide application in smart contracts written in Solidity. The use of this instruction allows to **halt** execution, **revert** changes to the blockchain state, and **return** the reason for the halt.

_Did you know!?_ The `REVERT` instruction was only proposed on February 6, 2017. Prior to that, no such instruction existed.

Before the standard's implementation, developers used `assert()` to roll back transaction execution upon certain conditions. Unlike `REVERT`, using `assert()` consumed all the remaining gas, regardless of where it was called in the code.

The `REVERT` instruction is represented by the operation code [`0xfd`](https://www.evm.codes/#fd?fork=shanghai). This operation code takes two parameters, which are the last ones on the stack:
- **offset**. A memory offset indicating the returned data
- **size**. The size of the returned data

_Important!_ Semantically, the use of `REVERT` in relation to memory and memory cost is identical to the `RETURN` instruction and takes the same parameters.

### Ways to use revert in Solidity code

Returning a transaction without error information:


```solidity
function withdraw(uint256 amount) external {
    if (_balance < amount) {
      revert();
    }
    ...
}
```

Returning the transaction with a specified text error:

```solidity
function withdraw(uint256 amount) external {
    if (_balance < amount) {
      revert("Insufficient amount");
    }
    ...
}
```

Returning the transaction using a [custom error](https://soliditylang.org/blog/2021/04/21/custom-errors/):

```solidity
error InsufficientAmount();

function withdraw(uint256 amount) external {
    if (_balance < amount) {
      revert InsufficientAmount();
    }
    ...
}
```

## Links

1. [EIP-140: REVERT Instruction](https://eips.ethereum.org/EIPS/eip-140)
2. Solidity [Documentation](https://docs.soliditylang.org/en/v0.8.23/control-structures.html#revert) on the revert() instruction
3. For those interested in the [history](https://github.com/ethereum/EIPs/pull/206/commits) of the discussion on the implementation of EIP
