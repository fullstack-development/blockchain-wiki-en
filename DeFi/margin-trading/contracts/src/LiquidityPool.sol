// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice Contract storage for providing liquidity.
 * It is assumed that liquidity management is carried out by providers through the use of functions: deposit() and withdraw().
 */

contract LiquidityPool {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 public totalDebt;

    mapping(address => uint256) liquidityProviders;
    mapping(address => uint256) borrowers;

    error LiquidityPool_CallerIsNotLiquidityProvider(address caller);
    error LiquidityPool_CallerIsNotBorrower(address caller);
    error LiquidityPool_InsufficientLiquidity();

    event LiquidityAdded(address liquidityProvider, uint256 amount);
    event LiquidityWithdrawn(address liquidityProvider, uint256 amount);
    event Borrowed(address borrower, uint256 amount);
    event Repaid(address borrower, uint256 amount);

    modifier onlyLiquidityProvider(address sender) {
        if (liquidityProviders[sender] == 0) {
            revert LiquidityPool_CallerIsNotLiquidityProvider(sender);
        }

        _;
    }

    modifier onlyBorrower(address sender) {
        if (borrowers[sender] == 0) {
            revert LiquidityPool_CallerIsNotBorrower(sender);
        }

        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
    }

    /**
 * @notice Allows you to provide funds for lending
 * @param amount The amount of the asset to be added to the contract
 * @dev The user providing the token will be referred to as a liquidity provider
 */
    function deposit(uint256 amount) external {
        liquidityProviders[msg.sender] = amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit LiquidityAdded(msg.sender, amount);
    }

   /**
 * @notice Allows the liquidity provider to withdraw their funds
 * @param amount The withdrawal amount
 * @dev Available for calling by the user who provided their funds to the contract.
 * Withdrawal can be partial, but not exceeding the provided amount
 */
    function withdraw(uint256 amount) external onlyLiquidityProvider(msg.sender) {
        if (amount > liquidityProviders[msg.sender]) {
            amount = liquidityProviders[msg.sender];
        }

        token.safeTransfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, amount);
    }

    /**
 * @notice Allows borrowing funds provided by liquidity providers
 * @param amount The loan amount
 * @dev The loan amount is recorded in the 'borrowers' mapping
 */
    function borrow(uint256 amount) external {
        if (amount > token.balanceOf(address(this))) {
            revert LiquidityPool_InsufficientLiquidity();
        }

        totalDebt += amount;
        borrowers[msg.sender] = amount;

        token.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    /**
 * @notice Allows a borrower to repay the debt
 * @param amount The repayment amount
 */
    function repay(uint256 amount) external onlyBorrower(msg.sender) {
        totalDebt -= amount;
        borrowers[msg.sender] -= amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Repaid(msg.sender, amount);
    }

    /**
 * @notice Returns the debt amount for a specific borrower
 * @param borrower The address of the borrower's account
 */
    function getDebt(address borrower) external view returns (uint256) {
        return borrowers[borrower];
    }
}
