// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ILendingAdapter.sol";
import "./interfaces/ILendingPool.sol";

/**
 * @title Aave adapter
 * @notice This adapter contract is created to demonstrate interaction with the Aave protocol
 * Capabilities:
 * 1. Provide liquidity
 * 2. Withdraw liquidity
 * 3. Take a loan
 * 4. Repay a loan
 * 5. Liquidate a position
 * @dev The address of the ILendingPool contract is set in the constructor for the Ethereum network
 */
contract AaveLendingAdapter is ILendingAdapter {
    using SafeERC20 for IERC20;

    ILendingPool lendingPool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    IERC20 public tokenA; // collateral token
    IERC20 public tokenB; // debt token

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /**
    * @notice Adding liquidity and simultaneously collateral for a loan
    * @param amount The amount of tokenA to be deposited into the Aave protocol as liquidity
    */
    function addCollateral(uint256 amount) external {
        tokenA.safeTransferFrom(msg.sender, address(this), amount);

        tokenA.safeApprove(address(lendingPool), amount);
        lendingPool.deposit(address(tokenA), amount, address(this), 0);
    }

    /**
    * @notice Withdrawal of liquidity and simultaneous collateral for a loan
    * @param amount The amount of tokenA to be withdrawn from the Aave protocol
    */
    function withdrawCollateral(uint256 amount) external {
        lendingPool.withdraw(address(tokenA), amount, address(this));
        tokenA.safeTransfer(msg.sender, amount);
    }

    /**
    * @notice Borrowing an asset from the Aave protocol
    * @param amount The amount of tokenB to be borrowed
    * @param interestRateMode The type of interest rate calculation
    */
    function borrow(uint256 amount, uint256 interestRateMode) external {
        lendingPool.borrow(address(tokenB), amount, interestRateMode, 0, address(this));
        tokenB.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Loan repayment, which includes returning the debt.
     * @param amount The amount of tokenB for loan repayment.
     * @param rateMode The type of interest rate calculation.
     */
    function repayBorrow(uint256 amount, uint256 rateMode) external {
        tokenB.safeTransferFrom(msg.sender, address(this), amount);

        tokenB.safeApprove(address(lendingPool), amount);
        lendingPool.repay(address(tokenB), amount, rateMode, address(this));
    }

    /**
     * @notice Position liquidation.
     * @param borrower The address of the user whose position is being liquidated.
     * @param repayAmount The amount for repaying the user's position.
     */
    function liquidate(address borrower, uint256 repayAmount) external {
        tokenB.safeTransferFrom(msg.sender, address(this), repayAmount);

        tokenB.safeApprove(address(lendingPool), repayAmount);
        lendingPool.liquidationCall(address(tokenA), address(tokenB), borrower, repayAmount, false);

        tokenA.safeTransfer(msg.sender, tokenA.balanceOf(address(this)));
    }
}
