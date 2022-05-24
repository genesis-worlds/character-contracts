// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMiningClaim {
    function spend(uint256 worldId, uint256 amount) external;
}
