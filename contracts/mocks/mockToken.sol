// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ILocalContract.sol";


contract mockToken is ERC20 {
    mapping(address => bool) public localContracts;
    address owner;

    constructor() ERC20("mockGAME", "mGAME") {
        _mint(msg.sender, 10**36);
        owner = msg.sender;
    }

    function transferByContract(
        address from_,
        address to_,
        uint256 value_
    ) public {
        require(localContracts[msg.sender], "sender must be a local contract");
        _transfer(from_, to_, value_);
    }

    function updateLocalContract(address contract_, bool isLocal_) external {
        require(msg.sender == owner, "Secure now");
        ILocalContract localContract = ILocalContract(contract_);
        require(localContract.isLocalContract(), "this must be tagged as a local contract");
        localContracts[contract_] = isLocal_;
    }
}

