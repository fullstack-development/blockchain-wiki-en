// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import "./interfaces/ILiquidityPool.sol";
import "./interfaces/ISimpleOrderBook.sol";

/**
 * @notice Main contract of the example.
 * Implements a simple way to operate with borrowed funds.
 * @dev Borrowed funds are taken from the LiquidityPool.sol contract.
 * Token exchange operations are simulated by the SimpleOrderBook.sol contract,
 * which is responsible for pricing and the actual token transfers.
 * All functions can only be called by the contract owner.
 */

contract MarginTrading is Ownable {
    using SafeERC20 for IERC20;

    ILiquidityPool liquidityPool;
    ISimpleOrderBook orderBook;

    IERC20 tokenA;
    IERC20 tokenB;

    uint256 public longDebtA;
    uint256 public longBalanceB;

    uint256 public shortDebtA;
    uint256 public shortBalanceB;

    error MarginTrading__InsufficientAmountForClosePosition();

    event LongOpened();
    event LongClosed();
    event ShortOpened();
    event ShortClosed();

    constructor(
        address _liquidityPool,
        address _orderBook,
        address _tokenA,
        address _tokenB
    ) {
        liquidityPool = ILiquidityPool(_liquidityPool); /// Контракт для взятия займа
        orderBook = ISimpleOrderBook(_orderBook); /// Контракт для физического проведение обмена одного токена на другой. Симулирует работу обменника.

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /**
 * @notice Opening a long position. Buying token B with the expectation that its price will increase in the future.
 * @param amountBToBuy The amount of token B to purchase.
 * @param leverage The leverage to increase the purchase amount with borrowed funds.
 * @dev It is implied that when the price of token B increases,
 * the sender of this function should manually call the closeLong() function to realize the profit.
 */

    function openLong(uint256 amountBToBuy, uint256 leverage) external onlyOwner {
/// Calculating the amount of token A required to purchase token B.
        uint256 amountAToSell = orderBook.calcAmountToSell(address(tokenA), address(tokenB), amountBToBuy * leverage);

/// Borrowing token A to purchase a larger amount of token B.
        liquidityPool.borrow(amountAToSell);

        longDebtA += amountAToSell;
        longBalanceB += amountBToBuy;

/// Buying token B in exchange for token A.
        tokenA.safeApprove(address(orderBook), amountAToSell);
        orderBook.buy(address(tokenA), address(tokenB), amountBToBuy);

        emit LongOpened();
    }

   /**
 * @notice Closing a long position.
 * Selling token B and settling the debt obligations, followed by profit withdrawal.
 */

    function closeLong() external onlyOwner {
        /// Selling all of the token B
        tokenB.safeApprove(address(orderBook), longBalanceB);
        uint256 balanceA = orderBook.sell(address(tokenB), address(tokenA), longBalanceB);

        if (balanceA < longDebtA) {
            revert MarginTrading__InsufficientAmountForClosePosition();
        }

        /// Closing the debt with token A, which was borrowed to purchase token B
        tokenA.safeApprove(address(liquidityPool), longDebtA);
        liquidityPool.repay(longDebtA);

        longDebtA = 0;
        longBalanceB = 0;

        /// Sending the profit in the form of token A from buying token B cheaper than it was sold to the contract owner
        uint256 freeTokenA = tokenA.balanceOf(address(this));
        tokenA.safeTransfer(owner(), freeTokenA);

        emit LongClosed();
    }

    /**
 * @notice Opening a short position. Selling token A with the expectation that its price will drop in the future.
 * @param amountAToSell The amount of token A to sell.
 * @param leverage The leverage to increase the selling amount with borrowed funds.
 * @dev It is implied that when the price of token A drops,
 * the sender of this function should manually call the closeShort() function to claim the profit.
 */

    function openShort(uint256 amountAToSell, uint leverage) external {
/// Borrowing token A for selling.
        liquidityPool.borrow(amountAToSell * leverage);

        shortDebtA += amountAToSell * leverage;

/// Selling token A, anticipating its price will drop, in exchange for token B.
        tokenA.safeApprove(address(orderBook), amountAToSell * leverage);
        shortBalanceB += orderBook.sell(address(tokenA), address(tokenB), amountAToSell * leverage);

        emit ShortOpened();
    }

    /**
     * @notice Closing a short position. Buying token B and settling debt obligations, followed by profit withdrawal.

    function closeShort() external {
        /// Buying token A at a lower price than sold, in exchange for token B.
        tokenB.safeApprove(address(orderBook), shortBalanceB);
        uint256 balanceA = orderBook.buy(address(tokenB), address(tokenA), shortDebtA);

        if (balanceA < longDebtA) {
            revert MarginTrading__InsufficientAmountForClosePosition();
        }

        /// Returning token A that was borrowed for selling.
        tokenA.safeApprove(address(liquidityPool), shortDebtA);
        liquidityPool.repay(shortDebtA);

        shortDebtA = 0;
        shortBalanceB = 0;

        /// Sending the remaining profit in the form of token B to the contract owner
        uint256 freeTokenB = tokenB.balanceOf(address(this));
        tokenB.safeTransfer(owner(), freeTokenB);

        emit ShortClosed();
    }
}
