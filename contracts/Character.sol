// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IGenesis.sol";

contract Character is ERC721, AccessControl {
    
    // The genesis contract address
    IGenesis genesisContract;

    /// @notice Receiver address to receive fees
    address public feeReceiver;

    /// @notice Total supply
    uint256 public totalSupply;

    // @notice Level of tokens
    mapping(uint256 => uint256) tokenLevel;

    /// @notice Airdrop amount
    mapping(uint256 => mapping(uint256 => address)) public claimedAirdrops;

    /// @notice Emitted when airdrop is claimed
    event AirdropClaimed(address indexed airdropContract, uint256 airdropId, uint256 tokenId, address indexed recipient);

    /// @notice Emitted level is up
    event LevelUp(uint256 tokenId, uint256 newLevel);

    constructor(string memory name_, string memory symbol_, address genesisContract_, address feeReceiver_) ERC721(name_, symbol_) {
        genesisContract = IGenesis(genesisContract_);
        feeReceiver = feeReceiver_;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view  override(ERC721, AccessControl) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Sets fee receiver
     */
    function setFeeReceiver(address feeReceiver_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeReceiver = feeReceiver_;
    }

    /**
     * @dev Sets the baseURI for {tokenURI}
     */
    function distributeTokens(address[] memory recipients) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 tokenId = totalSupply;
        for(uint256 i = 0; i < recipients.length; i++) {
            tokenId++;
            _mint(recipients[i], tokenId);
        }
        totalSupply = tokenId;
    }

    function buyNft() external {
        genesisContract.transferFrom(_msgSender(), feeReceiver, 100 * 10 ** 18);
        uint256 tokenId = totalSupply + 1;
        _mint(_msgSender(), tokenId);
        totalSupply = tokenId;
    }

    function levelUp(uint256 tokenId) external {
        uint256 newLevel = getLevel(tokenId) + 1;
        genesisContract.transferFrom(_msgSender(), feeReceiver, 10 * newLevel);
        tokenLevel[tokenId] = newLevel;
        emit LevelUp(tokenId, newLevel);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseURI(), "/", tokenId, "/", getLevel(tokenId)));
    }

    function getLevel(uint256 tokenId) public view returns (uint256 level) {
        level = tokenLevel[tokenId];
        if (level > 0) {
            return level;
        }
        uint256 bonus = 0;
        if (tokenId <= 8192) {
            bonus = 14;
        } else if (tokenId <= 16384) {
            bonus = 12;
        } else if (tokenId <= 32768) {
            bonus = 10;
        } else if (tokenId <= 65536) {
            bonus = 8;
        } else if (tokenId <= 131072) {
            bonus = 6;
        } else if (tokenId <= 262144) {
            bonus = 4;
        } else if (tokenId <= 524288) {
            bonus = 2;
        }

        uint256 range = uint256(keccak256(abi.encode(tokenId))) % 64;
        if (range < 2) {
            level = bonus + 6;
        } else if (range < 4) {
            level = bonus + 5;
        } else if (range < 8) {
            level = bonus + 4;
        } else if (range < 16) {
            level = bonus + 3;
        } else if (range < 32) {
            level = bonus + 2;
        } else {
            level = bonus + 1;
        }
    }

    function getAttributes(uint256 tokenId) external pure returns (uint256 class, uint256 trait1, uint256 trait2, uint256 trait3) {
        // uint256 range = keccak32(tokenId);
    }

    function getStats(uint256 tokenId) external view returns (uint256[6] memory stats) {
        // (uint256 level, uint256 class, uint256 trait1, uint256 trait2, uint256 trait3) = getAttributes(tokenId);
        // uint256 level = getLevel(tokenId);
    }

    // Checks whether:
    //   (a) the token is owned by the user (if tokenOwner isn’t provided, it skips this check)
    //   (b) the airdropId is a uint48 (so it can be combined with an address)
    //   (c) the token has claimed that airdrop
    function checkAirdrop(address airdropContract, uint256 airdropId, uint256 tokenId, address recipient) external view returns(bool) {
        uint64 shortAirdropId = uint64(airdropId);
        if(ownerOf(tokenId) != address(0) && ownerOf(tokenId) != recipient) {
            return false;
        }
        if(uint256(shortAirdropId) != airdropId) {
            return false;
        }
        uint256 airdropCode = airdropId << 192 + uint256(uint160(_msgSender()));
        return claimedAirdrops[tokenId][airdropCode] == address(0);
    }

    // This is designed to receive airdrop requests from a specific contract
    // It reverts in all cases where the airdrop is invalid
    // It can only be called from the contract code
    // Recipient must be the owner of the token
    // The token (not the user) must not have received that airdrop
    function claimAirdrop(uint256 airdropId, uint256 tokenId, address recipient) external {
        require(recipient != address(0) && ownerOf(tokenId) == recipient, "token owner not valid");
        uint64 shortAirdropId = uint64(airdropId);
        require(uint256(shortAirdropId) == airdropId, "airdropId overflow");
        uint256 airdropCode = airdropId << 192 + uint256(uint160(_msgSender()));
        require(claimedAirdrops[tokenId][airdropCode] == address(0), "airdrop already claimed by this character");
        claimedAirdrops[tokenId][airdropCode] = ownerOf(tokenId);
        emit AirdropClaimed(msg.sender, airdropId, tokenId, ownerOf(tokenId));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}