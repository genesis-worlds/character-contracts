// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IGenesis.sol";
import "./interfaces/IGAME_ERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract Character is ERC721Enumerable, AccessControl {
    
    // The genesis contract address
    IGenesis genesisContract;

    // The GAME contract address
    IGAME_ERC20 gameContract;

    // The uniswap router
    IUniswapV2Router02 public uniswapRouter;

    /// @notice Receiver address to receive fees
    address public feeReceiver;

    /// @notice Base URI
    string public baseURI;

    // @notice Level of tokens
    mapping(uint256 => uint256) tokenLevel;

    /// @notice Emitted level is up
    event LevelUp(uint256 tokenId, uint256 newLevel);

    constructor(string memory name_, string memory symbol_, address gameContract_, address genesisContract_, address feeReceiver_) ERC721(name_, symbol_) {
        genesisContract = IGenesis(genesisContract_);
        gameContract = IGAME_ERC20(gameContract_);
        feeReceiver = feeReceiver_;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view  override(ERC721Enumerable, AccessControl) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Sets uniswap router
     */
    function setUniswapRouter(address uniswapRouter_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapRouter = IUniswapV2Router02(uniswapRouter_);
    }

    /**
     * @dev Sets fee receiver
     */
    function setFeeReceiver(address feeReceiver_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeReceiver = feeReceiver_;
    }

    /**
     * @dev Sets base uri
     */
    function setBaseURI(string memory baseURI_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = baseURI_;
    }

    function _createNft() private {
        uint256 tokenId = totalSupply() + 1;
        _mint(_msgSender(), tokenId);
        uint256 newLevel = _getStartingLevel(tokenId);
        tokenLevel[tokenId] = newLevel;
        emit LevelUp(tokenId, newLevel);
    }

    function buyNftWithGAME() external {
        gameContract.transferByContract(_msgSender(), feeReceiver, 100 * 10 ** 18);
        _createNft();
    }

    function buyNftWithGENESIS() external {
        genesisContract.transferFrom(_msgSender(), feeReceiver, 100 * 10 ** 18);
        _createNft();
    }

    // function buyNftWithMATIC() external {
    //     gameContract.transferByContract(_msgSender(), feeReceiver, 100 * 10 ** 18);
    //     _createNft();
    // }

    function levelUp(uint256 tokenId) external {
        uint256 newLevel = tokenLevel[tokenId] + 1;
        genesisContract.transferFrom(_msgSender(), feeReceiver, 10 * newLevel * 10 ** 18);
        tokenLevel[tokenId] = newLevel;
        emit LevelUp(tokenId, newLevel);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, "/", tokenId, "/", tokenLevel[tokenId]));
    }

    function _getStartingLevel(uint256 tokenId) internal pure returns (uint256 level) {
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

    // These attributes only cover the top-level attributes (which are each 0-6). To get the next level (specializations), you have to take the next 256 chars of the 
    // Level comes from the first byte (above)
    // Traits come frome the second byte; there’s 7*6*5=210 combinations, which fits
    function getAttributes(uint256 tokenId) external pure returns (uint256 class, uint256 subclass, uint256 trait1, uint256 trait2, uint256 trait3) {
        return getAttributesFromHash(uint256(keccak256(abi.encode(tokenId))));
    }

    function getAttributesFromHash(uint256 hash) public pure returns (uint256 class, uint256 subclass, uint256 trait1, uint256 trait2, uint256 trait3) {
        uint256 tokenIdHash = hash << 8;
        // This should generate 3 unique stats, roughly evenly distributed,
        // with no more than one from each of 7 groups.
        // The first byte gave level
        // The second byte gives the three traits.
        // The third byte would give the ability within each trait (not calced here)
        trait1 = tokenIdHash % 7; // 0-2 are slightly over-represented
        trait2 = tokenIdHash % 6; // 0-2 are slightly over-represented; 3 less so
        trait2 = trait2 == trait1 ? 7 : trait2;
        trait3 = tokenIdHash % 5; // 0 is slightly over-represented; 1 less so
        trait3 = trait3 == trait1 ? 7 : trait3 == trait2 ? 6 : trait3;

        // This generates a number from 0-20, representing the class of the token.
        // Classes come in three levels of rarity. They’re independent from traits.
        // Classes 0, 7, and 14 are the common, rare, and legendary classes for a single trait
        // The fourth byte is the class, the fifth byte is the subclass
        uint256 classRandom = tokenIdHash << 24;
        class = classRandom % 7; // 0-2 are slightly over-represented

        uint256 subClassRandom = tokenIdHash << 32;
        subclass = subClassRandom % 6;
        subclass = subclass == class ? 7 : subclass;

        classRandom = classRandom % 16;
        class = class + classRandom == 15 ? 14 : classRandom > 10 ? 7 : classRandom;

        subClassRandom = subClassRandom % 16;
        subclass = subclass + subClassRandom == 15 ? 14 : subClassRandom > 10 ? 7 : subClassRandom;
    }

    // Bytes 6 through 15 of the token hash generate the 7 stats (one mapped to each trait), two for trait bonuses;
    // The highest a stat can go is 232 (100 for level, 69 from the random roll, 19 from class, 13 from subclass, and 31 from primary stat)
    // This generates stats from 7 to 70 at 1st level + a max of 31 for the top stat, and  22 for next, 10 for third
    // Stats of 26 to 89 at 20th
    // Stats of 106 to 169 at 100th, + 46 = 215 absolute maximum
    function getStats(uint256 tokenId) external view returns (uint256[7] memory stats) {
        uint256 tokenIdHash = uint256(keccak256(abi.encode(tokenId)));
        (uint256 class, uint256 subclass, uint256 trait1, uint256 trait2, uint256 trait3) = getAttributesFromHash(tokenIdHash); 
        uint256 hash = tokenIdHash << 40;
        uint256 level = tokenLevel[tokenId];
        if(level > 100) {
            level = 100;
        }

        // Sets the stat based on the level and a random roll
        for(uint256 i = 0; i < 7; i++) {
            uint256 stat = hash << (i * 8) % 256;
            if(stat < 64) {
            stats[i] = 6 + stat + level;
            } else if (stat < 128) {
            stats[i] = 6 + stat % 32 + level;
            } else {
            stats[i] = 6 + stat % 16 + level;
            }
        }
        
        // This adds the bonuses to the stat, based on the character’s traits
        hash = tokenIdHash << 96 % 256;
        stats[class % 7 + 1] += hash % 19;
        stats[subclass % 7 + 1] += hash % 13;
        hash = tokenIdHash << 104 % 256;
        stats[trait1 - 1] += hash % 31;
        stats[trait2 - 1] += hash % 23;
        stats[trait3 - 1] += hash % 11;
    }
}