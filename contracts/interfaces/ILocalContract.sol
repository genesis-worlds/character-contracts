// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// @title iLocalContract
// @author GAME Credits (gamecredits.org)
abstract contract ILocalContract {

  function updateLocalContract(address contract_, bool isLocal_) external virtual {}

  function isLocalContract()
    external
    virtual
    pure
  returns(bool) {
    return true;
  }
}