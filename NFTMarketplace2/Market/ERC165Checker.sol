// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./IERC165.sol";
library OZERC165Checker {
  // As per the EIP-165 spec, no interface should ever match 0xffffffff
  bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;
  function supportsERC165(address account) internal view returns (bool) {
    // Any contract that implements ERC165 must explicitly indicate support of
    // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
    return
      supportsERC165Interface(account, type(IERC165).interfaceId) &&
      !supportsERC165Interface(account, _INTERFACE_ID_INVALID);
  }
  function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
    // query support of both ERC165 as per the spec and support of _interfaceId
    return supportsERC165(account) && supportsERC165Interface(account, interfaceId);
  }
  function getSupportedInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool[] memory) {
    // an array of booleans corresponding to interfaceIds and whether they're supported or not
    bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);
    // query support of ERC165 itself
    if (supportsERC165(account)) {
      // query support of each interface in interfaceIds
      unchecked {
        for (uint256 i = 0; i < interfaceIds.length; ++i) {
          interfaceIdsSupported[i] = supportsERC165Interface(account, interfaceIds[i]);
        }
      }
    }
    return interfaceIdsSupported;
  }
  function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
    // query support of ERC165 itself
    if (!supportsERC165(account)) {
      return false;
    }
    // query support of each interface in _interfaceIds
    unchecked {
      for (uint256 i = 0; i < interfaceIds.length; ++i) {
        if (!supportsERC165Interface(account, interfaceIds[i])) {
          return false;
        }
      }
    }
    // all interfaces supported
    return true;
  }
  function supportsERC165Interface(address account, bytes4 interfaceId) internal view returns (bool) {
    bytes memory encodedParams = abi.encodeWithSelector(IERC165(account).supportsInterface.selector, interfaceId);
    (bool success, bytes memory result) = account.staticcall{ gas: 30000 }(encodedParams);
    if (result.length < 32) return false;
    return success && abi.decode(result, (bool));
  }
}