// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Dutch auction
 * @notice The smart contract implements the sale of an ERC-721 (nft) token using a Dutch-type auction.
 * A Dutch auction involves a decrease in the value of an item over time.
 * The auction starts with the maximum price set.
 *Collected funds are moved to the specified wallet address.
 * @dev Smart contract roles:
 * - DEFAULT_ADMIN_ROLE. Can change the wallet address for withdrawing funds collected from the sale.
 * Can control the setting of the starting price per NFT.
 * - AUCTIONEER_ROLE. Can create and start an auction by calling the start() function or cancel it with cancel()
 */
contract DutchAuction is AccessControl {
    bytes32 public constant AUCTIONEER_ROLE = keccak256("AUCTIONEER_ROLE");

    uint256 private constant _DEFAULT_STARTING_PRICE = 1000 ether;
    uint256 private constant _MIN_AUCTION_TIME = 1 hours;

    struct Auction {
        IERC721 nft;
        uint256 tokenId;
        uint256 start;
        uint256 startingPrice;
        uint256 discountRatePerSecond;
        address auctioneer;
    }

    Auction private _auction;
    address private _wallet;
    uint256 private _startingPrice = _DEFAULT_STARTING_PRICE;

    event AuctionStarted(Auction auction);
    event AuctionCanceled(Auction auction);
    event AuctionFinished(Auction auction, address indexed winner, uint256 value);
    event WalletSet(address wallet);
    event StartingPriceSet(uint256 startingPrice);

    error AuctionNotStarted();
    error AuctionHasAlreadyStarted();
    error DiscountRatePerSecondNotEnough();
    error ValueNotEnough();
    error TransferNativeFailed();
    error AuctionIncorrectStartTime();
    error WalletAddressZero();

    /// @notice Allows a function to be called when the auction has started
    modifier whenStarted() {
        if (block.timestamp < _auction.start || _auction.start == 0) {
            revert AuctionNotStarted();
        }

        _;
    }

    constructor(address wallet) {
        if (wallet == address(0)) {
            revert WalletAddressZero();
        }

        _wallet = wallet;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        emit WalletSet(wallet);
    }

    /**
     * @notice Creates an auction
     * @param nft Address of the nft contract
     * @param tokenId NFT ID
     * @param startTime Auction start time
     * @param discountRatePerSecond Reduces the cost of nft per second
     * @dev An auction can be created in advance by directly specifying its start time
     */
    function start(IERC721 nft, uint256 tokenId, uint256 startTime, uint256 discountRatePerSecond)
        external
        onlyRole(AUCTIONEER_ROLE)
    {
        if (_auction.start != 0) {
            revert AuctionHasAlreadyStarted();
        }

        if (startTime < block.timestamp) {
            revert AuctionIncorrectStartTime();
        }

        if (discountRatePerSecond <= _startingPrice / _MIN_AUCTION_TIME) {
            /// Reducing the value to 0 nft should not be faster,
            /// than the minimum set time _MIN_AUCTION_TIME
            revert DiscountRatePerSecondNotEnough();
        }

        /// Transfer NFT to the auction smart contract
        nft.transferFrom(msg.sender, address(this), tokenId);

        /// Create an auction record
        _auction = Auction({
            nft: nft,
            tokenId: tokenId,
            start: startTime,
            startingPrice: _startingPrice,
            discountRatePerSecond: discountRatePerSecond,
            auctioneer: msg.sender
        });

        emit AuctionStarted(_auction);
    }

    /**
     * @notice Cancels the auction
     * @dev Only the auctioneer can cancel an auction
     */
    function cancel() external whenStarted onlyRole(AUCTIONEER_ROLE) {
        Auction memory auction = _auction;

        /// Clear auction information
        delete _auction;

        /// Return nft to auctioneer
        auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);

        emit AuctionCanceled(auction);
    }

    /**
     * @notice Ends the auction
     * @dev Any address can end the auction
     */
    function finish() external payable whenStarted {
        uint256 price = _getPrice();

        /// Refund the transaction if the payment for NFT is not enough
        if (msg.value < price) {
            revert ValueNotEnough();
        }

        /// Clearing data about a past auction
        Auction memory auction = _auction;
        delete _auction;

        if (price == 0) {
            /// If the value of NFT is 0
            auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);
        } else {
            /// Send nft to the winner
            auction.nft.transferFrom(address(this), msg.sender, auction.tokenId);

            /// Send payment to protocol wallet
            _transferNative(_wallet, price);

            /// Send remaining surplus back to auction winner
            _transferNative(msg.sender, msg.value - price);
        }

        emit AuctionFinished(auction, msg.sender, msg.value);
    }

    /// @notice Returns information about the cost of NFT at a given time
    function getPrice() external view whenStarted returns (uint256) {
        return _getPrice();
    }

    /// @notice Return the cost of NFT
    function _getPrice() private view returns (uint256) {
        Auction memory auction = _auction;

        /// We calculate the difference between the current time and the start of the auction in seconds
        uint256 elapsedTime = block.timestamp - auction.start;

        /// We calculate the discount amount over time
        uint256 discountValue = elapsedTime * auction.discountRatePerSecond;

        /// Interactive: Here you can complicate things and implement a reserve price, below which NFT cannot cost
        /// Try to implement it yourself. Don't forget to check the condition in the finish() function and add tests

        /// If the discount is greater than the starting price, return 0
        return auction.startingPrice > discountValue ? auction.startingPrice - discountValue : 0;
    }

    /// @notice Returns the initial price of NFT for each new auction
    function getStartingPrice() external view returns (uint256) {
        return _startingPrice;
    }

    /**
     * @notice Allows you to change the initial price of NFT for each new auction
     * @param startingPrice New starting price of nft
     * @dev DEFAULT_ADMIN_ROLE only
     */
    function setStartingPrice(uint256 startingPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _startingPrice = startingPrice;

        emit StartingPriceSet(startingPrice);
    }

    /// @notice Returns information about the auction
    function getAuction() external view returns (Auction memory) {
        return _auction;
    }

    /// @notice Returns the wallet address for withdrawing funds collected from the sale
    function getWallet() external view returns (address) {
        return _wallet;
    }

    /**
     * @notice Allows you to change the wallet for withdrawing funds collected from sales
     * @param wallet New wallet address
     * @dev DEFAULT_ADMIN_ROLE only
     */
    function setWallet(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _wallet = wallet;

        emit WalletSet(wallet);
    }

    function _transferNative(address to, uint256 value) private {
        (bool success,) = to.call{value: value}("");

        if (!success) {
            revert TransferNativeFailed();
        }
    }
}
