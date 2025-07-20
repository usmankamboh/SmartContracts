// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./Initializable.sol";
import "./AddressUpgradeable.sol";
abstract contract TreasuryNode is Initializable {
  using AddressUpgradeable for address payable;
  address payable private treasury;
  function _initializeTreasuryNode(address payable _treasury) internal initializer {
    require(_treasury.isContract(), "TreasuryNode: Address is not a contract");
    treasury = _treasury;
  }
  function getTreasury() public view returns (address payable) {
    return treasury;
  }
  // `______gap` is added to each mixin to allow adding new data slots or additional mixins in an upgrade-safe way.
  uint256[2000] private __gap;
}