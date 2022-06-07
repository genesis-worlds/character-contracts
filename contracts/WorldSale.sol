pragma solidity ^0.8.0;
// SPDX-License-Identifier: UNLICENSED

/*
  Needs:
  foundation share
  Assign parcels before sale starts (list of parcels)
  parcel level data
  Land from mainnet sales
  Mainnet land sale contract (just a straight 721?)
*/

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@maticnetwork/fx-portal/contracts/tunnel/FxBaseChildTunnel.sol";
import "./Encode.sol";

import "./interfaces/IGenesis.sol";
import "./interfaces/IMiningClaim.sol";


contract WorldSale is Initializable, ERC721EnumerableUpgradeable, AccessControlUpgradeable, FxBaseChildTunnel {
  uint256 public constant N_TRAITS = 5;

  // Settings
  // =========

  /// @notice Bonus land price
  uint256 public bonusLandPrice;

  /// @notice Land level up price
  uint256 public landLevelUpPrice;

  /// @notice Land grow price
  uint256 public landGrowPrice;

  /// @notice Building price
  uint256 public buildingPrice;

  /// @notice move land price
  uint256 public moveLandPrice;

  /// @notice Available Building Ids
  uint256[] public availableBuildingIds;

  /// @notice purchaseActive
  bool public purchaseActive;

  // Data
  // =========

  /// @notice Genesis Receiver
  address public genesisReceiver;

  /// @notice Referrers
  mapping(address => address) public referrers;

  /// @notice Mining Claim
  IMiningClaim private miningClaim;

  /// @notice Next parcel id
  mapping(uint256 => uint256) private nextParcelId;

  /// @notice Land Datas
  mapping(uint256 => uint256) public landDatas;

  /// @notice A, B, C
  mapping(uint256 => uint256) public worldTraits;

  // The genesis contract address
  IGenesis private genesisContract;

  // Events
  // =========

  event LandData(uint256 landId, uint256 level, uint256 size, uint256 buildingId, uint256[N_TRAITS] traits);  

  // Modifiers
  // =========

  modifier onlyAdmin {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not an owner");
    _;
  }

  constructor() FxBaseChildTunnel(address(0)) {}

  function initialize(address genesisContract_, address fxChild_) external initializer
  {
    __ERC721Enumerable_init();
    __AccessControl_init();
    genesisContract = IGenesis(genesisContract_);
    genesisReceiver = _msgSender();
    fxChild = fxChild_;

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  /**
    * @dev See {IERC165-supportsInterface}.
    */
  function supportsInterface(bytes4 interfaceId)
    public view override(ERC721EnumerableUpgradeable, AccessControlUpgradeable) 
    returns (bool)
  {
    return
      interfaceId == type(IERC721Upgradeable).interfaceId ||
      interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  //////////////////////////////////////////////////////////////
  //                                                          //
  //                         Admin                            //
  //                                                          //
  //////////////////////////////////////////////////////////////

  function setBonusLandPrice(uint256 _price) 
    external onlyAdmin
  {
    bonusLandPrice = _price;
  }

  function setLandLevelUpPrice(uint256 _price)
    external onlyAdmin
  {
    landLevelUpPrice = _price;
  }

  function setLandGrowPrice(uint256 price_)
    external onlyAdmin
  {
    landGrowPrice = price_;
  }

  function setBuildingPrice(uint256 price_)
    external onlyAdmin
  {
    buildingPrice = price_;
  }

  function setMoveLandPrice(uint256 price_)
    external onlyAdmin 
  {
    moveLandPrice = price_;
  }

  function togglePurhcaseActive(bool isActive)
    external onlyAdmin 
  {
    purchaseActive = isActive;
  }

  function setGenesisReceiver(address receiver_)
    external onlyAdmin 
  {
    genesisReceiver = receiver_;
  }

  function setWorldTraits(uint256 worldId, uint256 a, uint256 b, uint256 c)
    external onlyAdmin
  {
    require(1 <= a && a <= 7, "invliad trait");
    require(1 <= b && b <= 7, "invliad trait");
    require(1 <= c && c <= 7, "invliad trait");
    worldTraits[worldId] = a | (b << 4) | (c << 8);
  }

  //////////////////////////////////////////////////////////////
  //                                                          //
  //                         Viewer                           //
  //                                                          //
  //////////////////////////////////////////////////////////////

  function getWorldTraits(uint256 worldId) public view returns (uint256 a, uint256 b, uint256 c)
  {
    uint256 worldTrait = worldTraits[worldId];
    a = worldTrait % 16;
    b = (worldTrait >> 4) % 16;
    c = (worldTrait >> 8) % 16;
  }

  //////////////////////////////////////////////////////////////
  //                                                          //
  //                         Purchase                         //
  //                                                          //
  //////////////////////////////////////////////////////////////

  function claimLand(uint256 worldId, bool buyBonusLand) external {
    // mining claim // world id
    miningClaim.spend(worldId, 1);
    if (buyBonusLand) {
      _takePayment(_msgSender(), bonusLandPrice);
    }
    _deliverLand(worldId, 4, 10);
  }

  function _processMessageFromRoot(uint256 stateId, address sender, bytes memory data) internal override virtual validateSender(sender) {
    (address buyer, address referrer, uint256 worldId, uint256 size) = Encode.decode(data);
    if (referrers[sender] == address(0)) {
      referrers[sender] = referrer;
    }
    _deliverLand(worldId, size, 1);
    if (size >= 2) {
      _deliverLand(worldId, size, 1);
    }
  }

  function _deliverLand(uint256 worldId, uint256 size, uint256 level) internal {
    // initial triats
    uint256[N_TRAITS] memory initialTraits = _getStartingTraits();
    nextParcelId[worldId] = nextParcelId[worldId] + 1;
    uint256 parcelId = nextParcelId[worldId];
    uint256 landId = _getLandId(worldId, parcelId);
    _mint(_msgSender(), landId);
    _storeLandData(worldId, parcelId, size, level, 1, initialTraits);
  }

  function _storeLandData(uint256 worldId, uint256 parcelId, uint256 size, uint256 level, uint256 buildingId, uint256[N_TRAITS] memory traits) internal {
    uint256 landId = _getLandId(worldId, parcelId);
    landDatas[landId] = _encodeLandData(worldId, parcelId, size, level, buildingId, traits);
    emit LandData(landId, level, size, buildingId, traits);
 }

  function _takePayment(address payer, uint256 amount) internal {
    address referrer = referrers[payer];
    if (referrer != address(0)) {
      uint256 referralAmount = amount / 4;
      amount = amount - referralAmount;
      genesisContract.transferFrom(payer, referrer, referralAmount);
    }
    genesisContract.transferFrom(payer, genesisReceiver, amount);
  }

  function _getLandId(uint256 worldId, uint256 parcelId) internal pure returns (uint256 landId) {
    landId = (worldId << 128) | parcelId;
  }

  function _getStartingTraits() internal view returns (uint256[N_TRAITS] memory) {
  }

  function _encodeLandData(uint256 worldId, uint256 parcelId, uint256 size, uint256 level, uint256 buildingId, uint256[N_TRAITS] memory traits) internal view returns (uint256) {
    uint256 premiumStatus = 1;
    uint256 resource = 1;
    uint256 x;
    uint256 y;
    uint256 output;
    // world Id; 32 bit
    output = output | uint32(worldId);
    // parcel Id; 32 bit
    output = (output << 32) | uint32(parcelId);

    // size; 8 bit
    output = (output << 8) | uint8(size);
    // level; 8 bit
    output = (output << 8) | uint8(level);
    // building; 8 bit
    output = (output << 8) | uint8(buildingId);
    // x; 8 bit
    output = (output << 8) | uint16(x);
    // y; 8 bit
    output = (output << 8) | uint16(y);

    (uint256 a, uint256 b, uint256 c) = getWorldTraits(worldId);

    // premiumStatus; 4 bit
    output = (output << 4) | (premiumStatus % 16);
    // bascitrait; 4 bit
    output = (output << 4) | (traits[0] % 16);
    // resource; 4 bit
    output = (output << 4) | (resource % 16);
    // trait; 4 bit
    output = (output << 4) | (traits[1] % 16);
    // worldA; 4 bit
    output = (output << 4) | (a % 16);
    // trait; 4 bit
    output = (output << 4) | (traits[2] % 16);
    // worldB; 4 bit
    output = (output << 4) | (b % 16);
    // trait; 4 bit
    output = (output << 4) | (traits[3] % 16);
    // worldC; 4 bit
    output = (output << 4) | (c % 16);
    // trait; 4 bit
    output = (output << 4) | (traits[4] % 16);
  }
}