// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IGenesis.sol";
import "./interfaces/IGAME_ERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/ILocalContract.sol";


contract Character is ERC721Enumerable, AccessControl, ILocalContract {
    bytes32 public constant APPROVED_CONTRACT = keccak256("APPROVED_CONTRACT");

    // Doing a bitwise and between this and a stat line should keep everything but the stats
    uint256 STAT_MASK = 0xfffffffFfffffffFfffffffFfffffffFfffffffFfffffffFff00000000000000;     

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

    /// @notice Price in Genesis
    uint256 public priceInGenesis = 1000 * 10**18;

    /// @notice Price in Game
    uint256 public priceInGame = 1000 * 10**18;

    /// @notice Price in MATIC
    uint256 public priceInMatic = 1000 * 10**18;

    /// @notice cost to level up
    uint256 public cost;

    /// @notice Genesis multiplier
    uint256 public genesisPriceMultiplier;

    /// @notice Game multiplier
    uint256 public gamePriceMultiplier;

    /// @notice Matic multiplier
    uint256 public maticPriceMultiplier;

    // @notice Level of tokens
    mapping(uint256 => uint256) public tokenLevel;

    // @notice Level of tokens
    mapping(uint256 => uint256) public tokenStats;

    /// @notice Emitted level is up
    event LevelUp(uint256 tokenId, uint256 newLevel);

    /// @notice Emitted level is up
    event TokenStats(uint256 tokenId, uint256 input);

    modifier onlyTrustedContract {
        require(hasRole(APPROVED_CONTRACT, _msgSender()), "Not trusted contract");
        _;
    }

    constructor(address gameContract_, address genesisContract_, address feeReceiver_) ERC721("Genesis Characters", "CHAR") {
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

    /**
     * @dev Set price in Genesis
     */
    function setPriceInGenesis(uint256 priceInGenesis_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        priceInGenesis = priceInGenesis_;
    }

    /**
     * @dev Set price in Game
     */
    function setPriceInGame(uint256 priceInGame_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        priceInGame = priceInGame_;
    }

    /**
     * @dev Set price in MATIC
     */
    function setPriceInMatic(uint256 priceInMatic_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        priceInMatic = priceInMatic_;
    }

    /**
     * @dev Set cost to level up
     */
    function setCost(uint256 cost_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cost = cost_;
    }

    /**
     * @dev Set Game price multiplier
     */
    function setGamePriceMultiplier(uint256 gamePriceMultiplier_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        gamePriceMultiplier = gamePriceMultiplier_;
    }

    /**
     * @dev Set Genesis price multiplier
     */
    function setGenesisPriceMutliplier(uint256 genesisPriceMultiplier_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        genesisPriceMultiplier = genesisPriceMultiplier_;
    }

    /**
     * @dev Set MATIC price mutliplier
     */
    function setMaticPriceMutliplier(uint256 maticPriceMultiplier_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maticPriceMultiplier = maticPriceMultiplier_;
    }

    // function getPrice(uint256 tokenId) public pure returns (uint256) {
    //     if (tokenId <= 10000) {
    //         return 1000;
    //     } else if (tokenId <= 40000) {
    //         return 250;
    //     } else if (tokenId <= 100000) {
    //         return 100;
    //     } else {
    //         return 25;
    //     }
    // }

    function _createNft(uint256 tokenId) private {
        _mint(_msgSender(), tokenId);
        uint256 newLevel = _getStartingLevel(tokenId);
        tokenLevel[tokenId] = newLevel;
        emit LevelUp(tokenId, newLevel);
    }

    function buyNftWithGAME() external {
        uint256 tokenId = totalSupply() + 1;
        gameContract.transferByContract(_msgSender(), feeReceiver, priceInGame);
        _createNft(tokenId);
    }

    function buyNftWithGENESIS() external {
        uint256 tokenId = totalSupply() + 1;
        genesisContract.transferFrom(_msgSender(), feeReceiver, priceInGenesis);
        _createNft(tokenId);
    }

    function buyNftwithMatic() external payable {
        uint256 tokenId = totalSupply() + 1;
        require(msg.value >= priceInMatic, "not enough paid");
        payable(feeReceiver).transfer(priceInMatic);
        _createNft(tokenId);
    }

    // The test for this function is to take a stat line (or several)
    // Note that this does not SAVE the stats; it just updates them.
    function increaseStats(uint256 input, uint256[7] memory statIncreases) public view returns(uint256 output) {
        output = input & STAT_MASK;
        for(uint256 i = 0; i < 7; i++) {
            uint256 shift = 16 * i;
            uint256 newStat = uint256(uint16(input >> shift)) + statIncreases[i];
            if(newStat >= 32768) {
                newStat = 32767;
            }
            output = output & (newStat << shift);
        }
    }

    function decreaseStats(uint256 input, uint256[7] memory statDecreases) public view returns(uint256 output) {
        output = input & STAT_MASK;
        for(uint256 i = 0; i < 7; i++) {
            uint256 shift = 16 * i;
            // Don’t use safemath here; if we underflow, we need to reset to 0.
            uint256 newStat = uint256(uint16(input << 16 * i)) - statDecreases[i];
            if(newStat >= 32768) {
                newStat = 0;
            }
            output = output & (newStat << shift);
        }
    }

    function getTraits(uint256 input) public pure returns(uint256[7] memory traits) {
        traits[0] = uint256(uint8(input >> 128)); // Trait A
        traits[1] = uint256(uint8(input >> 136)); // Trait B
        traits[2] = uint256(uint8(input >> 144)); // Trait C
        traits[3] = uint256(uint8(input >> 152)); // Specialization A
        traits[4] = uint256(uint8(input >> 160)); // Specialization B
        traits[5] = uint256(uint8(input >> 168)); // Specialization C
        traits[6] = uint256(uint8(input >> 176)); // Class
    }

    function getStats(uint256 input) public pure returns(uint256[7] memory stats) {
        stats[0] = uint256(uint16(input)); // Strength
        stats[1] = uint256(uint16(input >> 16)); // Speed
        stats[2] = uint256(uint16(input >> 32)); // Defense
        stats[3] = uint256(uint16(input >> 48)); // Body
        stats[4] = uint256(uint16(input >> 64)); // Mind
        stats[5] = uint256(uint16(input >> 80)); // Tech
        stats[6] = uint256(uint16(input >> 96)); // Magic
    }

    function getLevel(uint256 input) public pure returns(uint256 level) {
        level = uint256(uint16(input >> 112));
    }

    function levelUpWithPermission(uint256 tokenId, uint256 levels, uint256[7] calldata stats) external onlyTrustedContract returns(uint256 cost) {
        cost = completeLevelUp(tokenId, levels, stats);
    }

    function setStatsWithPermission(uint256 tokenId, uint256 newStats) external onlyTrustedContract returns(uint256 cost) {
        tokenStats[tokenId] = newStats;
        emit TokenStats(tokenId, newStats);
    }

    function levelUpWithGAME(uint256 expectedSpend, uint256 tokenId, uint256 levels, uint256[7] calldata stats) external {
        address sender = _msgSender();
        uint256 baseCost = completeLevelUp(tokenId, levels, stats);
        uint256 cost = cost * gamePriceMultiplier;
        require(expectedSpend == cost, "GAME paid is incorrect");
        gameContract.transferByContract(sender, feeReceiver, baseCost);
    }

    function levelUpWithGENESIS(uint256 expectedSpend, uint256 tokenId, uint256 levels, uint256[7] calldata stats) external {
        address sender = _msgSender();
        uint256 baseCost = completeLevelUp(tokenId, levels, stats);
        uint256 cost = cost * genesisPriceMultiplier;
        require(expectedSpend == cost, "GENESIS paid is incorrect");
        genesisContract.transferFrom(sender, feeReceiver, baseCost);
    }

    function levelUpWithMATIC(uint256 tokenId, uint256 levels, uint256[7] calldata stats) external payable {
        uint256 baseCost = completeLevelUp(tokenId, levels, stats);
        uint256 cost = cost * maticPriceMultiplier;
        require(msg.value == cost, "MATIC paid is incorrect");
        payable(feeReceiver).transfer(cost);
    }

    function completeLevelUp(uint256 tokenId, uint256 levels, uint256[7] calldata stats) internal returns(uint256 baseCost) {
        uint input = tokenStats[tokenId];
        require(input > 0, "token stats do not exist");
        uint256 currentLevel = getLevel(input);
        require(currentLevel + levels <= 32767, "level cap");
        uint256 cost = 0;
        for(uint256 i = 1; i <= levels; i++) {
            cost = cost + (currentLevel + i) ** 2;
        }
        cost = cost * 10;
        uint256 statSum = stats[0] + stats[1] + stats[2] + stats[3] + stats[4] + stats[5] + stats[6];
        require(statSum == levels * 7, "incorrect number of stat points");
        uint256 output = increaseStats(input, stats);
        output = input + levels >> 112;
        tokenStats[tokenId] = output;
        emit TokenStats(tokenId, output);
    }

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
        if (tokenId <= 10000) { // Level 15-20
            bonus = 14;
        } else if (tokenId <= 40000) { // Level 10-15
            bonus = 9;
        } else if (tokenId <= 100000) { // Level 5-10
            bonus = 4;
        } // Otherwise Level 1-6

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
}