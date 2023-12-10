// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Custodian} from './Custodian.sol';
import {RiskEngine} from './RiskEngine.sol';
import {LookupTable} from './libraries/LookupTable.sol';

contract PoolManager {
  struct Pool {
    string[] assets;
    uint256 fee;
    uint256 created;
    uint256 updated;
  }

  uint256 public poolCount;
  mapping(address => Pool) public pools;
  mapping(uint256 => address) public indices;

  LookupTable public lookupTable;

  RiskEngine public riskEngine;
  uint64 public subscriptionId;

  constructor(
    uint64 subId,
    address router,
    bytes32 donId,
    string memory source,
    uint32 gasLimit
  ) {
    riskEngine = new RiskEngine(router, donId, source, gasLimit);
    lookupTable = new LookupTable();
    subscriptionId = subId;
    poolCount = 0;
  }

  function createPool(
    string memory symbol,
    string memory name,
    uint256 fee,
    string[] memory assets
  ) public {
    Custodian token = new Custodian(symbol, name);
    address tokenAddress = address(token);

    indices[poolCount] = tokenAddress;
    pools[tokenAddress] = Pool(assets, fee, block.number, block.number);
    poolCount += 1;

    riskEngine.initializePoolWeights(tokenAddress, assets.length);
  }

  function getAssets(address pool) public view returns (string[] memory) {
    return pools[pool].assets;
  }

  function deposit(uint256 index, uint256 amount) public {
    Custodian custodian = Custodian(indices[index]);
    custodian.deposit(amount);
  }

  /**
   * @notice Calls Chainlink DON which uses the risk engine API to set new asset weights where `args[0]` is
   * the pool index and `args[1]` is the asset index
   */
  function rebalance(uint256 index) public {
    address tokenAddress = indices[index];
    Pool storage pool = pools[tokenAddress];

    for (uint256 i = 0; i < pool.assets.length; i++) {
      string[] memory args = new string[](2);
      args[0] = lookupTable.integers(index);
      args[1] = lookupTable.integers(i);
      riskEngine.sendRequest(subscriptionId, i, tokenAddress, args);
    }
  }
}
