// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
interface IProxyCall {
  function proxyCallAndReturnAddress(address externalContract, bytes calldata callData)
    external
    returns (address payable result);
}