// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
  * @title English auction
  * @notice The smart contract implements the sale of an ERC-721 (nft) token using an English-type auction.
  * An English auction implies an increase in the value of an item with each new bid. The auction is limited in time.
  * Collected funds are moved to the specified wallet address.
  * @dev Smart contract roles:
  * - DEFAULT_ADMIN_ROLE. Can change the wallet address for withdrawing funds collected from the sale.
  * Can control auction duration setting.
  * - AUCTIONEER_ROLE. Can create and start an auction by calling the start() function or cancel it with cancel()
  */
contract EnglishAuction is AccessControl {
    bytes32 public constant AUCTIONEER_ROLE = keccak256("AUCTIONEER_ROLE");
    uint256 private constant _DEFAULT_AUCTION_DURATION = 10 days;

    struct Auction {
        IERC721 nft;
        uint256 tokenId;
        uint256 start;
        uint256 duration;
        address auctioneer;
    }

    struct HighestBid {
        address account;
        uint256 value;
    }

    Auction private _auction;
    HighestBid private _highestBid;
    uint256 _auctionDuration = _DEFAULT_AUCTION_DURATION;
    address private _wallet;

    event AuctionStarted(Auction auction);
    event AuctionCanceled(Auction auction);
    event AuctionFinished(Auction auction, HighestBid highestBid);
    event Bid(address indexed account, uint256 value);
    event AuctionDurationSet(uint256 auctionDuration);
    event WalletSet(address wallet);

    error AuctionNotStarted();
    error AuctionNotFinished();
    error AuctionHasAlreadyStarted();
    error AuctionHasAlreadyFinished();
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

    /// @notice Allows a function to be called when the auction has ended
    modifier whenFinished() {
        uint256 auctionFinish = _auction.start + _auction.duration;

        if (block.timestamp < auctionFinish) {
            revert AuctionNotFinished();
        }

        _;
    }

    /// @notice Allows a function to be called when the auction has not ended
    modifier whenNotFinished() {
        uint256 auctionFinish = _auction.start + _auction.duration;

        if (block.timestamp >= auctionFinish) {
            revert AuctionHasAlreadyFinished();
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
     * @dev An auction can be created in advance by directly specifying its start time
     */
    function start(IERC721 nft, uint256 tokenId, uint256 startTime) external onlyRole(AUCTIONEER_ROLE) {
        if (_auction.start != 0) {
            revert AuctionHasAlreadyStarted();
        }

        if (startTime < block.timestamp) {
            revert AuctionIncorrectStartTime();
        }

        /// Transfer NFT to the auction smart contract
        nft.transferFrom(msg.sender, address(this), tokenId);

        /// Create an auction record
        _auction = Auction({
            nft: nft,
            tokenId: tokenId,
            start: startTime,
            duration: _auctionDuration,
            auctioneer: msg.sender
        });

        emit AuctionStarted(_auction);
    }

    /**
     * @notice Allows you to place a bet
     * @dev The native currency of the blockchain is accepted as a bet
     */
    function bid() external payable whenStarted whenNotFinished {
        HighestBid memory highestBid = _highestBid;

        /// Each new bet must be greater than the previous one
        if (msg.value <= highestBid.value) {
            revert ValueNotEnough();
        }

        /// Recording a new bet
        _highestBid = HighestBid(msg.sender, msg.value);

        /// Return to the previous participant his bet
        if (highestBid.value > 0) {
            _transferNative(highestBid.account, highestBid.value);
        }

        emit Bid(msg.sender, msg.value);
    }

    /**
     * @notice Cancels the auction
     * @dev Only the auctioneer can cancel an auction
     */
    function cancel() external whenStarted onlyRole(AUCTIONEER_ROLE) {
        Auction memory auction = _auction;
        HighestBid memory highestBid = _highestBid;

        /// Clear auction information
        _clearAuction();

        if (highestBid.account != address(0)) {
            /// Return of the bet to the participant if it was made
            _transferNative(highestBid.account, highestBid.value);
        }

        /// Return nft to auctioneer
        auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);

        emit AuctionCanceled(auction);
    }

    /**
     * @notice Ends the auction
     * @dev Any address can finish the auction after the auction ends
     */
    function finish() external whenFinished {
        HighestBid memory highestBid = _highestBid;
        Auction memory auction = _auction;

        /// Clear auction information
        _clearAuction();

        if (highestBid.account == address(0)) {
            /// If there was no bid, return the nft to the auctioneer
            auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);
        } else {
            /// Send payment to protocol wallet
            _transferNative(_wallet, highestBid.value);

            /// Send nft to the winner
            auction.nft.transferFrom(address(this), highestBid.account, auction.tokenId);
        }

        emit AuctionFinished(auction, highestBid);
    }

    /// @notice Returns information about the current highest bid
    function getHighestBid() external view returns (HighestBid memory) {
        return _highestBid;
    }

    /// @notice Returns the default auction duration
    function getAuctionDuration() external view returns (uint256) {
        return _auctionDuration;
    }

    /**
     * @notice Allows you to change the duration of the auction
     * @param auctionDuration New auction duration
     * @dev DEFAULT_ADMIN_ROLE only
     */
    function setAuctionDuration(uint256 auctionDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _auctionDuration = auctionDuration;

        emit AuctionDurationSet(auctionDuration);
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

    function _clearAuction() private {
        /// Clearing data about a past auction
        delete _highestBid;
        delete _auction;
    }

    function _transferNative(address to, uint256 value) private {
        (bool success,) = to.call{value: value}("");

        if (!success) {
            revert TransferNativeFailed();
        }
    }
}
