# Pitfalls of Decentralized Trading

Let's discuss important aspects of decentralized finance, including:

- Price slippage during transaction execution
- Profit loss risks for liquidity providers
- Types of attacks during transaction execution.

## Price Slippage

When exchanging tokens, there is often a difference between the **expected price** before sending the transaction and the **actual price** after the transaction is executed. This difference is known as **price slippage**.

Yes, it's possible, and in fact, it occurs in almost every token exchange.

When making a trade on a decentralized exchange (DEX), the expected price may differ from the actual price. This is because the expected price depends on the past state of the blockchain, which can change between transaction creation and execution.

### Example

Let's consider a decentralized exchange based on the familiar Automated Market Maker (AMM) principle. In this exchange, liquidity providers have created a **liquid pair**.

Alice and Bob want to buy 1 ETH for USDT in our improvised exchange. The starting price of 1 ETH at the moment is 1,400 USDT. Both Alice and Bob send 1,400 USDT to the exchange.

Our exchange is decentralized and still operates on blockchain technology, which means transactions are executed atomically, step by step. Therefore, Bob's transaction is executed before Alice's transaction. But it's not just executed earlier, it also affects the price of ETH. It becomes more expensive relative to the price before the purchase. All according to the rules of AMM.

**How did this happen?** The price of an asset depends on the ratio of token amounts in the **liquidity pool**. If one token becomes scarce, its price slightly increases relative to the other token.

So, by the time Alice's transaction is executed, the price of ETH has already changed and becomes 1,540 USDT. But since Alice sent less USDT, she will receive less ETH. In other words, ETH becomes more expensive for her. This is the **price slippage** between the expected price and the actual price.

![Slippage](images/slippage.png)

_Important!_ Slippage is often expressed in percentages and indicates how much the token price can change.

The actual exchange price (the amount of tokens you will receive) depends not only on the token amounts in the liquidity pool but also on the order of transactions in the exchange. Specifically, it depends on the position of your transaction among other users' transactions.

_Important!_ The cost of the exchange depends on the order of transactions.

### Why does slippage occur?

The example of Alice and Bob allows us to identify two main causes of slippage: **liquidity** and **volatility**.

1. **Volatility** refers to the price fluctuations of an asset over a certain period of time. Every token is subject to volatility.
    - The more the token price fluctuates, the more slippage occurs between the start of the trade and its actual execution. This is due to the price fluctuations during the exchange process between different users.

    - Each purchase of a token increases its price since there is less of it in the pool. Each sale of a token decreases its price since there is more of it in the pool.

    - Volatility is usually measured as a percentage over a specific time period: a year, a month, or a day. Token volatility is measured by the deviation from the average price. The higher the deviation, the higher the level of volatility. Therefore, the more the token price changes over a period of time, the more volatile the token is.

The image below shows three types of price volatility for a token on a timeline.

![Volatility](images/slippage-volatility.png)

2. **Liquidity**: Some tokens are traded less frequently due to their lower popularity or novelty compared to other tokens. This means there is not enough liquidity in the pools to maintain a stable price. Therefore, buying a large quantity of tokens can significantly impact its current price.

Let's assume we want to buy 5 ETH.

![Liquidity](images/slippage-liquidity.png)

> **Left Chart**: Low liquidity. There are only 10 ETH left in the pool. The chart shows a significant shift along the curve of the token amount ratio. Buying only 5 ETH would greatly change the price of the remaining 5 ETH in the pool. According to AMM mathematics, it's not possible to deplete the pool. The remaining ETH will simply become very expensive.

> **Right Chart**: High liquidity. There are 1000 tokens in the pool. As shown in the chart, buying 5 ETH would have a much smaller impact on the amount of ETH in the pool. Consequently, the price of ETH would change insignificantly. In other words, the price would change less if someone else buys 5 ETH before us.

_Important!_ The higher the liquidity the less subject we are to price slippage as the expected price will almost match the actual price.

### How does Uniswap demonstrate slippage?

So, I've explained the reasons that lead to price slippage. The following patterns apply to slippage:

1. The more tokens involved in a trade, the more impact it has on the price.
2. The less liquidity in the liquidity pool, the greater the slippage.

You can confirm these patterns yourself in the [Uniswap application](https://app.uniswap.org/#/swap). Follow the link, select the tokens for exchange, and play around with the amount of tokens you're willing to provide to the liquidity pool.

In the additional swap options, there is a parameter called **"Price impact"**. It visually shows the influence of the trade price on the cost of the purchased token.

![Uniswap Price Impact](images/uniswap-price-impact.png)

Let's try to exchange USDT for ASM tokens. [ASM token](https://coinmarketcap.com/currencies/assemble-protocol/) is supported by the Assemble platform. On this platform, users and sellers can accumulate and spend reward points. Providers of such points can conduct promotional campaigns, providing benefits in the form of discounts to ASM token holders.

(Non-financial advice, I'm just taking this token as a bright example😉)

In the swap modal, Uniswap will warn me in advance that my trade will have a significant impact on the token's price. The impact is more than 91%. In this case, it means that we will buy a large portion of the ASM token liquidity.

![Uniswap Price Impact Warning](images/uniswap-price-impact-warning.png)

### Good News

_Important!_ Slippage is the change in token price during a trade and it can be either positive or negative.

Slippage can be categorized as **positive** or **negative**, meaning that the expected price can change in both directions, either higher or lower than expected.

![Slippage Categories](images/slippage-categories.png)

_Important!_ If the actual execution price is **lower** than the expected buy price, it is considered a **positive slippage** as it gives us a better price than initially anticipated.

_Important!_ If the actual execution price is **higher** than the expected buy price, it is considered a **negative slippage** as it provides us with a less favorable price than initially expected.

This applies to both buying and selling tokens.

### How does Uniswap handle slippage?

On some exchanges, you can manually set the slippage tolerance (0.5%, 1%, 5%). For example, in the decentralized exchange Uniswap, you can specify slippage in the swap settings.

![Uniswap Slippage Tolerance](images/uniswap-slippage-tolerance.png)

This value directly affects the time required for token swapping. If you set a low slippage tolerance, the exchange may take a long time or may not execute at all. If you set too high of a value, another user or bot may see our pending trade and outmaneuver us.

For users, this poses a potential issue or even a threat.

To warn about potential issues, Uniswap provides explicit prompts in the interface about what might happen during the exchange. Take a look at the screenshot from the Uniswap website below. This is an example of setting a low slippage tolerance.

![Uniswap Slippage Tolerance Low](images/uniswap-slippage-tolerance-low.png)

In the next screenshot, I set a high slippage tolerance, and Uniswap warns me about the potential frontrun threat.

Bots can front-run user transactions, thereby affecting the actual trade price. For users, this results in additional costs when executing the trade. This is how Frontrun works, which is one of the most common bot attacks.

We will discuss frontrunning in more detail later. For now, remember that setting a too high slippage tolerance creates various potential risks for the exchange.

![Uniswap Slippage Tolerance High](images/uniswap-slippage-tolerance-high.png)

## Impermanent Loss

Every liquidity pool relies on liquidity providers who reduce token volatility. The interest of a liquidity provider is to receive rewards for providing their tokens to the pool. Guaranteed rewards, what could be better? But it's not that simple.

When we provide liquidity to a pool, the price of the deposited asset can change. This factor is called **impermanent loss**. These losses are potential and unrealized. They only become permanent and realized when funds are withdrawn from the pool.

In simpler terms, the more the asset price changes, the greater the potential losses we may experience when withdrawing funds from the pool.

Let me explain with an example. There will be a lot of text and calculations. We're smoothly transitioning to a physics lesson... Just kidding! 🙈

### Example

**Scenario:**
Let's say I want to become a liquidity provider for the USDT/ETH token pool. Here's what we agree upon:
- We need to add tokens to the pool in a 1:1 ratio.
- The price of 1 ETH is 100 USDT.
- Let's assume that 1 ETH is worth $100.
- The total liquidity in the pool at the moment is 10 ETH and 1000 USDT.

**Process:**
1. I add 1 ETH and 100 USDT to the liquidity pool.
> According to our agreement, the value of 1 ETH and 100 USDT added to the liquidity pool is $200.
>
> Let's calculate our share of the deposited tokens relative to all the tokens in the pool, which amounts to 10%. This means that we will receive 10% of the fees from trades in our pool.
>
> Let's recall the AMM mechanism with the constant equation: **X** * **Y** = **K**, where
> **X** represents the amount of ETH,
> **Y** represents the amount of USDT,
> **K** is a constant value.
>
> In this case, 10 ETH * 1000 USDT = 10,000. This value should remain constant before and after any trades in the pool.

2. The price of 1 ETH rises to $400.
> Yes, it happened, but the token ratio in the pool still indicates that the price of ETH is 100 USDT. Arbitrage bots take advantage of this opportunity. They identify price discrepancies across different exchanges and engage in the process of "buying cheaper in one place, selling higher in another." They pocket the profit. We will discuss arbitrage bots in more detail later.

3. After the bots' activity, there are 5 ETH and 2000 USDT left in the pool.
> This way, our constant **K** of 10,000 is preserved. The price difference between 1 ETH in the pool and outside the exchange is also neutralized.

4. Now it's time to withdraw 10% of the liquidity we provided.
> This amounts to 0.5 ETH and 200 USDT. In dollar terms, it is $400. Twice the initially invested amount! Let's not forget about the fees collected from users for utilizing our liquidity pool for token swaps. Let's assume our reward is $20.

We earned $220 in net profit! Nice, right? Absolutely!

However, if we had simply held our ETH and USDT in a wallet, we would have had 1 ETH worth $400 and 100 USDT worth $100. Together, that would be $500.

The difference between the potential value of $500 and the realized value of $420 is the **impermanent loss**.

_Important!_ Remember that impermanent losses are unrealized until we withdraw the tokens from the pool. Moreover, the fee earnings should partially or completely offset the losses and ideally put us in a profit.

### Is there a way to avoid impermanent loss?

Unfortunately, a liquidity provider cannot completely avoid impermanent losses. But the risk can be mitigated by using pools with stablecoins and less volatile tokens.

To assess the impermanent loss when the token prices change, you can use graphical representations.

![Impermanent Loss](./images/impermanent-loss.png)

According to the graph, we can conclude that:
* A 1.25x price change results in a loss of 0.6%.
* A 1.50x price change results in a loss of 2.0%.
* A 1.75x price change results in a loss of 3.8%.
* A 2x price change results in a loss of 5.7%.
* A 3x price change results in a loss of 13.4%.
* A 4x price change results in a loss of 20.0%.
* A 5x price change results in a loss of 25.5%.

To quickly and conveniently calculate impermanent losses, you can use a specialized service. Try this [impermanent loss calculator](https://dailydefi.org/tools/impermanent-loss-calculator/). Any similar service will require inputting the token values at the time of liquidity addition to the pool and at the time of withdrawal.

## Arbitrage. Mev. Gas Auction

Let's dive into arbitrage.

Prices for the same asset can differ across different exchanges. When you buy tokens on one exchange and sell them on another to make a profit, that's called **arbitrage**.

In reality, it's not just about "buy low, sell high" but a mindset focused on assessing the token's value and demand. To generate profit, you often need to set up a complex chain of transactions.

![Arbitrage](./images/arbitrage.png)

_Important!_ Remember that you can also suffer losses if the token price drops during the transaction. Manual arbitrage is challenging to profit from, so the process is automated through programming.

Arbitrage bots influence market prices and other market participants. They balance token exchange rates across the market, increasing overall efficiency. This benefits users. In that sense, arbitrage is useful as it increases trading volume and commission revenue.

However, not all bots are helpful or even harmless. There is a range of bots that, in their pursuit of profit, can have a negative impact.

### What makes bots dangerous?

To understand how malicious bots work, it's necessary to comprehend the blockchain's structure and the work of miners.

When a transaction is sent to the blockchain, it is not executed immediately. It enters the **mempool** or **memory pool**, a small database of unconfirmed or pending transactions. When a transaction is confirmed by being included in a block, it is removed from the mempool.

Miners select transactions from the mempool to include in a block based on the highest profit they can gain. They can include, exclude, or change the order of transactions in the block at their discretion. The process of extracting such profit is called **Miner Extractable Value (MEV)**.

Alongside miners, bots also monitor the mempool because its contents are visible to everyone (we are still in the blockchain). Bots can execute their own transactions to front-run or follow the execution of a target transaction.

For example, upon seeing a large token deposit into a liquidity pool that will impact the price increase, a malicious bot can:

1. Make a purchase of tokens at a lower price.
2. Wait for the transaction to be pending.
3. Sell the tokens at the new higher price.

Bots can execute their own transactions by artificially increasing the gas price. This prompts miners to prioritize their transaction from the mempool based on the desire to extract maximum MEV.

The interesting part is that there can be multiple malicious bots. Competition arises among them to offer the highest gas price. This phenomenon is known as a **gas war**. Such a war increases the transaction fee for regular users.

The cost of token exchange on a DEX using AMM depends on the order of transactions. As you may have noticed, the order of transactions can be manipulated by offering a higher gas price. Bots try to position their transaction in a specific spot among other pending transactions. This creates attacks that exploit miners.

Let's look at the most common bot attacks:

1. **Front-running**

> A bot observes transactions and selects a suitable one that will bring it profit. It initiates a competing transaction with a higher gas price and expects its transaction to be confirmed before the victim's transaction.

For example, Alice wants to purchase a large number of tokens. This will lead to a price increase since fewer tokens will be in circulation, while the demand remains the same. The bot wants to buy the token before Alice does, so it conducts a front-running attack.

![Arbitrage Front-Running](./images/arbitrage-frontrun.png)

## Front-running

The attack proceeds as follows:
1. Alice initiates a token purchase, and her transaction enters the **mempool**.
2. The bot identifies Alice's transaction and applies its profit strategy. The strategy involves finding transactions that can significantly impact the token's price. After finding such a transaction, the bot aims to be the first to buy the token at the current price before it changes, intending to hold or sell it at a higher price in the future.
3. Alice's transaction is a perfect fit for the bot. It can profit by buying the tokens before her. So, the bot takes action and initiates its own token purchase transaction, which also enters the **mempool**. However, the bot offers a higher gas price to the miner compared to Alice's transaction. But the bot doesn't offer an excessively high price. It needs to consider the overhead costs of its actions and maintain a balance; otherwise, it could end up at a loss.
4. Meanwhile, the miner carries out their usual duties and creates a block of transactions. As mentioned before, they follow the principle of MEV, attempting to maximize their profit. Since there are numerous transactions in the **mempool**, there's a high chance that the victim's transaction has not yet been executed, and all the aforementioned bot manipulations with transactions have been successful.
5. Since the bot's transaction offers a higher gas price, it is logically prioritized by the miner and included in the block before Alice's transaction. This means that the bot's transaction will be executed before Alice's.

You might ask, what's wrong with this attack? After all, Alice will eventually buy her token anyway. Did we forget about the slippage? It will come as a surprise to Alice when she sees the difference between the actual and intended purchase price.

_Important!_ The bot's transaction, just like any other token purchase, will increase its price. Consequently, Alice will end up paying more than expected for the purchase and receiving fewer tokens since the bot buys them before her.

## Back-running

> The attack is similar to front-running, with the difference that the bot executes its own transaction immediately after the target transaction.

For example, the bot monitors the mempool for the emergence of new liquidity pools. If it finds a new pool, it buys as many tokens as possible. However, it doesn't buy all of them to allow other users to purchase the tokens.

Then the bot waits for the price to rise, and other users start buying the tokens. At this point, the bot sells the tokens at a higher price. The strategy aims to buy the token as early as possible to sell it at a higher price.

![Arbitrage Back-run](./images/arbitrage-backrun.png)

According to this scheme, the following scenario unfolds:
1. The bot discovers a new token that has recently appeared and buys it. Often, the price of such tokens is low.
2. Alice learns about this token and wants to buy it. Note that there are other users between the bot and Alice who have already purchased the token. In this case, Alice simply serves as a signal for the bot.
3. Alice initiates the token purchase, and her transaction enters the **mempool**.
4. The bot sees Alice's transaction and applies its profit strategy, which involves waiting for the token's price to rise. Remember that when Alice buys the token, its price will increase significantly. This growth is substantial since Alice is a wealthy buyer and always buys in large volumes.
5. Alice's transaction perfectly fits the bot's strategy, as it will drive up the price, allowing the bot to profit. The bot then initiates its own transaction to sell the token, which also enters the **mempool**. However, this time, the bot offers a lower gas price to the miner compared to Alice's transaction. The bot aims for its transaction to be executed as close as possible to Alice's.
6. Meanwhile, the miner carries out their usual duties and creates a block of transactions. Therefore, they first add Alice's transaction to buy the token and then the bot's transaction to sell the token.

Now you can ask again, what's the danger for Alice in this scenario? After all, she will buy before the bot. Yes, she will buy earlier, so it's not front-running but back-running. After Alice buys her tokens, the bot will sell its tokens. Remember that the bot bought a significant portion of the tokens for maximum profit?

Selling a large number of tokens can significantly crash the price of a new, unestablished token. As a result, Alice will be left holding tokens that have drastically dropped in price and turned into worthless pieces.

## Sandwich

> This attack combines both front-running and back-running.    

Let's jump straight to an example. Alice wants to buy a token on a decentralized exchange that uses an automated market maker model.

The bot, upon seeing Alice's transaction, creates two of its own transactions, which it inserts before and after Alice's transaction. The first transaction by the bot purchases the token, increasing the price of Alice's transaction, while the second transaction involves selling the token at a higher price with a profit.

![Arbitrage Sandwich](./images/arbitrage-sandwich.png)

According to this scheme, the following scenario unfolds:
1. The bot's strategy involves finding a transaction that will significantly increase the token's price.
2. Alice initiates the token purchase, and the transaction enters the **mempool**.
3. The bot, constantly monitoring the **mempool**, spots Alice's transaction and applies its profit strategy.
4. Alice's transaction is a perfect fit for the bot, as it will drive up the price and allow the bot to profit. The bot then initiates two transactions: one for buying the token, where it sets a higher gas price than Alice, and one for selling the token, where it sets a lower gas price than Alice.
5. Both transactions also enter the **mempool**.
6. Meanwhile, the miner carries out their usual duties and creates a block of transactions. Due to the correctly set gas prices, the miner executes the bot's first transaction before Alice's, and the second transaction follows.

In this case, the problem for Alice is slippage. The actual purchase price for Alice will be higher, and she will end up with fewer tokens than expected.

The bot was able to profit from the difference between the purchase and sale. It bought the token at a lower price with the first transaction and sold it at a higher price with the second transaction, pocketing the profit.

# Conclusion

That's all! We've explored many aspects of DEX. We've discussed why token prices can experience slippage and how to mitigate it, the risks of providing liquidity to pools with impermanent loss, and the main types of attacks.

You might be wondering, why do I need this theory?

If you continue delving into the world of decentralized finance, you'll have to tackle the issues we've discussed above in your own projects. As they say, forewarned is forearmed! And who knows, perhaps you'll be able to create a decentralized exchange without price slippage, impermanent loss, and with state-of-the-art protection against bot attacks.
