# Reserve finance

**Author:** [Pavel Naydanov](https://github.com/PavelNaydanov) 🕵️‍♂️

**[Reserve](https://reserve.org/)** is a protocol for launching and managing a synthetic asset backed 1:1 by a set of other digital assets. In the context of the protocol, such a synthetic asset is called an index, and its implementation is called a DTF.

**DTF (Decentralized Token Folio)** is a set of smart contracts that implement a synthetic asset as an ERC-20 token for Ethereum and L2 blockchains. DTF is designed to implement various products — from a stablecoin to an investment portfolio.

Conceptually, the protocol is similar to centralized ETF funds, but it operates fully on-chain.

## Key components

Reserve supports two main types of indexes: Yield DTF and Index DTF, which are used in different strategies.

**Yield DTF**

Allows autonomous management of yield-bearing assets (stETH, cUSDC, aUSDC, etc.), distributing income according to rules defined by the governance system.

**Index DTF**

Allows managing a set of assets (ETH, WBNB, AVAX, etc.) using from several to hundreds of tokens. The lightweight design removes the need for complex collateral management, making it possible to create large, transparent indexes with decentralized governance.

**Marketing describes the advantages of Index DTF as follows:**
- 10+ assets on Ethereum and 100+ assets on the Base blockchain.
- Almost any ERC-20 token is supported, no oracle required.
- Permissionless access: anyone can create an index token or mint an existing index.
- Flexible governance: any ERC-20 token can be used as a governance token. By default, Reserve’s RSR token is used.
- Automatic rebalancing implemented via auctions.

| Property   | Yield DTF (RTokens)          | Index DTF           |
| ---------- | ---------------------------- | ------------------- |
| Goal       | Yield-bearing assets         | Diversification     |
| Assets     | stETH, aUSDC, LST            | Any ERC20           |
| Revenue    | Auto-harvest + auctions      | Mint/TVL fees       |
| Complexity | High (many plugins)          | Low (1 contract)    |

Index DTF is optimized for passive portfolio diversification with regular tokens, while Yield DTF focuses on yield harvesting mechanisms.

In this article, we will take a detailed look at **Index DTF**. This is a newer and more concise solution that helps to understand how protocols of this kind are structured.

## Minting and redemption

We have defined that Index DTF is implemented using smart contracts. These smart contracts are fully compatible with the ERC-20 interface. Therefore, the index has the following basic functionality: transfer, minting, burning.

For a user, in the context of an index, **minting and redemption** are the two core processes that allow converting user assets into the index and back.

![](./images/reserve-mint-and-redemption.png)

Each index defines a set of collateral assets that the user must provide in exchange for the index token. In the screenshot, the set consists of three assets: USDC, USDT, ETH.

For the reverse exchange, the user transfers the index token and receives assets from the set.

**At what rate will the exchange happen?**

To calculate the rate, a formula is used that computes the amount of each token to be taken from the user during minting:

![](./images/reserve-mint-formula.png)

This formula is applied to each collateral token taken from the user. The desired amount of index tokens is multiplied by the balance of the token locked inside the protocol and divided by the total supply of the index token.

_Important!_ The exact same formula is applied for **redemption** to calculate the amount of collateral tokens that will be paid to the user in exchange for the index token.

This formula maintains the exchange rate and preserves the proportions of each collateral token relative to each other within the basket. These proportions are defined by the index creator during initialization. To do this, the creator supplies tokens to the smart contract in the required proportions and specifies the **basket unit parameter**.

**Basket unit**

The basket unit ({BU} — basket units) describes how many collateral tokens must be supplied to mint 1 index token.

If the basket unit is described as {100 USDC, 150 USDT, 0.1 ETH}, then it is easy to calculate how many collateral assets are needed to receive 2, 10, and so on index tokens.

|Index amount|USDC amount|USDT amount|ETH amount|
|-|-|-|-|
|1 INDEX|100 USDC|150 USDT|0.1 ETH|
|2 INDEX|200 USDC|300 USDT|0.2 ETH|
|...|...|...|...|
|10 INDEX|1000 USDC|1500 USDT|1 ETH|
|...|...|...|...|

**How to calculate the shares of collateral tokens in the basket?**

On smart contracts, the shares of each token are set during initialization by the index creator, and afterward only the proportions are preserved.

However, in the interface, it is necessary to display the percentage composition of collateral tokens in the basket. But how can this be done if all tokens are different?

For this purpose, the protocol defines one more parameter — **Unit of Account** (UoA), which specifies the unit in which all assets inside the protocol are compared.

For the basket {100 USDC, 150 USDT, 0.1 ETH}, a convenient UoA can be USD. Then USDC and USDT are pegged 1:1 to USD. For ETH, its USD price needs to be obtained.

Assume that 1 ETH = 3000 USD. Then we can calculate the proportions based on the basket unit.  
100 USD (100 USDC) + 150 USD (150 USDT) + 300 USD (0.1 ETH) = 550 USD. The values are taken from the table above.

Now we can calculate the proportions of the basket tokens.

||Token amount|Amount in USD|Token share %|
|-|-|-|-|
|USDC|100|100|≈ 18.2%|
|USDT|150|150|≈ 27.3%|
|ETH|0.1|300|≈ 54.5%|


At the same time, we chose dollars as the UoA denomination, but nothing prevents us from doing the same in another currency, for example ETH, BTC, or even a non-cryptocurrency.

**Zapper**

In Reserve, indexes can be backed by a large number of tokens, which is quite inconvenient for users. They need to prepare the required amount of each token from the index basket.

To improve this process, Reserve offers its own solution called **Zapper**, which allows a user to deposit a single token to mint an index token. Under the hood, the protocol converts the user’s token into the full set of basket tokens.

![](./images/reserve-zapper.png)

_Important!_ At the time of writing, the manual mode—where the user supplies each basket asset individually—is still available.

## Rebalancing

**Asset rebalancing** is the core function of the protocol. The task is to change the proportions of collateral tokens held in the index basket.

For example, the basket contains (USDC, USDT, ETH) in proportions (30%, 20%, 50%). A classic rebalancing task is to reduce the amount of USDC and increase the share of ETH in the basket, for example to (15%, 20%, 65%).

Technically, rebalancing is implemented via a Dutch auction.  
This is a descending-price auction, where a maximum exchange price is set at the start. For example, if the goal is to reduce the USDC share and increase the ETH share, the auction determines how much USDC can be received for 1 ETH.

Launching this process requires the participation of two roles:
- **Rebalance manager.** Either a governance smart contract or an address set during index initialization.
- **Auction launcher.** An address set during index initialization.

![](./images/reserve-auction-process.png)

1. The manager starts the rebalancing process, specifying the list of basket tokens, buy/sell limits, and other parameters. This call can be made via a governance vote.
2. An auction window is created for each token pair that requires adjustment.
3. The auction launcher initiates the Dutch auction.
4. The Dutch auction runs directly on the index smart contract, meaning the auction has direct access to the index tokens and its actions are limited by the rebalancing configuration.
5. Auction participants buy the asset that needs to be reduced by providing the asset that needs to be increased. When the auction goal is met or the time expires, the auction is closed.

## Index DTF architecture

In this section, we will analyze the smart contract architecture of **Index DTF** based on the [repository](https://github.com/reserve-protocol/reserve-index-dtf/tree/main).

**Entry point**

Studying the smart contracts is easy because the protocol has only one entry point. The smart contract [Folio.sol](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol) implements the core index logic:
- Basket implementation.
- Storage of collateral tokens.
- Minting and burning of the index token.

Characteristics of the `Folio.sol` smart contract:
- The contract is upgradeable and versioned using a custom solution.
- ERC-20 compatible, inheriting from OpenZeppelin’s ERC-20.
- Inherits from OpenZeppelin’s AccessControl to implement role-based access control.
- Uses classic OpenZeppelin reentrancy protection.

The diagram below shows the list of smart contracts that `Folio.sol` inherits from to implement these characteristics, as well as the actors that can interact with it.

![](./images/reserve-folio-structure.png)

Actors that can interact with the smart contract are defined by four green boxes:
1. **Default admin:** Can update basket tokens, configure settings (from fees to name), permanently stop index operation, and perform some other actions.
2. **User:** Any user can mint index tokens and redeem the index back into collateral tokens at any time. No pauses or freezes are предусмотрены.
3. **Rebalance manager:** Can initiate the rebalancing process, close an auction, and finalize the rebalancing of basket tokens.
4. **Auction launcher:** Can open an auction, close an auction, and stop the rebalancing process. The last permission seems illogical from a role separation perspective, but this is a design choice, not a vulnerability.

_Important!_ If the index is “deprecated” by the owner, this does not prevent users from redeeming index tokens for their deposited assets (calling the `redeem()` function). Redemption will happen at the rate defined by the basket token proportions at the moment the index is closed.

**Basket**

Now we are ready to see how the [security token basket](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L118) works.
```solidity
EnumerableSet.AddressSet private basket;
```

As we can see, the basket is a "set" from the OpenZeppelin library, which stores the addresses of collateral tokens. This prevents tokens from being duplicated in the basket. Interacting with the basket is simple:
```solidity
// Get a list of token addresses
basket.values();

// Add token address to basket
basket.add(token);

// Remove token address from basket
basket.remove(token);
```

We can encounter basket operations in different parts of a smart contract. `Folio.sol`.

For example functions [addToBasket()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L266) and [removeFromBasket()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L271) which are controlled by `defaultAdmin`.

Below, we will examine the function of adding a token to the basket.

```solidity
  function addToBasket(IERC20 token) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
      require(_addToBasket(address(token)), Folio__BasketModificationFailed());
  }

  function _addToBasket(address token) internal returns (bool) {
    // Prevents index tokens or zero tokens from being added to the basket
    require(token != address(0) && token != address(this), Folio__InvalidAsset());
    emit BasketTokenAdded(token);

    return basket.add(token);
}
```

An interesting thing here is that the token of the index itself (`address(this)`) can never be added to the basket. In other words, the index will never provide for itself. This is an important technical limitation.

Now we will look at the part of the function that removes the token from the basket.

```solidity
    function removeFromBasket(IERC20 token) external nonReentrant {
        ...

        // DefaultAdmin or any user can always remove a token from the basket if the token balance and its weight are equal to 0.
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
            (
              rebalance.details[address(token)].weights.spot == 0
              && IERC20(token).balanceOf(address(this)) == 0
            ),
            Folio__BalanceNotRemovable()
        );
        require(_removeFromBasket(address(token)), Folio__BasketModificationFailed());
    }

    function _removeFromBasket(address token) internal returns (bool) {
        emit BasketTokenRemoved(token);

        delete rebalance.details[token];

        return basket.remove(token);
    }
```

An interesting fact about removing a token from the basket. The `defaultAdmin` can lock collateral tokens inside the `Folio.sol` smart contract if they remove a token from the basket.

In this case, when redeeming the index token for collateral tokens, the user will not receive this token. For the user, it is safer when the index is managed by **governance** and a **timeLock**. This gives time to take action and perform redemption before the token is removed from the basket.

The protocol also notes in the code that token removal by any user may become unavailable if someone sends a small amount of the token being removed to the `Folio.sol` smart contract. In this case, only the `defaultAdmin` can remove the token from the basket. But if the `defaultAdmin` is **governance**, it will first be necessary to vote for this removal and wait for the **timeLock**.

**Minting**

The [mint()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L386C1-L433C6) function issues index tokens to any user who provides collateral. The main requirements are that the call is not in a reentrancy state and that the default admin has not closed the index.


```solidity
function mint(
    uint256 shares,
    address receiver,
    uint256 minSharesOut
) external nonReentrant notDeprecated sync returns (address[] memory _assets, uint256[] memory _amounts) {
    // Commissions are calculated here.
    ...
    uint256 totalFeeShares = ...

    // Subtract the calculated fees from the expected number of index tokens.
    uint256 sharesOut = shares - totalFeeShares;

    // Protection against slippage after commission deduction
    require(sharesOut != 0 && sharesOut >= minSharesOut, Folio__InsufficientSharesOut());

    // Calculate the amount of each collateral token to be debited from the user
    (_assets, _amounts) = _toAssets(shares, Math.Rounding.Ceil);

    // Write off the calculated share of each collateral token from the user
    uint256 assetLength = _assets.length;
    for (uint256 i; i < assetLength; i++) {
        if (_amounts[i] != 0) {
            SafeERC20.safeTransferFrom(IERC20(_assets[i]), msg.sender, address(this), _amounts[i]);
        }
    }

    // Issue an index token to the user
    _mint(receiver, sharesOut);

    // Record the information about fees for DAO
    daoPendingFeeShares += daoFeeShares;
    // Record information about fees for index recipients, which is set during initialisation.
    feeRecipientsPendingFeeShares += totalFeeShares - daoFeeShares;
}
```

Based on how many index tokens the user wants to receive, the code calculates the required amounts of each collateral token and deducts them from the user during the call.

What is interesting here is that the user receives the index tokens minus a fee, which is not immediately sent to the recipients (DAO and others).

To distribute the fees, the [distributeFees()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L478C1-L508C6) function must be called separately. This function mints the accumulated amount of index tokens to the fee recipient addresses.

**Redemption**

The [redeem()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L439C5-L465C6) function issues collateral tokens to the user in exchange for the index token. The only restriction is that it must not be performed during a reentrancy call.

```solidity
function redeem(
    uint256 shares,
    address receiver,
    address[] calldata assets,
    uint256[] calldata minAmountsOut
) external nonReentrant sync returns (uint256[] memory _amounts) {
    address[] memory _assets;
    // Calculate the amount of each security token to be issued to the user
    (_assets, _amounts) = _toAssets(shares, Math.Rounding.Floor);

    // Burn the index token at the user calling the function
    _burn(msg.sender, shares);

    // verifying that the user has correctly specified the minimum amount to receive for each token in the basket.
    uint256 len = _assets.length;
    require(len == assets.length && len == minAmountsOut.length, Folio__InvalidArrayLengths());

    for (uint256 i; i < len; i++) {
        require(_assets[i] == assets[i], Folio__InvalidAsset());
        // Slippage protection
        require(_amounts[i] >= minAmountsOut[i], Folio__InvalidAssetAmount(_assets[i]));

        // Issuing each token to the user
        if (_amounts[i] != 0) {
            SafeERC20.safeTransfer(IERC20(_assets[i]), receiver, _amounts[i]);
        }
    }
}
```

The index token redemption function is straightforward and clear. The key takeaway here is that it is always available for calling. This means a user can always exchange their index tokens to receive their collateral tokens.

**Rebalancing and Auction**

We combine the rebalancing and auction processes because they are two steps of a single, inseparable process. The call order looks like this:

![](./images/reserve-high-auction-flow.png)

The rebalancing process begins when the rebalancing manager initiates the process by calling the [startRebalance()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L589C1-L610C6) function.

```solidity
function startRebalance(
    TokenRebalanceParams[] calldata tokens,
    RebalanceLimits calldata limits,
    uint256 auctionLauncherWindow,
    uint256 ttl
) external onlyRole(REBALANCE_MANAGER) nonReentrant notDeprecated sync {
    RebalancingLib.startRebalance(
        basket.values(),
        rebalanceControl,
        rebalance,
        tokens,
        limits,
        auctionLauncherWindow,
        ttl,
        bidsEnabled
    );

    // Add new tokens to the basket
    for (uint256 i; i < tokens.length; i++) {
        _addToBasket(tokens[i].token);
    }
}
```

What's important here is that new tokens will only be added to the basket if the address passed to the `startRebalance()` function is unique. All other logic is tucked away in the [RebalancingLib.sol](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/utils/RebalancingLib.sol#L24) library.

Let's take a look at the most interesting parts.

```solidity
function startRebalance(
    address[] calldata oldTokens,
    IFolio.RebalanceControl storage rebalanceControl,
    IFolio.Rebalance storage rebalance, // Information about the rebalancing will be recorded here.
    IFolio.TokenRebalanceParams[] calldata tokens,
    IFolio.RebalanceLimits calldata limits,
    uint256 auctionLauncherWindow,
    uint256 ttl,
    bool bidsEnabled
) external {
    ...

    // We verify that the rebalancing lifetime (ttl) is within the tolerances.
    require(ttl != 0 && ttl >= auctionLauncherWindow && ttl <= MAX_TTL, IFolio.Folio__InvalidTTL());

    ...

    uint256 len = tokens.length;
    require(len > 1, IFolio.Folio__EmptyRebalance());

    // We store information about each token that will participate in the rebalancing.
    for (uint256 i; i < len; i++) {
        IFolio.TokenRebalanceParams calldata params = tokens[i];

        // We check various parameters for the token: set value, address, duplicates, rebalancing type (based on fixed weight in the basket or not).

        ...

        rebalance.details[params.token] = IFolio.RebalanceDetails({
            inRebalance: true,
            weights: params.weight,
            initialPrices: params.price,
            maxAuctionSize: params.maxAuctionSize
        });
    }

    // Saving information about the rebalancing process
    rebalance.nonce++;
    rebalance.limits = limits;
    rebalance.startedAt = block.timestamp;
    rebalance.restrictedUntil = block.timestamp + auctionLauncherWindow;
    rebalance.availableUntil = block.timestamp + ttl;
    rebalance.priceControl = rebalanceControl.priceControl;
    rebalance.bidsEnabled = bidsEnabled;

    emit IFolio.RebalanceStarted(
        rebalance.nonce,
        rebalance.priceControl,
        tokens,
        limits,
        block.timestamp,
        block.timestamp + auctionLauncherWindow,
        block.timestamp + ttl,
        bidsEnabled
    );
}
```

Here’s what is interesting:
1. The ttl (Time-To-Live) must be greater than the auction window (auctionLauncherWindow), but the ttl is capped at a maximum of 4 weeks.
2. Multiple auctions can be launched within the ttl, or none at all if the auctionLauncherWindow is set to 0.
3. Only one rebalancing process can be active at a time.

**auctionLauncherWindow** — can be equal to 0. When this parameter is non-zero, it splits the rebalancing process into two segments and affects the type of auction that can be launched in the future.

![](./images/reserve-rebalance-timing.png)

From the start of the rebalancing until the auction window expires, the auction can only be launched by the rebalancing manager via the [openAuction()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L619) function.

Once the auction window has ended but the rebalancing conditions have not been met, the auction can be launched by any account via the [openAuctionUnrestricted()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L646C14-L646C37) function.

As the name suggests, the auction will be launched without any restrictions to complete the rebalancing. It’s important to note that a minimum time window always remains for launching an "Unrestricted" auction. This is sufficient because the auction **must** start within the rebalancing period, but the auction itself can continue after the rebalancing ends.

The logic for opening an auction — creating a record of its start on the blockchain — is also tucked away in the `RebalancingLib.sol` library within the [openAuction()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/utils/RebalancingLib.sol#L122) function.

You can explore how an auction is opened on your own, while we move on to the more interesting logic responsible for bidding on an auction lot. Any user can call the [bid()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L720C1-L739C6) function during an auction.

```solidity
function bid(
  uint256 auctionId,
  IERC20 sellToken,
  IERC20 buyToken,
  uint256 sellAmount,
  uint256 maxBuyAmount,
  bool withCallback,
  bytes calldata data
) external nonReentrant notDeprecated sync returns (uint256 boughtAmt) {
  require(rebalance.bidsEnabled, Folio__PermissionlessBidsDisabled());
  Auction storage auction = auctions[auctionId];

// Get the purchase amount
  (, boughtAmt, ) = _getBid(auction, sellToken, buyToken, sellAmount, sellAmount, maxBuyAmount);

  // Complete the purchase and remove the token being sold from the basket if the auction target has been reached.
  if (RebalancingLib.bid(auction, auctionId, sellToken, buyToken, sellAmount, boughtAmt, withCallback, data)) {
      _removeFromBasket(address(sellToken));
  }
}
```

The function accepts a buy token and a sell token, as well as the amount of the sell token. Here, it is important to understand that:
- **sellToken:** This is the token the protocol is selling, meaning for the caller of the `bid()` function, it is the token they are buying.
- **buyToken:** This is the token the protocol is buying, meaning for the caller of the `bid()` function, it is the token they are selling.

Therefore, the **buyToken** will be debited from the user as part of the auction lot purchase.

The `bid()` function hides its logic in the `RebalancingLib.sol` library. We are interested in two functions: [getBid()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/utils/RebalancingLib.sol#L264) and [bid()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/utils/RebalancingLib.sol#L343C5-L343C18).

Let's take a look at these functions below.

```solidity
function getBid(
    IFolio.Rebalance storage rebalance,
    IFolio.Auction storage auction,
    IERC20 sellToken,
    IERC20 buyToken,
    GetBidParams memory params
) external view returns (uint256 sellAmount, uint256 bidAmount, uint256 price) {
    assert(params.minSellAmount <= params.maxSellAmount);

    // Calculate the auction purchase price
    price = _price(rebalance, auction, sellToken, buyToken);

    uint256 buyAvailable;
    {
        IFolio.RebalanceDetails memory buyDetails = rebalance.details[address(buyToken)];

        // The purchase limit is calculated based on the minimum token weight and the total rebalancing limit.
        uint256 buyLimit = Math.mulDiv(rebalance.limits.low, buyDetails.weights.low, D18, Math.Rounding.Floor);

        // Calculates how much has already been purchased
        uint256 buyLimitBal = Math.mulDiv(buyLimit, params.totalSupply, D27, Math.Rounding.Floor);
        buyAvailable = params.buyBal < buyLimitBal ? buyLimitBal - params.buyBal : 0;

        // Calculate the balance of tokens available for purchase according to the auction
        uint256 buyRemaining = buyDetails.maxAuctionSize > auction.traded[address(buyToken)]
            ? buyDetails.maxAuctionSize - auction.traded[address(buyToken)]
            : 0;

        // refund the minimum available amount or the remaining amount.
        buyAvailable = Math.min(buyAvailable, buyRemaining);

        ...
    }

    uint256 sellAvailable;
    {
        ...

        // Based on buyAvailable, calculate how many tokens can be sold.
        uint256 sellAvailableFromBuy = Math.mulDiv(buyAvailable, D27, price, Math.Rounding.Floor);
        sellAvailable = Math.min(sellAvailable, sellAvailableFromBuy);

        ...

        sellAvailable = Math.min(sellAvailable, sellRemaining);
    }

    ...

    // Total number of tokens available for purchase
    bidAmount = Math.mulDiv(sellAmount, price, D27, Math.Rounding.Ceil);
    require(bidAmount <= params.maxBuyAmount, IFolio.Folio__SlippageExceeded());
}
```

In the end, `getBid()` determines how many tokens it can sell and buy while adhering to all constraints, such as rebalancing limits, available balances, and the current price. It is worth noting that the price is calculated separately in the [getPrice()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/utils/RebalancingLib.sol#L427) function and, following the Dutch auction rule, decreases over time.

```solidity
function _price(
    IFolio.Rebalance storage rebalance,
    IFolio.Auction storage auction,
    IERC20 sellToken,
    IERC20 buyToken
) internal view returns (uint256 p) {
    IFolio.PriceRange memory sellPrices = auction.prices[address(sellToken)];
    IFolio.PriceRange memory buyPrices = auction.prices[address(buyToken)];

    ...

    uint256 elapsed = block.timestamp - auction.startTime;
    uint256 auctionLength = auction.endTime - auction.startTime;

    // Calculate the rate of price change coefficient
    uint256 k = MathLib.ln(Math.mulDiv(startPrice, D18, endPrice)) / auctionLength;

    // Calculate the present price
    p = Math.mulDiv(startPrice, MathLib.exp(-1 * int256(k * elapsed)), D18, Math.Rounding.Ceil);
    if (p < endPrice) {
        p = endPrice;
    }
}
```

What's interesting here is that the coefficient k is responsible for the rate of price change (represented by a natural logarithm). This coefficient depends on the starting and ending prices, as well as the auction duration. The greater the price difference and the shorter the auction, the higher the rate of price change.


All that's left now is to look at the logic of the token buyback itself in the [bid()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/utils/RebalancingLib.sol#L343) function.

```solidity
function bid(
    IFolio.Auction storage auction,
    uint256 auctionId,
    IERC20 sellToken,
    IERC20 buyToken,
    uint256 sellAmount,
    uint256 bidAmount,
    bool withCallback,
    bytes calldata data
) external returns (bool shouldRemoveFromBasket) {
    ...

    // The buyer receives the sell token
SafeERC20.safeTransfer(sellToken, msg.sender, sellAmount);

// Implementation of a callback if necessary to debit the buy token from the smart contract
if (withCallback) {
    IBidderCallee(msg.sender).bidCallback(address(buyToken), bidAmount, data);
} else {
    SafeERC20.safeTransferFrom(buyToken, msg.sender, address(this), bidAmount);
}
    ...

    // Storing information about how much was sold and purchased at auction
    auction.traded[address(sellToken)] += sold;
    auction.traded[address(buyToken)] += bought;

    emit IFolio.AuctionBid(auctionId, address(sellToken), address(buyToken), sold, bought);

    // Return true if the token should be removed from the basket
    return sellBalAfter == 0;
}
```

In addition to simple token movements between the transaction caller and the index smart contract, we can see that the caller can be a smart contract that pays for the auction purchase. However, the smart contract must implement the specific `IBidderCallee` interface.

The rebalancing and auction process ends when the time expires or when the [closeAuction()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L779) and [endRebalance()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L799) functions are physically called.

These are very simple functions:

```solidity
function closeAuction(uint256 auctionId) external nonReentrant {
  require(
      hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
          hasRole(REBALANCE_MANAGER, msg.sender) ||
          hasRole(AUCTION_LAUNCHER, msg.sender),
      Folio__Unauthorized()
  );
  ...

  // Set the current time as the auction end time
  auctions[auctionId].endTime = block.timestamp - 1;
}

function endRebalance() external nonReentrant {
    require(
        hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
            hasRole(REBALANCE_MANAGER, msg.sender) ||
            hasRole(AUCTION_LAUNCHER, msg.sender),
        Folio__Unauthorized()
    );

    // Set the current time as the rebalancing end time
    rebalance.availableUntil = block.timestamp;
}
```

Thus, we have covered the most significant and complex process of the protocol: rebalancing and auctions. Auctions have an alternative way of filling lots through specially registered "fillers" that implement integration with CowDAO. I’ll leave this as [homework for you](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L742C5-L773C6).

**Deployment and Index Updates**

Deployment is the process that deploys the index smart contract to the blockchain and prepares it for operation. For this, the protocol has implemented a separate smart contract, [FolioDeployer.sol](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/deployer/FolioDeployer.sol).

![](./images/reserve-deploy-process.png)

Fundamentally, two different types of indices can be deployed based on the management style: centralized by a single account or via a DAO. Smart contracts for the DAO can be deployed directly during the deployment process or separately and simply passed as the owner.

Under the hood, the index will be deployed as an upgradeable smart contract of the `TransparentUpgradeableProxy` type, but with some specific features. All settings will be initialized during the deployment call: from setting the index parameters to granting permissions and assigning roles. Interaction with the proxy for management is performed through the [FolioProxyAdmin.sol](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/folio/FolioProxy.sol#L14) smart contract.

Whoever owns the `FolioProxyAdmin.sol` can perform an upgrade to a new implementation. However, the new implementation must be registered within the protocol and must not be deprecated. In this way, the protocol ensures that an update cannot be performed to an implementation with vulnerabilities or bugs.

Let's look at the [upgradeToVersion()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/folio/FolioProxy.sol#L24C14-L24C30) function in the `FolioProxyAdmin.sol` smart contract, which implements this.

```solidity
function upgradeToVersion(address proxyTarget, bytes32 versionHash, bytes memory data) external onlyOwner {
    IFolioVersionRegistry folioRegistry = IFolioVersionRegistry(versionRegistry);

    // We check that the version is not prohibited.
    require(!folioRegistry.isDeprecated(versionHash), VersionDeprecated());
    // We check that the version is registered.
    require(address(folioRegistry.deployments(versionHash)) != address(0), InvalidVersion());

    address folioImpl = folioRegistry.getImplementationForVersion(versionHash);

    ITransparentUpgradeableProxy(proxyTarget).upgradeToAndCall(folioImpl, data);
}
```

In this section, we will look at the [FolioGovernance.sol](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/governance/FolioGovernor.sol) smart contract, which Reserve offers out of the box. Generally, this is a solution from OpenZeppelin, but there are a few differences from classic governance:

1. Dynamic **proposalThreshold**. In OpenZeppelin, this is set as a fixed value. In `FolioGovernor.sol`, it is calculated dynamically based on the total token supply at a given point in time:
   
    ```solidity
    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        uint256 threshold = super.proposalThreshold();
        uint256 pastSupply = Math.max(1, token().getPastTotalSupply(clock() - 1));

        // Calculate the supply threshold
        return (threshold * pastSupply + (1e18 - 1)) / 1e18;
    }
    ```
3. Dynamic **quorum**. `GovernorVotesQuorumFractionUpgradeable` is used to calculate the quorum as a fraction of the total supply of tokens at a given point in time.

    ```solidity
    function quorum(
        uint256 timepoint
    ) public view override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable) returns (uint256) {
        return super.quorum(timepoint);
    }
    ```
There are a few other differences, but these are mostly voting system settings. We'll skip them and move on. Governance smart contracts require a voting token.

When a user deploys an index, they can choose a DAO as the index management model and specify a voting token for the DAO. They can use their own ERC-20 token or the protocol's RSR token.

**RSR - Protocol Token**

**RSR** is an ERC-20 token required for governance, risk management, and use within the ecosystem.

RSR performs three main functions:
- **Staking**: Staking in Yield DTFs to provide capital in exchange for DTF yield.
- **Vote-locking on Index DTFs**: RSR is the default token for managing Index DTFs (basket changes or updating other parameters).
- **Deflationary sink**: A portion of the fees from each Index DTF is used to buy back RSR on the market and burn it, gradually reducing the circulating supply.

## Fees & revenue

Fees are a key driver for stakeholders involved in the operation of the index.

For Index DTFs, there are two explicit fees charged directly from each index token smart contract:
1. **TVL fee** (management fee). The size is strictly <10% APY (set by governance, usually 0.01-0.1% per year).
2. **Mint fee**. A fee for the issuance of the index.

Both fees are collected in the index token. When calling `mint()`, the user receives the index token minus the fee, and the fee information is recorded within the index smart contract.

In practice, the fee-related index tokens are created later. To do this, the public function [distributeFees()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L478C1-L508C6) must be called.

```solidity
function distributeFees() public nonReentrant sync {
    uint256 _feeRecipientsPendingFeeShares = feeRecipientsPendingFeeShares;
    feeRecipientsPendingFeeShares = 0;
    uint256 feeRecipientsTotal;

    // Minting of index tokens for commission recipients specified when creating the index
    uint256 len = feeRecipients.length;
    for (uint256 i; i < len; i++) {
        uint256 shares = (_feeRecipientsPendingFeeShares * feeRecipients[i].portion) / D18;
        feeRecipientsTotal += shares;

        _mint(feeRecipients[i].recipient, shares);

        emit FolioFeePaid(feeRecipients[i].recipient, shares);
    }

    // Minting an index token for DAO
    uint256 daoShares = daoPendingFeeShares + _feeRecipientsPendingFeeShares - feeRecipientsTotal;

    (address daoRecipient, , , ) = daoFeeRegistry.getFeeDetails(address(this));

    _mint(daoRecipient, daoShares);
    emit ProtocolFeePaid(daoRecipient, daoShares);

    daoPendingFeeShares = 0;
}
```

This allows fees to accumulate over time, so they can then be distributed in a single transaction. Distribution is a public function that can be called by any interested party.

Even though the fee-related index tokens are minted separately, the index's [totalSupply()](https://github.com/reserve-protocol/reserve-index-dtf/blob/main/contracts/Folio.sol#L356) function still accounts for the fees immediately, even if they haven't been physically distributed yet.

```solidity
function totalSupply() public view override returns (uint256) {
    (uint256 _daoPendingFeeShares, uint256 _feeRecipientsPendingFeeShares, ) = _getPendingFeeShares();

    // Add accumulated commissions to the existing index token volume
    return super.totalSupply() + _daoPendingFeeShares + _feeRecipientsPendingFeeShares;
}
```

## Risks

The Reserve protocol carries risks for the user, and its [documentation](https://reserve.org/protocol/risks/) suggests reviewing them. Looking ahead, my opinion is that they are logical and not that critical. It’s just something you need to be aware of.

**Smart Contracts**

The protocol is built using smart contracts. If bugs or vulnerabilities are discovered in them, it could lead to the loss of user assets. The protocol's smart contracts have undergone several security audits, but no audit can guarantee total security. In my view, this risk is inherent to any DeFi application.

**Oracle**

For Yield DTFs, there is a risk associated with oracle performance. Oracles are used to obtain real-time price data to calculate the collateral amount.

Therefore, if a specific oracle erroneously reports the price of a collateral token, the DTF might consider the collateral to be in default and attempt to exchange it for emergency collateral, potentially at a loss.

**Sandwich Attacks and MEV**

**MEV searchers** constantly scan the blockchain for profit extraction opportunities. When interacting with any AMM-based DEX, users should consider slippage, which determines how much profit searchers can extract from a transaction.

It’s worth remembering that there are ways to protect against MEV via [Flashbots RPC](https://docs.flashbots.net/).

**Governance Risks: Index Management via DAO**

The protocol offers a management system for DTFs out of the box. It provides full on-chain governance. The system's powers are extensive, making attacks possible.
These potential attacks could involve an attacker accumulating enough governance power to push through a malicious update, allowing them to steal funds.

These types of attacks are mitigated by the presence of specific roles in index management.

**Admin Risks: Centralized Index Management**

If a `Default admin` is used instead of `governance` for management, the administrator can:
- Remove a token from the basket, thereby freezing it.
- Stop **minting** (though redemption will still work).
- Upgrade to a malicious version (mitigated by the fact that the version must be in the versionRegistry).
- Shut down the index.

**Collateral Asset Risks**

Collateral asset risk is related to the fact that a collateral token might implement a blacklist that could include user addresses. This would make it impossible to get the "blacklisted" collateral token back, along with other tokens in the basket.

There are also some other risks that, in my opinion, are less interesting. For example, risks on the frontend part of the protocol which could be compromised, or the liability of other protocols whose tokens are used as collateral.

## Conclusions

**Reserve Index DTF** is a minimalist and elegant solution for creating on-chain indices that solves key DeFi problems: the complexity of asset diversification, portfolio creation, and the creation of collateralized stablecoins.

A single smart contract, `Folio.sol`, implements the following functionality:

- **Permissionless Launch**: Anyone can create an index with any basket of ERC-20 tokens without oracles. In the interface, this is currently marked as **coming soon**.

- **Automatic Rebalancing** via Dutch auctions — a decentralized AMM for portfolios.

- **Economy without Extra Fees**: Fees are only collected in the index token, which participates in the buyback and burning of the RSR token, thereby reducing its market supply.

- **Available Liquidity**: Exchange index tokens for collateral assets without restrictions based on the current basket proportions.

The architectural philosophy of **Reserve** is a competition of products: there is no "correct" basket, and no forced assets. The market itself will choose effective indices and weed out ineffective ones. In other words, it’s a "decentralized BlackRock" where any user can launch an ETF.

At the same time, risks remain for the user: management, MEV, governance attacks, and third-party collateral tokens.

## Links

1. [Reserve docs](https://reserve.org/protocol/)
2. Yield DTFs [repository](https://github.com/reserve-protocol/protocol)
3. Index DTFs [repository](https://github.com/reserve-protocol/reserve-index-dtf)
4. For those who enjoy watching videos, explore the protocol through a [series of educational films](https://reserve.org/protocol/video_overview/).
