// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IFlashLoanReceiver.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingAdapter.sol";
import "./interfaces/IUniswapV2Router02.sol";

/**
 * @title Loan Liquidator Contract
 * @notice Liquidates the position of the specified user using flashLoan() without the use of its own funds.
 * Only gas fees are required.
 */
contract Liquidator is IFlashLoanReceiver {
    using SafeERC20 for IERC20;

    ILendingPool lendingPool;
    ILendingAdapter lendingAdapter;
    IUniswapV2Router02 router;

    IERC20 tokenA; // collateral token
    IERC20 tokenB; // debt token

    constructor(address _lendingPool, address _lendingAdapter, address _router) {
        lendingPool = ILendingPool(_lendingPool);
        lendingAdapter = ILendingAdapter(_lendingAdapter);
        router = IUniswapV2Router02(_router);

        tokenA = lendingAdapter.tokenA();
        tokenB = lendingAdapter.tokenB();
    }

    /**
    * Liquidates the borrower's position using flashLoan()
    * @param borrower The address of the borrower
    * @param repayAmount The amount to liquidate the borrower's debt
    */
    function liquidate(address borrower, uint256 repayAmount) external {
        address[] memory assets = new address[](1);
        assets[0] = address(tokenB);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = repayAmount;

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        bytes memory params = abi.encode(borrower, msg.sender);

        /// Take a flash loan and expect the protocol to call the executeOperation() function on our contract,
        /// where we receive assets in the loan and use them to liquidate the borrower's position.
        lendingPool.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            params,
            0
        );
    }

    /**
    * Callback function called by the Aave protocol as part of the flashLoan() operation.
    * @param amounts An array of amounts for each asset.
    * @param premiums The fees for each asset that need to be returned along with the borrowed assets at the end of the transaction.
    * @param params Packed data passed by the flashLoan() caller.
    */
    function executeOperation(
        address[] calldata /** assets - Список активов полученных для займа**/,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /** initiator - Адрес вызывающего транзакцию flashLoan()**/ ,
        bytes calldata params
    ) external returns (bool) {
        (address borrower, address recipient) = abi.decode(params, (address, address));
        uint256 repayAmount = amounts[0];

        /// Approve the LendingPool contract to use the borrowed tokenB
        uint amountOwing = amounts[0] + premiums[0];
        tokenB.safeApprove(address(lendingPool), amountOwing);

        /// Liquidate the loan, repay the debt in the form of tokenB, and receive tokenA in return
        tokenB.safeApprove(address(lendingAdapter), repayAmount);
        lendingAdapter.liquidate(borrower, repayAmount);

        /// Swap tokenA for tokenB. We need the amount we will return at the end of the transaction as part of flashLoan()
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        tokenA.safeApprove(address(router), tokenA.balanceOf(address(this)));
        router.swapTokensForExactTokens(
            amountOwing,
            tokenA.balanceOf(address(this)),
            path,
            address(this),
            block.timestamp
        );

        /// Send the remaining tokenA to our own address. This is our profit
        tokenA.safeTransfer(recipient, tokenA.balanceOf(address(this)));

        return true;
    }
}
