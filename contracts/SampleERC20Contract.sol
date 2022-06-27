// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SampleERC20Contract is ERC20 {
    constructor(uint256 initialSupply) ERC20("SampleERC20Contract", "ERC20") {
        _mint(msg.sender, initialSupply);
    }
}