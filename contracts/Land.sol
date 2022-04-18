pragma solidity ^0.8.0;
// SPDX-License-Identifier: UNLICENSED

/*
  Needs:
  foundation share
  Assign parcels before sale starts (list of parcels)
  Slightly larger district sizes? More larger parcels? More districts per world?
  District and parcel level data
  Land/Districts from mainnet sales
  Mainnet land sale contract (just a straight 721?)
*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IGenesis.sol";
import "./interfaces/IGAME_ERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/ILocalContract.sol";

contract Character is ERC721Enumerable, AccessControl, ILocalContract {
  using SafeMath for uint256;
  bytes32 public constant ORACLE = keccak256("ORACLE");
  bytes32 public constant SALE_MANAGER = keccak256("SALE_MANAGER");
  bytes32 public constant BUILDING_MANAGER = keccak256("BUILDING_MANAGER");

  /// @notice Base URI
  string public baseURI = "https://images.genesis.game/land/json/";

  /// @notice Price in Genesis
  uint256 public priceInGenesis = 2000 * 10**18;
  
  /// @notice Price in Matic
  uint256 public priceInMatic = 200 * 10**18;

  // The genesis contract address
  IGenesis genesisContract;

  // The world contract address
  IERC1155 worldContract;

  /// @notice Receiver address to receive fees
  address public feeReceiver = 0x6C6C6ad72Eb172942BA68690c865e9864EA42eA2;

  // burn address is changeable if necessary. Dead address must remain the same
  address burnAddress = 0x000000000000000000000000000000000000dEaD;
  address deadAddress = 0x000000000000000000000000000000000000dEaD;

  mapping (uint256 => uint256) public presaleStartTimes;
  mapping (uint256 => uint256) public saleStartTimes;

  mapping (uint256 => uint256) public parcelTraits;

  mapping (uint256 => uint256[5]) public totalParcelCounts;

  uint256[5] public priceUnitsByParcelSize = [1, 4, 8, 16, 32];
  mapping (uint256 => uint256[5]) maxParcelsPerWorld;
  mapping (uint256 => uint256[5]) foundationParcelsPerWorld;

  event SaleStart(uint256 world, uint256 districts, uint256 claimStartTime, uint256 saleStartTime);
  event ParcelBought(uint256 parcelId, uint256 claimsPaid, uint256 genesisPaid, uint256 maticPaid);
  event ParcelTraits(uint256 parcelId);
  event BuildingTraits(uint256 parcelId);

  // Modifiers
  // =========

  modifier onlyAdmin {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not an owner");
    _;
  }

  modifier onlySaleManager {
    require(hasRole(SALE_MANAGER, _msgSender()), "Not a sale manager");
    _;
  }

  modifier onlyBuildingManager {
    require(hasRole(BUILDING_MANAGER, _msgSender()), "Not a sale manager");
    _;
  }

  modifier onlyOracle {
    require(hasRole(ORACLE, _msgSender()), "Not an oracle");
    _;
  }

  constructor(address genesisContract_, address worldContract_)
    ERC721("Genesis Worlds Land", "LAND")
  {
    genesisContract = IGenesis(genesisContract_);
    worldContract = IERC1155(worldContract_);

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(SALE_MANAGER, _msgSender());
    _setupRole(ORACLE, _msgSender());
    _setRoleAdmin(SALE_MANAGER, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(ORACLE, DEFAULT_ADMIN_ROLE);
  }

  /**
    * @dev See {IERC165-supportsInterface}.
    */
  function supportsInterface(bytes4 interfaceId)
    public view override(ERC721Enumerable, AccessControl) 
    returns (bool)
  {
    return
      interfaceId == type(IERC721).interfaceId ||
      interfaceId == type(IERC721Metadata).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  //////////////////////////////////////////////////////////////
  //                                                          //
  //                         Admin                            //
  //                                                          //
  //////////////////////////////////////////////////////////////

  // A sale manager (person or contract) can set up world sales for worlds
  // World sales can only be changed before it goes on sale
  function initializeParcelSale(uint256 world_, uint256 districts_, uint256 startTime_, uint256 presaleDuration_)
    public onlySaleManager
  {
    require(world_ < 1000000, "only for on-chain worlds");
    require(block.timestamp < startTime_, "sale has started");
    uint256 saleStartTime = startTime_ + presaleDuration_;
    presaleStartTimes[world_] = startTime_;
    saleStartTimes[world_] = saleStartTime;
    emit SaleStart(world_, districts_, startTime_, saleStartTime);
  }

  function setFeeReceiver(address feeReceiver_) 
    external onlyAdmin
  {
      feeReceiver = feeReceiver_;
  }

  function setBurnAddress(address burnAddress_)
    external onlyAdmin
  {
      burnAddress = burnAddress_;
  }

  function setBaseURI(string memory baseURI_)
    external onlyAdmin
  {
      baseURI = baseURI_;
  }

  function setPriceInGenesis(uint256 priceInGenesis_)
    external onlyAdmin
  {
      priceInGenesis = priceInGenesis_;
  }

  function setPriceInMatic(uint256 priceInMatic_)
    external onlyAdmin
  {
      priceInMatic = priceInMatic_;
  }

  function setPriceUnitsByParcelSize(uint256[5] memory _priceUnits)
    external onlyAdmin 
  {
    for (uint256 i = 0; i < 5; i += 1) {
      priceUnitsByParcelSize[i] = _priceUnits[i];
    } 
  }

  function setParcelsPerWorld(uint256 world, uint256[5] memory _max, uint256[5] memory _foundation)
    external onlyAdmin
  {
    // TODO: (a) the function can’t be called if a parcel for that world exists

    require(presaleStartTimes[world] > block.timestamp, "Presale already started");

    for (uint256 i = 0; i < 5; i += 1) {
      require(_max[i] + _foundation[i] < 10000, "9999 is maximum parcels per world");
      maxParcelsPerWorld[world][i] = _max[i];
      foundationParcelsPerWorld[world][i] = _foundation[i];
    }
  }

  /*function initializeCrossChainWorld(uint256 world_, uint256 numberOfDistricts_, bool isOverride_)
    public onlyOracle
  {
    require(world_ >= 1000000, "only for cross-chain worlds");
  }*/

  //////////////////////////////////////////////////////////////
  //                                                          //
  //                         Purchase                         //
  //                                                          //
  //////////////////////////////////////////////////////////////

  // Parcels can only be granted by a sale manager
  // Parcels can be granted any time after the sale is set up,
  //   even before/during the presale or during/after the main sale
  function grantParcels(address recipient, uint256 world_, uint256[5] calldata amounts)
    public
    onlySaleManager
  {
    require(presaleStartTimes[world_] > 0, "World is not ready for sale");
    for (uint256 size = 0; size < 5; size++) {
      for(uint256 i = 0; i < amounts[size]; i++) {
        require(totalParcelCounts[world_][size] < foundationParcelsPerWorld[world_][size], "Exceeds foundation parcels count");
        uint256 parcelId = totalParcelCounts[world_][size];
        (uint256 world, uint256 district, uint256 parcel, uint256 size) = parseParcelId(parcelId);
        require(world == world_, "Parcel must be from this world");
        emit ParcelBought(parcelId, 0, 0, 0);
        _deliverParcel(recipient, parcelId, world, district, parcel, size);
      }
    }
  }

  // Parcels can be claimed with mining claims during the presale or regular sale
  function claimParcels(address recipient, uint256 world_, uint256[] calldata parcelIds_)
    public
  {
    require(presaleStartTimes[world_] > block.timestamp, "Presale has not started");
    address sender = _msgSender();
    uint256 totalPrice = 0;
    // need to get the parcel size and building size, and make sure they fit
    for(uint256 i = 0; i < parcelIds_.length; i++) {
      uint256 parcelId = parcelIds_[i];
      (uint256 world, uint256 district, uint256 parcel, uint256 size) = parseParcelId(parcelId);
      require(world == world_, "Parcel must be from this world");

      uint256 price = size.mul(size);
      totalPrice = totalPrice.add(price);
      emit ParcelBought(parcelId, price, 0, 0);
      _deliverParcel(recipient, parcelId, world, district, parcel, size);
    }
    // take payment in claims
    worldContract.safeTransferFrom(sender, deadAddress, world_, totalPrice, "");
  }

  // Parcels can be bought with GENESIS only during the regular sale, not the presale
  function buyParcelsWithGenesis(address recipient, uint256 world_, uint256[] calldata parcelIds_) 
    public 
  {
    require(saleStartTimes[world_] > block.timestamp, "Regular sale has not started");
    address sender = _msgSender();
    uint256 totalPrice = 0;
    // need to get the parcel size and building size, and make sure they fit
    for(uint256 i = 0; i < parcelIds_.length; i++) {
      uint256 parcelId = parcelIds_[i];
      (uint256 world, uint256 district, uint256 parcel, uint256 size) = parseParcelId(parcelId);
      require(world == world_, "Parcel must be from this world");

      uint256 price = priceInGenesis.mul(size).mul(size);
      totalPrice = totalPrice.add(price);
      emit ParcelBought(parcelId, 0, price, 0);
      // deliver the parcel
      _deliverParcel(recipient, parcelId, world, district, parcel, size);
    }

    // take payment, half to burn, half to dev fund
    uint256 halfOfPrice = totalPrice.div(2);
    genesisContract.transferFrom(sender, burnAddress, halfOfPrice);
    genesisContract.transferFrom(sender, feeReceiver, halfOfPrice);

  }

  // Parcels can be bought with MATIC only during the regular sale, not the presale
  function buyParcelsWithMatic(address recipient, uint256 world_, uint256[] calldata parcelIds_) 
    public payable
  {
    require(saleStartTimes[world_] > block.timestamp, "Regular sale has not started");
    uint256 totalPrice = 0;
    // need to get the parcel size and building size, and make sure they fit
    for(uint256 i = 0; i < parcelIds_.length; i++) {
      uint256 parcelId = parcelIds_[i];
      (uint256 world, uint256 district, uint256 parcel, uint256 size) = parseParcelId(parcelId);
      require(world == world_, "Parcel must be from this world");

      // need to get the parcel price
      uint256 price = priceInMatic.mul(size).mul(size);
      totalPrice = totalPrice.add(price);
      emit ParcelBought(parcelId, 0, 0, price);
      _deliverParcel(recipient, parcelId, world, district, parcel, size);
    }
    require(msg.value == totalPrice, "Price must match");
    (bool sent, ) = address(this).call{value: msg.value}("");
    require(sent, "Failed to send Ether");
  }

  // parcels and districts are zero-based, so the 6x6 parcel in each district is parcel 0
  // worlds are both 1-based, so district #0 and world #0 are invalid
  function _deliverParcel(address recipient, uint256 parcelId_, uint256 world_, uint256 district_, uint256 parcel_, uint256 size_)
    internal
  {
    // ensure parcel and district exists
    require(district_ < 24, "invalid district"); // need to check whether the district exists somehow
    require(parcel_ < 113, "invalid parcel");
    // deliver the parcel
    _mint(recipient, parcelId_);
    totalParcelCounts[world_][size_] = totalParcelCounts[world_][size_] + 1;
    // store parcel data
    // traits, size, etc
    (uint256 size, uint trait,,) = getParcelTraits(parcelId_);
    emit ParcelTraits(parcelId_);
    // if there's a building, deliver it too: figure out what building (if any is attached)

    // store building data

    // Deliver the building, and attach it to the land
    uint256 buildingId = 0xfffffffffffffffffff;
    _mint(recipient, buildingId);
  }


  /*function deliverCrossChainParcel(
    uint256 world_,
    uint256 district_,
    uint256 parcel_,
    uint256 building_,
    address recipient_,
    bool isOverride_
  ) public onlyOracle {
    require(parcel_ > 0, "parcel must be non-zero");
    uint256 tokenId = encodeParcelId(world_, district_, parcel_);
    require(_owners(tokenId) = address(0), "must not be owned");

    // Set the token data and emit an event

    _mint(recipient_, tokenId);
  }*/


  //////////////////////////////////////////////////////////////
  //                                                          //
  //                       VIEW and PURE                      //
  //                                                          //
  //////////////////////////////////////////////////////////////

  function tokenURI(uint256 tokenId)
    public view override
    returns (string memory) 
  {
    return string(abi.encodePacked(baseURI, "?i=", tokenId)); //, "&d=", tokenStats[tokenId]));
  }

  function encodeParcelId(uint256 world_, uint256 size_, uint256 parcel_) 
    public pure 
    returns(uint256 parcelId)
  {
    require(world_ < 1000000000000);
    require(size_ < 5);
    require(parcel_ < 10000);
    parcelId = world_ * 100000 + size_ * 10000 + parcel_;
  }

  function parseParcelId(uint256 parcelId_) 
    public pure 
    returns(uint256 world, uint256 district, uint256 parcel, uint256 size) 
  {
    world = parcelId_ / 100000;
    parcel = parcelId_ % 10000;
    size = (parcelId_ - parcel) % 100000;
  }

  function getWorldTraits(uint256 worldId_)
    public pure 
    returns(uint256[3] memory traits)
  {
    if(worldId_ > 35 || worldId_ == 0) {
      // Not a core world, random traits, can brute force select if we need to pick for a client
      uint256 trait1 = worldId_ % 7;
      uint256 trait2 = worldId_ % 6;
      trait2 = trait2 == trait1 ? 7 : trait2;
      uint256 trait3 = worldId_ % 5; // 0 is slightly over-represented; 1 less so
      trait3 = trait3 == trait1 ? 7 : trait3 == trait2 ? 6 : trait3;
      traits = [trait1, trait2, trait3];
    } else {
      // core world, table of 35 rows of specific traits to look up.
      traits = worldId_ == 1 ? [uint256(1), uint256(2), uint256(3)] : 
        worldId_ == 2 ? [uint256(1), uint256(2), uint256(3)] : [uint256(1), uint256(2), uint256(3)];
        // ... [world % 7
    }
  }

  function getParcelTraits(uint256 parcelId_) 
    public pure 
    returns(uint256 size, uint256 trait, uint256 building, uint256[3] memory attributes)
  {
    (uint256 world, uint256 district, uint256 parcel, uint256 size_) = parseParcelId(parcelId_);
    size = size_;
  // would be better to hash these seeds, so it’s not everything just in order
    uint256 seed = world + district + parcel;
    uint256[3] memory traits = getWorldTraits(world);

    // Trait is 1 of the 3 for the world - this is pulled from the storage data of the world
    trait = traits[seed % 3]; 

    // building 
    uint256 buildingType = seed % 5;
    building = buildingType == 0 || size < 2 ? 0 
      : size == 2 ? buildingType + 4 
      : size == 4 ? buildingType / 2 + 2
      : buildingType / 2;

    // Attributes are based on the plot’s trait, and a random roll
    uint256 attributeBase = trait * 100 + 1;
    attributes[0] = seed % 13 + attributeBase; // one of attribute 1-13
    attributes[1] = seed % 11 + attributeBase + 13; // one of attribute 14-24
    attributes[2] = seed % 7 + attributeBase + 24; // one of attribute 25-31
  }

  function getMaxParcelsPerWorld(uint256 world)
    public view returns (uint256[5] memory)
  {
    return maxParcelsPerWorld[world];
  }

  function getFoundationParcelsPerWorld(uint256 world)
    public view returns (uint256[5] memory)
  {
    return foundationParcelsPerWorld[world];
  }
}