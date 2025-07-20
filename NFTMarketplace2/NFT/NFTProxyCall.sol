// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./AddressUpgradeable.sol";
import "./IProxyCall.sol";
abstract contract NFT721ProxyCall {
  using AddressUpgradeable for address payable;
  IProxyCall private proxyCall;
  event ProxyCallContractUpdated(address indexed proxyCallContract);
  function _updateProxyCall(address proxyCallContract) internal {
    proxyCall = IProxyCall(proxyCallContract);
    emit ProxyCallContractUpdated(proxyCallContract);
  }
  function proxyCallAddress() external view returns (address) {
    return address(proxyCall);
  }
  function _proxyCallAndReturnContractAddress(address externalContract, bytes memory callData)
    internal
    returns (address payable result)
  {
    result = proxyCall.proxyCallAndReturnAddress(externalContract, callData);
    require(result.isContract(), "NFT721ProxyCall: address returned is not a contract");
  }
  // This mixin uses a total of 100 slots
  uint256[99] private ______gap;
}