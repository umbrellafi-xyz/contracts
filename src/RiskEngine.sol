// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FunctionsClient} from './chainlink/functions/FunctionsClient.sol';
import {FunctionsRequest} from './chainlink/functions/libraries/FunctionsRequest.sol';
import {ConfirmedOwner} from './chainlink/shared/access/ConfirmedOwner.sol';

/**
 * @title RiskEngine
 * @notice This is a contract that makes HTTP requests using Chainlink.
 * @dev This contract uses hardcoded values for Mumbai testnet and should not be used in production.
 */
contract RiskEngine is FunctionsClient, ConfirmedOwner {
  using FunctionsRequest for FunctionsRequest.Request;

  struct Configuration {
    address router;
    bytes32 donId;
    string source;
    uint32 gasLimit;
  }

  Configuration public configuration;

  struct RequestPayload {
    address pool;
    uint256 assetIndex;
  }

  mapping(bytes32 => RequestPayload) public requestIds;
  mapping(address => uint256[]) public poolWeights;

  error UnexpectedRequestId(bytes32 requestId);

  event Response(
    bytes32 indexed requestId,
    uint256 weight,
    uint256 index,
    bytes response,
    bytes err
  );

  /**
   * @notice Initializes the contract with the Chainlink router address and sets the contract owner
   */
  constructor(
    address router,
    bytes32 donId,
    string memory source,
    uint32 gasLimit
  ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
    configuration.router = router;
    configuration.donId = donId;
    configuration.source = source;
    configuration.gasLimit = gasLimit;
  }

  /**
   * @notice Sends an HTTP request for risk engine
   * @param subscriptionId The id for the Chainlink subscription
   * @param args The arguments to pass to the HTTP request
   * @return requestId The id of the request
   */
  function sendRequest(
    uint64 subscriptionId,
    uint256 assetIndex,
    address poolAddress,
    string[] calldata args
  ) external onlyOwner returns (bytes32 requestId) {
    FunctionsRequest.Request memory req;

    // Initialize the request with JS code
    req.initializeRequestForInlineJavaScript(configuration.source);
    if (args.length > 0) {
      req.setArgs(args);
    }

    // Send the request and store the request ID
    requestId = _sendRequest(
      req.encodeCBOR(),
      subscriptionId,
      configuration.gasLimit,
      configuration.donId
    );

    requestIds[requestId] = RequestPayload(poolAddress, assetIndex);

    return requestId;
  }

  /**
   * @notice Callback function for fulfilling a request
   * @param requestId The id of the request to fulfill
   * @param response The HTTP response data
   * @param err Any errors from the Functions request
   */
  function fulfillRequest(
    bytes32 requestId,
    bytes memory response,
    bytes memory err
  ) internal override {
    uint256 weight = abi.decode(response, (uint256));
    poolWeights[requestIds[requestId].pool][
      requestIds[requestId].assetIndex
    ] = weight;

    emit Response(
      requestId,
      weight,
      requestIds[requestId].assetIndex,
      response,
      err
    );
  }

  /**
   * @notice Sets pool weights to an array of zeros based on asset count
   */
  function initializePoolWeights(address pool, uint256 assetCount) public {
    poolWeights[pool] = new uint256[](assetCount);
  }

  /**
   * @notice Gets pool weights
   */
  function getPoolWeights(address pool) public view returns (uint256[] memory) {
    return poolWeights[pool];
  }
}
