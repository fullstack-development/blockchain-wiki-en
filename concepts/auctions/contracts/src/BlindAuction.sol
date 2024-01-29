// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Blind Auction
 * @notice The smart contract implements the sale of an ERC-721 (nft) token using a blind auction.
 * A blind auction involves collecting bids behind closed doors. Auction participants do not know each other's bids.
 * The auction has stages: collection of hidden bids, disclosure of bids, determination of the winner.
 *Collected funds are moved to the specified wallet address.
 * To hide participants' bids, the commit-reveal scheme is used
 * @dev Smart contract roles:
 * - DEFAULT_ADMIN_ROLE. Can change the wallet address for withdrawing funds collected from the sale.
 * Can control the duration setting of auction stages.
 * - AUCTIONEER_ROLE. Can create and start an auction by calling the start() function or cancel it with cancel()
 */
contract BlindAuction is AccessControl {
    bytes32 public constant AUCTIONEER_ROLE = keccak256("AUCTIONEER_ROLE");

    uint256 private constant _DEFAULT_COMMIT_DURATION = 1 days;
    uint256 private constant _DEFAULT_REVEAL_DURATION = 0.5 days;

    struct Auction {
        IERC721 nft;
        uint256 tokenId;
        uint256 start;
        uint256 commitDuration;
        uint256 revealDuration;
        address auctioneer;
    }

    struct RevealedBid {
        address account;
        uint256 value;
    }

    Auction private _auction;
    uint256 private _commitDuration = _DEFAULT_COMMIT_DURATION;
    uint256 private _revealDuration = _DEFAULT_REVEAL_DURATION;
    address private _wallet;

    mapping(address account => bytes32 blindedBid) private _blindedBids;
    address[] private _auctionParticipants;

    RevealedBid[] private _revealedBids;

    event AuctionStarted(Auction auction);
    event Committed(address indexed account, bytes32 blindedBid);
    event Revealed(address indexed account, uint256 value, bytes32 blindedBid);
    event AuctionCanceled(Auction auction);
    event AuctionFinished(RevealedBid revealedBid);
    event WalletSet(address wallet);
    event CommitDurationSet(uint256 commitDuration);
    event RevealDurationSet(uint256 revealDuration);

    error AuctionNotStarted();
    error AuctionNotCommitStage();
    error AuctionNotRevealStage();
    error AuctionNotFinishStage();
    error AuctionHasAlreadyStarted();
    error BidHasAlreadyCommitted();
    error BidNotCommitted();
    error IncorrectRevealAmount();
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

    /// @notice Allows the function to be called when the auction is in the stage of collecting hidden bids
    modifier whenCommit() {
        uint256 commitEnd = _auction.start + _auction.commitDuration;

        if (block.timestamp < _auction.start || block.timestamp > commitEnd) {
            revert AuctionNotCommitStage();
        }

        _;
    }

    /// @notice Allows the function to be called when the auction is in the bidding stage
    modifier whenRevealed() {
        uint256 startReveal = _auction.start + _auction.commitDuration;
        uint256 endReveal = _auction.start + _auction.commitDuration + _auction.revealDuration;

        if (block.timestamp < startReveal || block.timestamp > endReveal) {
            revert AuctionNotRevealStage();
        }

        _;
    }

    /// @notice Allows a function to be called when the auction has ended
    modifier whenFinished() {
        uint256 endReveal = _auction.start + _auction.commitDuration + _auction.revealDuration;

        if (block.timestamp < endReveal) {
            revert AuctionNotFinishStage();
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

        /// We transfer NFT to the auction smart contract
        nft.transferFrom(msg.sender, address(this), tokenId);

        /// Create an auction record
        _auction = Auction({
            nft: nft,
            tokenId: tokenId,
            start: startTime,
            commitDuration: _commitDuration,
            revealDuration: _revealDuration,
            auctioneer: msg.sender
        });

        emit AuctionStarted(_auction);
    }

    /**
     * @notice Allows you to send a hidden bid
     * @param blindedBid Bid hash. Obtained by calling the generateBlindedBid() function
     * @dev Only available at commit stage
     */
    function commit(bytes32 blindedBid) external whenCommit {
        if (_blindedBids[msg.sender] != bytes32(0)) {
            revert BidHasAlreadyCommitted();
        }

        /// Write down the hidden rate
        _blindedBids[msg.sender] = blindedBid;
        _auctionParticipants.push(msg.sender);

        emit Committed(msg.sender, blindedBid);
    }

    /**
     * @notice Allows you to reveal the bidder's bid
     * @dev Available only at the reveal stage
     */
    function reveal() external payable whenRevealed {
        bytes32 blindedBid = _blindedBids[msg.sender];

        /// We check that the hidden bet was made
        if (blindedBid == bytes32(0)) {
            revert BidNotCommitted();
        }

        bytes32 expectedBlindedBid = generateBlindedBid(msg.sender, msg.value);

        /// We check the correctness of the hidden rate and the sent amount of native currency
        if (blindedBid != expectedBlindedBid) {
            revert IncorrectRevealAmount();
        }

        RevealedBid memory revealedBid = RevealedBid({account: msg.sender, value: msg.value});

        /// We record information about the disclosed bet
        _revealedBids.push(revealedBid);

        emit Revealed(msg.sender, msg.value, blindedBid);
    }

    /**
     * @notice Cancels the auction
     * @dev Only the auctioneer can cancel an auction
     */
    function cancel() external whenStarted onlyRole(AUCTIONEER_ROLE) {
        Auction memory auction = _auction;
        RevealedBid[] memory revealedBids = _revealedBids;

        /// Clear auction information
        _clearAuction();

        /// We go through all open bets
        for (uint256 i = 0; i < revealedBids.length; i++) {
            RevealedBid memory revealedBid = revealedBids[i];

            /// We make a refund at the disclosed rate
            _transferNative(revealedBid.account, revealedBid.value);
        }

        /// Return nft to auctioneer
        auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);

        emit AuctionCanceled(auction);
    }

    /**
     * @notice Ends the auction
     * @dev To participate in the final determination of the winner, the user must disclose the bid.
     * If two or more participants have equal bet amounts, the winner is the one
     * who made the bet disclosure earlier
     */
    function finish() external whenFinished {
        RevealedBid memory winnerRevealedBid;
        Auction memory auction = _auction;

        /// We go through all open bets
        for (uint256 i = 0; i < _revealedBids.length; i++) {
            RevealedBid memory revealedBid = _revealedBids[i];

            /// If the new revealed bid is greater than all previous bids
            if (revealedBid.value > winnerRevealedBid.value) {
                /// We return the bet to the previous winner
                _transferNative(winnerRevealedBid.account, winnerRevealedBid.value);

                /// Save the new bet
                winnerRevealedBid = revealedBid;
            } else {
                /// We return the revealed bet, which is less than the bet of the found winner
                _transferNative(revealedBid.account, revealedBid.value);
            }
        }

        /// Clear auction information
        _clearAuction();

        if (winnerRevealedBid.account == address(0)) {
            /// If there was no bid, return the nft to the auctioneer
            auction.nft.transferFrom(address(this), auction.auctioneer, auction.tokenId);
        } else {
            /// Send payment to protocol wallet
            _transferNative(_wallet, winnerRevealedBid.value);

            /// Send nft to the winner
            auction.nft.transferFrom(address(this), winnerRevealedBid.account, auction.tokenId);
        }

        emit AuctionFinished(winnerRevealedBid);
    }

    /**
     * @notice Generates a hidden bid for the bidder
     * @param account Auction participant address
     * @param value Bet size
     */
    function generateBlindedBid(address account, uint256 value) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, value));
    }

    /**
     * @notice Returns the hidden bids for the bidder's address
     * @param account Auction participant address
     */
    function getBlindedBidByAccount(address account) external view returns (bytes32) {
        return _blindedBids[account];
    }

    /// @notice Returns a list of revealed bets
    function getRevealedBids() external view returns (RevealedBid[] memory) {
        return _revealedBids;
    }

    /// @notice Returns information about the auction
    function getAuction() external view returns (Auction memory) {
        return _auction;
    }

    /// @notice Returns the duration of the commit stage
    function getCommitDuration() external view returns (uint256) {
        return _commitDuration;
    }

    /**
     * @notice Allows you to set the duration of the commit stage
     * @param commitDuration Duration of the commit stage
     * @dev DEFAULT_ADMIN_ROLE only
     */
    function setCommitDuration(uint256 commitDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _commitDuration = commitDuration;

        emit CommitDurationSet(commitDuration);
    }

    /// @notice Returns the duration of the reveal stage
    function getRevealDuration() external view returns (uint256) {
        return _revealDuration;
    }

    /**
     * @notice Allows you to set the duration of the reveal stage
     * @param revealDuration Duration of the reveal stage
     * @dev DEFAULT_ADMIN_ROLE only
     */
    function setRevealDuration(uint256 revealDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revealDuration = revealDuration;

        emit RevealDurationSet(revealDuration);
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
        delete _auction;

        /// Clearing data on hidden bids of all participants
        for (uint256 i = 0; i < _auctionParticipants.length; i++) {
            address participant = _auctionParticipants[i];

            delete _blindedBids[participant];
        }

        /// Clearing data on the addresses of auction participants
        delete _auctionParticipants;

        /// Clearing data on disclosed bids of auction participants
        delete _revealedBids;
    }

    function _transferNative(address to, uint256 value) private {
        (bool success,) = to.call{value: value}("");

        if (!success) {
            revert TransferNativeFailed();
        }
    }
}
