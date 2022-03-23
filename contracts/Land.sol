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
import "@openzeppelin/contracts//utils/math/SafeMath.sol";

import "./interfaces/IGenesis.sol";
import "./interfaces/IGAME_ERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/ILocalContract.sol";

contract Character is ERC721Enumerable, AccessControl, ILocalContract {
  using SafeMath for uint;
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

  string[] districtDataSet = ["A", "B", "C", "D", "E", "F", 'G'];

  // burn address is changeable if necessary. Dead address must remain the same
  address burnAddress = 0x000000000000000000000000000000000000dEaD;
  address deadAddress = 0x000000000000000000000000000000000000dEaD;

  mapping (uint => uint) public presaleStartTimes;
  mapping (uint => uint) public saleStartTimes;

  mapping (uint => uint) public districts;
  mapping (uint => uint) public crossChainDistricts;

  // Map buildings to parcels and vice versa
  mapping (uint => uint) public buildingToParcel;
  mapping (uint => uint) public parcelToBuilding;

  event MoveBuilding(uint building, uint onParcel, uint parcel, address owner);
  event SaleStart(uint world, uint districts, uint claimStartTime, uint saleStartTime);
  event ParcelBought(uint parcelId, uint claimsPaid, uint genesisPaid, uint maticPaid);

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

  // ADMINISTRATION functions
  // ========================

  // Connect a building to another land, disconnect a building from a land
  function moveBuilding(uint building_, uint fromParcel_, uint toParcel_) 
    public
  {
    _moveBuilding(building_, fromParcel_, toParcel_, _msgSender());
  }

  // Can move a building you own from any land
  // Can move any building from a land you own
  // Can move a building you own onto a land you own
  function _moveBuilding(uint building_, uint fromParcel_, uint toParcel_, address owner_)
    internal 
  {
    uint buildingOnFromParcel = parcelToBuilding[fromParcel_];
    uint buildingOnToParcel = parcelToBuilding[toParcel_];
    require(buildingToParcel[building_] == fromParcel_, "must be on the parcel you state");
    address buildingOwner = ownerOf(building_);
    if(fromParcel_ > 0) {
      require(buildingOnFromParcel == building_, "building must be on fromParcel");
      require(owner_ == ownerOf(fromParcel_) || owner_ == buildingOwner, "sender must own fromParcel and/or building");
      delete parcelToBuilding[fromParcel_];
    }
    if(toParcel_ > 0) {
      require(buildingOnToParcel == 0, "toParcel must be empty");
      require(owner_ == buildingOwner, "sender must own building");
      require(ownerOf(toParcel_) == owner_, "sender must own toParcel");
      parcelToBuilding[toParcel_] = building_;
      uint parcelSize = getParcelSize(toParcel_);
      uint buildingSize = getBuildingSize(building_);
      require(parcelSize >= buildingSize, "building must fit on the parcel");
    }
    buildingToParcel[building_] = toParcel_;
    emit MoveBuilding(building_, fromParcel_, toParcel_, owner_);
  }

  // A sale manager (person or contract) can set up world sales for worlds
  // World sales can only be changed before it goes on sale
  function initializeParcelSale(uint world_, uint districts_, uint startTime_, uint presaleDuration_)
    public onlySaleManager
  {
    require(world_ < 1000000, "only for on-chain worlds");
    require(block.timestamp < startTime_, "sale has started");
    uint saleStartTime = startTime_ + presaleDuration_;
    presaleStartTimes[world_] = startTime_;
    saleStartTimes[world_] = saleStartTime;
    districts[world_] = districts_;
    emit SaleStart(world_, districts_, startTime_, saleStartTime);
  }

  function createBuilding(uint buildingId_, uint size_, uint trait_) 
    public onlyBuildingManager 
  {
    // how do we set this up in a smart way? Ideally we can create more buildings over time in a smooth way.
    // And we 
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

  /*function initializeCrossChainWorld(uint world_, uint numberOfDistricts_, bool isOverride_)
    public onlyOracle
  {
    require(world_ >= 1000000, "only for cross-chain worlds");
    crossChainDistricts[world_] = numberOfDistricts_;
  }*/

  // PURCHASE functions
  // ==================

  function claimParcels(uint world_, uint[] calldata parcelIds_)
    public
  {
    address sender = _msgSender();
    uint totalPrice = 0;
    // need to get the parcel size and building size, and make sure they fit
    for(uint i = 0; i < parcelIds_.length; i++) {
      uint parcelId = parcelIds_[i];
      (uint world, , , uint size) = parseParcelId(parcelId);
      uint price = size.mul(size);
      totalPrice = totalPrice.add(price);
      emit ParcelBought(parcelId, price, 0, 0);
      _deliverParcel(world, parcelId);
    }
    // take payment in claims
    worldContract.safeTransferFrom(sender, deadAddress, world_, totalPrice, "");
  }

  function buyParcelsWithGenesis(uint world_, uint[] calldata parcelIds_) 
    public 
  {

    address sender = _msgSender();
    uint totalPrice = 0;
    // need to get the parcel size and building size, and make sure they fit
    for(uint i = 0; i < parcelIds_.length; i++) {
      uint parcelId = parcelIds_[i];
      (uint world, , , uint size) = parseParcelId(parcelId);
      require(world == world_, "Parcel must be from this world");

      uint price = priceInGenesis.mul(size).mul(size);
      totalPrice = totalPrice.add(price);
      emit ParcelBought(parcelId, 0, price, 0);
      // deliver the parcel
      _deliverParcel(world, parcelId);
    }

    // take payment, half to burn, half to dev fund
    uint halfOfPrice = totalPrice.div(2);
    genesisContract.transferFrom(sender, burnAddress, halfOfPrice);
    genesisContract.transferFrom(sender, feeReceiver, halfOfPrice);

  }

  function buyParcelsWithMatic(uint world_, uint[] calldata parcelIds_) 
    public payable
  {
    uint totalPrice = 0;
    // need to get the parcel size and building size, and make sure they fit
    for(uint i = 0; i < parcelIds_.length; i++) {
      uint parcelId = parcelIds_[i];
      (uint world, , , uint size) = parseParcelId(parcelId);
      require(world == world_, "Parcel must be from this world");
      // need to get the parcel price
      uint price = priceInMatic.mul(size).mul(size);
      totalPrice = totalPrice.add(price);
      emit ParcelBought(parcelId, 0, 0, price);
      _deliverParcel(world, parcelId);
    }
    require(msg.value == totalPrice, "Price must match");
    (bool sent, ) = address(this).call{value: msg.value}("");
    require(sent, "Failed to send Ether");
  }

  function _deliverParcel(uint world_, uint parcelId_)
    internal
  {
    // ensure parcel exists
    // ensure parcel can be delivered
    // store parcel data
    // if there's a building, deliver it too
    // store building data
    // Emit movebuilding
  }


  /*function deliverCrossChainParcel(
    uint world_,
    uint district_,
    uint parcel_,
    uint building_,
    address recipient_,
    bool isOverride_
  ) public onlyOracle {
    require(crossChainDistricts[world_] > 0, "districts must be set");
    require(district_ <= crossChainDistricts[world_] && district_ > 0, "district must exist");
    require(parcel_ > 0, "parcel must be non-zero");
    uint256 tokenId = encodeParcelId(world_, district_, parcel_);
    require(_owners(tokenId) = address(0), "must not be owned");

    // Set the token data and emit an event

    _mint(recipient_, tokenId);
  }*/

  // VIEW and PURE functions
  // =======================

  function tokenURI(uint256 tokenId)
    public view override
    returns (string memory) 
  {
    return string(abi.encodePacked(baseURI, "?i=", tokenId)); //, "&d=", tokenStats[tokenId]));
  }

  function getParcelSize(uint parcelId_)
    public pure
    returns(uint size)
  {
    uint256 districtSeed = parcelId_ / 1000 * 1000;
    uint256 parcelNumber = parcelId_ % 1000;
    uint parcelData = getParcelData(districtSeed); // 23 possible parcels, can change this

    // Parcel size is pulled from a lookup of what the district is.
    // Size is 1/2/4/6
    // ParcelData is built from 64 uint3 numbers (0-8, but only using 1,2,4,6)
    // it looks like a string of 64 numbers: 0x111111111122222244446
    uint256 parcelSize = parcelNumber >= 64 ? 1 : (parcelData << parcelNumber * 4) % 16;
  }

  // building sizes are encoded into first digit of the building ID
  function getBuildingSize(uint buildingId_)
    public pure
    returns(uint size)
  {
    size = buildingId_ << 248;
  }

  function encodeParcelId(uint world_, uint district_, uint parcel_) 
    public pure 
    returns(uint parcelId)
  {
    require(world_ < 1000000);
    require(district_ < 100);
    require(parcel_ < 1000);
    parcelId = world_ * 100000 + district_ * 1000 + parcel_;
  }

  function parseParcelId(uint parcelId_) 
    public pure 
    returns(uint world, uint district, uint parcel, uint size) 
  {
    world = parcelId_ / 100000;
    parcel = parcelId_ % 1000;
    district = (parcelId_ - parcel) % 100000;
    size = getParcelSize(parcelId_);

    // We can simplify this by having a single district setup: 1x 6x6, 4x 4x4, 16x 2x2, 92x 1x1
  }

  // Might want to key parcel data off traits rather than parcelId/world
  // If we expect 24 districts per world, we could have 4 parcels per type (28 total),
  //   and double up each of them
  function getParcelData(uint districtSeed_)
    public pure 
    returns(uint data) 
  {
    uint key = districtSeed_ % 23;
    data = key == 0 ? 0xabcdefabcdefabcdabcdefabcdefabcdabcdefabcdefabcdabcdefabcdefabcd :
      key == 1 ? 0xabcdefabcdefabcdabcdefabcdefabcdabcdefabcdefabcdabcdefabcdefabcd : 0xabcdefabcdefabcdabcdefabcdefabcdabcdefabcdefabcdabcdefabcdefabcd;
      // " 23 total lines here. Cheaper to do this than do a lookup";
  }

  function getWorldTraits(uint worldId_)
    public pure 
    returns(uint[3] memory traits)
  {
    if(worldId_ > 35 || worldId_ == 0) {
      // Not a core world, random traits, can brute force select if we need to pick for a client
      uint trait1 = worldId_ % 7;
      uint trait2 = worldId_ % 6;
      trait2 = trait2 == trait1 ? 7 : trait2;
      uint trait3 = worldId_ % 5; // 0 is slightly over-represented; 1 less so
      trait3 = trait3 == trait1 ? 7 : trait3 == trait2 ? 6 : trait3;
      traits = [trait1, trait2, trait3];
    } else {
      // core world, table of 35 rows of specific traits to look up.
      traits = worldId_ == 1 ? [uint(1), uint(2), uint(3)] : 
        worldId_ == 2 ? [uint(1), uint(2), uint(3)] : [uint(1), uint(2), uint(3)];
        // ... [world % 7
    }
  }

  function getParcelTraits(uint parcelId_) 
    public pure 
    returns(uint size, uint trait, uint building, uint[3] memory attributes)
  {
    (uint world, uint district, uint parcel, uint size_) = parseParcelId(parcelId_);
    size = size_;
  // would be better to hash these seeds, so it’s not everything just in order
    uint256 seed = world + district + parcel;
    uint256[3] memory traits = getWorldTraits(world);

    // Trait is 1 of the 3 for the world - this is pulled from the storage data of the world
    trait = traits[seed % 3]; 

    // building 
    uint buildingType = seed % 5;
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

  function getDistrictData(uint districtHash_) 
    public pure
    returns(uint districtData) 
  {
    uint256 districtType = districtHash_ % 16;
    if(districtType == 0) {
      return 1;
    } else if(districtType == 1) {
      return 2;
    } 
    // FIXME - finish this
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
}