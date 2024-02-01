// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/**
 * @title Simple NFT Staking Contract
 * @notice This contract accepts NFTs for storage and
 * allows the owner to retrieve the NFT at any time
 */
contract SimpleStaking is Ownable, ERC721Holder {
    /// @notice NFT that can be staked
    IERC721 private _nft;

    /// @notice Storage of addresses of owners for staked NFTs
    mapping(uint256 tokenId => address stakeholder) private _stakes;

    /// @notice Storage of the number of staked NFTs for each address
    mapping(address stakeholder => uint256 counter) private _stakedNftBalance;

    event Staked(address account, uint256 tokenId);
    event Unstaked(address account, uint256 tokenId);

    error StakeIsNotExist();
    error NotStaker();

    /// @dev Modifier to check the ability to retrieve the NFT
    modifier checkUnstake(uint256 tokenId) {
        address stakeholder = _stakes[tokenId];

        if (stakeholder == address(0)) {
            revert StakeIsNotExist();
        }

        if (msg.sender != stakeholder) {
            revert NotStaker();
        }

        _;
    }

    constructor (IERC721 nft) Ownable(msg.sender) {
        _nft = nft;
    }

    /**
     * @notice Allows transferring an NFT to the contract for staking
     * @param tokenId The identifier of the NFT
     * @dev Before calling, the owner must grant approve()
     */
    function stake(uint256 tokenId) external {
        /// Transfer of the NFT from the owner to the contract
        _nft.safeTransferFrom(msg.sender, address(this), tokenId);

        /// Запись данных о владельце
        _stakes[tokenId] = msg.sender;
        _stakedNftBalance[msg.sender] += 1;

        emit Staked(msg.sender, tokenId);
    }

    /**
        * @notice Allows the owner to claim the NFT
        * @param tokenId NFT identifier
        * @dev Owner verification within the checkUnstake() modifier

     */
    function unstake(uint256 tokenId) external checkUnstake(tokenId) {
        /// Transferring NFT from the contract to the owner
        _nft.safeTransferFrom(address(this), msg.sender, tokenId);

        /// Removing owner data
        delete _stakes[tokenId];
        _stakedNftBalance[msg.sender] -= 1;

        emit Unstaked(msg.sender, tokenId);
    }

    /**
        * @notice Allows checking if the NFT is staked
        * @param tokenId NFT identifier
        * @return Address of the NFT owner

     */
    function getStakerByTokenId(uint256 tokenId) external view returns (address) {
        return _stakes[tokenId];
    }

    /**
     * @notice Allows obtaining the number of NFTs staked by the owner
     * @param stakeholder NFT owner's adress
     */
    function getStakedNftBalance(address stakeholder) external view returns (uint256) {
        return _stakedNftBalance[stakeholder];
    }

    /// @notice Returns NFT collection's adress 
    function getNftAddress() external view returns (address) {
        return address(_nft);
    }
}
