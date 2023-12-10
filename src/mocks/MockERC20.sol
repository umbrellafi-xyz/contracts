// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
  uint256 public constant INITIAL_SUPPLY = 10e18;

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  /// @dev Unpermissioned minting for testing
  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }
}
