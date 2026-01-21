# Aqua protocol

**Author:** [Pavel Naidanov](https://github.com/PavelNaydanov) 🕵️‍♂️

[Aqua](https://1inch.com/aqua) - is a protocol for managing liquidity (shared liquidity layer), developed by the 1inch team, which allows liquidity providers to supply assets to multiple trading strategies at once without the need to lock them in liquidity pools.

Instead of locking liquidity, the provider or maker sets virtual balances on the Aqua smart contract and specifies the strategy in which these balances will be avail

The functionality of the protocol is described with the catchy slogan *"Shared liquidity to unlock DeFi capital"*.

**Problem Statement**

The protocol is designed to solve three problems:
- **Inefficient capital usage:** Research by 1inch shows that only a small portion of liquidity in pools is actually active in the market. Most of the time, this liquidity is only needed for price discovery during swaps.
- **Liquidity fragmentation:** From the perspective of a liquidity provider, capital needs to be distributed across different protocols, each with its own pools, fee tiers, and mechanisms. This is quite a labor-intensive process.
- **Capital lock-up:** Liquidity provided to a traditional liquidity pool can't be used in external protocols, DAOs, lending, or other yield strategies. This makes it impossible to use liquidity elsewhere while it's committed to pools, bringing us back to the inefficient capital usage mentioned in point 1.

|Problem|Traditional AMMs|Aqua|
|--------|----------------|----|
|Idle liquidity| 85–97% of liquidity sits idle|The same capital works across multiple strategies|
|Fragmentation|Capital is split across pools/protocols|Single liquidity participates in multiple strategies|
|Locked capital|Tokens lose composability|Funds remain with the maker|

## How does it work in practice?

The protocol's operation is very well and clearly documented in the [whitepaper](https://github.com/1inch/aqua/blob/main/whitepaper/aqua-dev-preview.md).

![](./images/aqua-architecture.png)
*// Diagram taken from the whitepaper*

**Main workflow:**

- `ship()` — Maker sets virtual balances for a strategy  
- `dock()` — Maker resets virtual balances for a strategy  
- `pull()` — Strategy pulls tokens from the maker during a swap in favor of the taker  
- `push()` — Taker sends tokens in favor of the maker

**Workflow explanations:**

The maker sets virtual balances on Aqua using the [ship()](https://github.com/1inch/aqua/blob/main/src/Aqua.sol#L40) and [dock()](https://github.com/1inch/aqua/blob/main/src/Aqua.sol#L54) functions to allocate assets for use in specific applications (shown as Aqua App in the diagram) and strategies.

A strategy is a way to utilize the maker's liquidity. Essentially, it's a smart contract implementation that additionally regulates how the taker interacts with the maker's liquidity.

> Why additionally? Because this is partially handled by the Aqua smart contract itself — it updates user balances and performs the actual asset transfer. However, the pricing, conditions, and swap process are all implemented within the Aqua App/strategy smart contract.

The taker interacts with the application, which calls the [push()](https://github.com/1inch/aqua/blob/main/src/Aqua.sol#L72) and [pull()](https://github.com/1inch/aqua/blob/main/src/Aqua.sol#L63) functions in Aqua. This executes the actual swap between the taker and the maker, while also updating the virtual balances on the Aqua smart contract.

Let's take an [example](https://github.com/1inch/aqua/blob/main/examples/apps/XYCSwap.sol) provided by the developers, which performs a swap between the maker and the taker through an Aqua App that implements strategy A.

Pay attention to the diagram below. It illustrates the process where the taker swaps ETH for the maker's USDT.

![](./images/aqua-swap-process.png)

1. First, the maker must allow strategy A to use their USDT. To do this, they call the function `ship(address app, bytes calldata strategy, [USDT], [100e6])`. This sets the maker's virtual USDT balance for use in strategy A.
2. Now the taker can call the `swap()` function on the `AquaApp.sol` smart contract. This initiates the exchange of ETH for USDT.  
3. Under the hood, `AquaApp.sol` will calculate the exchange rate and call the `pull()` function, which will transfer USDT from the maker to the taker.
4. `AquaApp.sol` will make a callback to the taker (assuming the taker is a smart contract in this setup).  
5. Inside that callback, the taker will verify the receipt of USDT and call the `push()` function on Aqua, which will transfer ETH from the taker to the maker.

## Aqua Smart Contracts

In this section, we'll break down the smart contracts of the Aqua protocol. To do that, we'll take a look at the code they implement.

General list of smart contracts:
- [AquaApp](https://github.com/1inch/aqua/blob/main/src/AquaApp.sol): Base smart contract for building applications that interact with Aqua
- [Aqua](https://github.com/1inch/aqua/blob/main/src/Aqua.sol): Core smart contract that implements the protocol and governs the exchange between the maker and the taker
- [BalanceLib](https://github.com/1inch/aqua/blob/main/src/libs/Balance.sol): Helper library for working with the storage where the maker's virtual balances are kept  
- [AquaRouter](https://github.com/1inch/aqua/blob/main/src/AquaRouter.sol): Entry point for interacting with the protocol

## Aqua app

In order for a maker to provide liquidity to a strategy, that strategy needs to be created first. This is where "app builders" come in — they implement the strategy. It's recommended to use the base smart contract [AquaApp.sol](https://github.com/1inch/aqua/blob/main/src/AquaApp.sol), which your smart contract should inherit from.

```solidity
import { TransientLock, TransientLockLib } from "@1inch/solidity-utils/contracts/libraries/TransientLock.sol";
import { IAqua } from "./interfaces/IAqua.sol";

// Base smart contracts for the application
abstract contract AquaApp {
    using TransientLockLib for TransientLock;

    ...

    // Aqua smart contract address
    IAqua public immutable AQUA;

    // State storage for reentrancy protection
    mapping(address maker => mapping(bytes32 strategyHash => TransientLock)) internal _reentrancyLocks;

    // Modifier to protect the strategy from reentrancy
    modifier nonReentrantStrategy(address maker, bytes32 strategyHash) {
        _reentrancyLocks[maker][strategyHash].lock();
        _;
        _reentrancyLocks[maker][strategyHash].unlock();
    }

    constructor(IAqua aqua) {
        AQUA = aqua;
    }

    // An internal function that your smart contract should use to safely handle the transfer of assets from the taker to the maker.
    function _safeCheckAquaPush(address maker, bytes32 strategyHash, address token, uint256 expectedBalance) internal view {

        require(_reentrancyLocks[maker][strategyHash].isLocked(), MissingNonReentrantModifier());

        (uint256 newBalance,) = AQUA.rawBalances(maker, address(this), strategyHash, token);
        require(newBalance >= expectedBalance, MissingTakerAquaPush(token, newBalance, expectedBalance));
    }
}
```

As you can see, the requirements for creating your application's smart contract are not very strict. Conceptually, the application should look like this:

```solidity
contract MyAquaApp is AquaApp {
    // Strategy parameters
    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        bytes32 salt; // Salt that will make the strategy unique
    }

    constructor(IAqua aqua) AquaApp(aqua) { }

    // Swap function
    function swapExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        bytes calldata takerData
    )
        external
        // Reentrancy protection
        nonReentrantStrategy(strategy.maker, keccak256(abi.encode(strategy)))
        returns (uint256 amountOut)
    {
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        // Logic for calculating amountOut
        require(amountOut >= amountOutMin, InsufficientOutputAmount(amountOut, amountOutMin));

        // Transfer of assets from the maker to the taker
        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);

        // Callback to the taker, where they can perform additional actions or verify the receipt of assets from the maker
        ISwapCallback(msg.sender).swapCallback(tokenIn, tokenOut, amountIn, amountOut, strategy.maker, address(this), strategyHash, takerData);

        // Verification of the safe transfer of assets from the taker to the maker
        _safeCheckAquaPush(strategy.maker, strategyHash, tokenIn, balanceIn + amountIn);
    }
}
```

It's important to note that "app builders" is an abstract term referring to the creators of strategies. At the same time, anyone can create applications/strategies. In other words, there are no restrictions preventing a maker from creating their own strategy for their own liquidity that operates through Aqua.

## Aqua

In this section, we'll take a look at the central smart contract [Aqua.sol](https://github.com/1inch/aqua/blob/main/src/Aqua.sol) — the reason we're all here. The code is very simple and quite short. Just 81 lines.

The key part here is the storage of virtual balances, which is a mapping of all possible keys used to identify who provided liquidity, to whom, how much, and in what way.

```solidity
struct Balance {
    uint248 amount;
    uint8 tokensCount;
}

mapping(address maker =>
    mapping(address app =>
        mapping(bytes32 strategyHash =>
            mapping(address token => Balance)))) private _balances;
```

It's worth noting that `Balance` stores not only the `amount` (the amount of tokens allowed for the strategy), but also `tokensCount` — the total number of tokens in the strategy.

This helps save gas when reading from storage. In the [Balance.sol](https://github.com/1inch/aqua/blob/main/src/libs/Balance.sol#L39) library, `amount` and `tokensCount` are packed into a single slot.

Lexically, `tokensCount` could have been stored in a separate mapping, but that would require an additional storage read.

### Router

The [AquaRouter.sol](https://github.com/1inch/aqua/blob/main/src/AquaRouter.sol) smart contract is the entry point for interacting with the protocol.

![](./images/aqua-router.png)

The router's code is empty and simply inherits functionality from:
1. [Aqua.sol](https://github.com/1inch/aqua/blob/main/src/Aqua.sol): core functionality for managing virtual balances.  
2. [Simulator.sol](https://github.com/1inch/solidity-utils/blob/master/contracts/mixins/Simulator.sol): used for safely simulating calls via `delegatecall` without changing the blockchain state.  
3. [Multicall.sol](https://github.com/1inch/solidity-utils/blob/master/contracts/mixins/Multicall.sol): allows executing multiple router calls within its context and in a single transaction.

The `Simulator.sol` and `Multicall.sol` smart contracts use the `delegatecall` opcode to delegate the call and execute the operation in the context of `Aqua.sol`.

```solidity
contract Simulator {
    error Simulated(address delegatee, bytes data, bool success, bytes result);

    function simulate(address delegatee, bytes calldata data) external payable {
        (bool success, bytes memory result) = delegatee.delegatecall(data);
        // Interrupts transaction execution and returns call data
        revert Simulated(delegatee, data, success, result);
    }
}
```

```solidity
contract Multicall {
    function multicall(bytes[] calldata data) external {
        for (uint256 i = 0; i < data.length; i++) {
            // Self-call to execute operations
            (bool success,) = address(this).delegatecall(data[i]);
            if (!success) {
               // Handling a failed call
               ...
            }
        }
    }
}
```

### ship Function

For a maker to provide liquidity, they need to call the [ship()](https://github.com/1inch/aqua/blob/main/src/Aqua.sol#L40) function on the Aqua smart contract. This function sets the virtual balances on Aqua.

Physically, the assets remain with the maker — either on a contract or an EOA, depending on how the maker integrates with Aqua.

Let's take a look at the `ship()` function code.

```solidity
function ship(address app, bytes calldata strategy, address[] calldata tokens, uint256[] calldata amounts) external returns(bytes32 strategyHash) {
    // Hashing the strategy data
    strategyHash = keccak256(strategy);
    uint8 tokensCount = tokens.length.toUint8();

    // Check that the maximum number of tokens for which the maker can add virtual balances is not exceeded
    require(tokensCount != _DOCKED, MaxNumberOfTokensExceeded(tokensCount, _DOCKED));

    emit Shipped(msg.sender, app, strategyHash, strategy);
    for (uint256 i = 0; i < tokens.length; i++) {
        Balance storage balance = _balances[msg.sender][app][strategyHash][tokens[i]];

        // Check that the balances for the token are zero
        require(balance.tokensCount == 0, StrategiesMustBeImmutable(app, strategyHash));

        // Write virtual balances
        balance.store(amounts[i].toUint248(), tokensCount);
        emit Pushed(msg.sender, app, strategyHash, tokens[i], amounts[i]);
    }
}
```

### dock Function

To withdraw liquidity, the maker needs to call the [dock()](https://github.com/1inch/aqua/blob/main/src/Aqua.sol#L54) function. Calling this function will reset the virtual balances on the Aqua smart contract.

Let's take a look at the `dock()` function code.

```solidity
function dock(address app, bytes32 strategyHash, address[] calldata tokens) external {
    for (uint256 i = 0; i < tokens.length; i++) {
        // Retrieve virtual balances from storage
        Balance storage balance = _balances[msg.sender][app][strategyHash][tokens[i]];

        // Check that the number of tokens matches the ones previously set
        require(balance.tokensCount == tokens.length, DockingShouldCloseAllTokens(app, strategyHash));

        // Reset virtual balances for the token
        balance.store(0, _DOCKED);
    }
    emit Docked(msg.sender, app, strategyHash);
}
```

### pull Function

For the taker to use the maker’s liquidity, the [pull()](https://github.com/1inch/aqua/blob/main/src/Aqua.sol#L63) function must be called on the Aqua smart contract. This call updates the maker’s balances and transfers assets from the maker to the taker.

```solidity
function pull(address maker, bytes32 strategyHash, address token, uint256 amount, address to) external {
    Balance storage balance = _balances[maker][msg.sender][strategyHash][token];
    (uint248 prevBalance, uint8 tokensCount) = balance.load();

    // Balance update
    balance.store(prevBalance - amount.toUint248(), tokensCount);

    // Transfer from maker to taker
    IERC20(token).safeTransferFrom(maker, to, amount);
    emit Pulled(maker, msg.sender, strategyHash, token, amount);
}
```

### push Function

For the taker to transfer their part of the asset to the maker, the [push()](https://github.com/1inch/aqua/blob/main/src/Aqua.sol#L63) function must be called on the Aqua smart contract. This call updates the taker’s balances and transfers assets from the taker to the maker.

```solidity
function push(address maker, address app, bytes32 strategyHash, address token, uint256 amount) external {
    Balance storage balance = _balances[maker][app][strategyHash][token];
    (uint248 prevBalance, uint8 tokensCount) = balance.load();
    require(tokensCount > 0 && tokensCount != _DOCKED, PushToNonActiveStrategyPrevented(maker, app, strategyHash, token));

    // Update maker's balance
    balance.store(prevBalance + amount.toUint248(), tokensCount);

    // Transfer from taker to maker
    IERC20(token).safeTransferFrom(msg.sender, maker, amount);
    emit Pushed(maker, app, strategyHash, token, amount);
}
```

## Risks or What You Need to Know

The protocol is not a silver bullet — it doesn't solve all the existing problems found in traditional AMMs with their pools. For example, it's important to understand that front-running protection in Aqua is exactly the same as in Uniswap. None! In some sense, Uniswap offers slippage protection, whereas in Aqua this responsibility falls entirely on the "app builders".

Makers will also be exposed to impermanent loss. However, in this case, it heavily depends on the strategy.

**Scam Protection**

A maker who sets virtual balances for a malicious strategy will lose their assets. In this regard, makers still need to consciously provide their liquidity to different strategies.

**Maker Reliability**

A taker integrating with a maker should understand that virtual balances in Aqua do not guarantee the actual presence of assets. Therefore, selecting a maker and routing swaps between different makers through Aqua still remains the taker's responsibility.

In this regard, Aqua is not supposed to guarantee the maker's real balance — it is merely an intermediate layer.

**Maker's Economic Losses**

The chosen strategy may not always be profitable. So it's important to keep in mind these golden rules:
- Diversify strategies across different types  
- Monitor the ratio between virtual and real balances  
- Set balances according to the needs of the strategy

**Smart Contract Hack**

The only real protection against hacks is going through multiple audits. In this regard, Aqua itself is simple, and I don't think there will be many attack vectors left for hackers. However, their battleground will be in the strategies. That’s why strategies should be built using the most modern and robust security practices available.

## Conclusion

The protocol is not a new type of DEX and not a full-fledged product. It's a tool designed to let makers provide their liquidity without the need to lock it up.

Aqua's architecture is based on a virtual balance system that manages liquidity without actually holding it. This allows multiple strategies to share the same liquidity while keeping the assets under the maker's control.

There’s no doubt that it should become much easier and more profitable for makers to provide their capital through the Aqua protocol. Takers may face increased costs due to the need to find the right maker, select a strategy, and higher gas fees if the strategy is complex. However, those costs can be offset by the efficiency of the strategy.

At the same time, a new competitive space is opening up for "app builders", where they can test their skills in creating successful strategies.

In my view, Aqua is a rethinking of liquidity management. And it's probably one of the most interesting innovations in DeFi at the end of 2025 and the beginning of 2026. Looking forward to seeing new strategies built on Aqua.

P.S. 1inch’s interest in creating Aqua lies in their own strategy called [SwapVm](https://github.com/1inch/swap-vm). But that’s a whole different story!

## Links

1. [Whitepaper](https://github.com/1inch/aqua/blob/main/whitepaper/aqua-dev-preview.md)
2. [Code repository](https://github.com/1inch/aqua/blob/main/README.md)
3. Analytical [dashboard](https://dune.com/1inch/idle) 1inch. Shows the inefficiency of capital usage within liquidity pools
