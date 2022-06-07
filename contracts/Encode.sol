pragma solidity ^0.8.0;
// SPDX-License-Identifier: UNLICENSED

library Encode {
  function encode(address buyer, address referrer, uint256 worldId, uint256 size) public pure returns (bytes memory) {
    return (abi.encode(buyer, referrer, worldId, size));
  }

  function decode(bytes memory data) public pure returns (address, address, uint256, uint256) {
    return abi.decode(data, (address, address, uint256, uint256));            
  }
}  
