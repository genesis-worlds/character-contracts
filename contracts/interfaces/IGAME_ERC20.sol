// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// @title IGAME_ERC20
// @dev The interface for the Auction & ERC-20 contract
//  Only methods required for calling by sibling contracts are required here
// @author GAME Credits (gamecredits.org)
abstract contract IGAME_ERC20 is IERC20 {
    function cancelAuctionByManager(uint256 tokenId_) external virtual;

    function transferByContract(
        address from_,
        address to_,
        uint256 value_
    ) external virtual;

    function linkContracts(address gameContract_, address erc721Contract_)
        external
        virtual;

    function getGameBalance(uint256 game_)
        public
        view
        virtual
        returns (uint256 balance);

    function getLoyaltyPointsGranted(uint256 game_, address account_)
        public
        view
        virtual
        returns (uint256 currentPoints);

    function getLoyaltyPointSpends(uint256 game_, address account_)
        public
        view
        virtual
        returns (uint256 currentPoints);

    function getLoyaltyPointsTotal(uint256 game_, address account_)
        public
        view
        virtual
        returns (uint256 currentPoints);

    function thirdPartySpendLoyaltyPoints(
        uint256 game_,
        address account_,
        uint256 pointsToSpend_
    ) external virtual;
}
