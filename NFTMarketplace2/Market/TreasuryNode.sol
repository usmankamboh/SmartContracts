// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./AddressUpgradeable.sol";
import "./Initializable.sol";
import "./IAdminRole.sol";
import "./IOperatorRole.sol";
error TreasuryNode_Address_Is_Not_A_Contract();
error TreasuryNode_Caller_Not_Admin();
error TreasuryNode_Caller_Not_Operator();
abstract contract TreasuryNode is Initializable {
  using AddressUpgradeable for address payable;
  // This value was replaced with an immutable version.
  address payable private __gap_was_treasury;
  // The address of the treasury contract.
  address payable private immutable treasury;
  // Requires the caller is a smart admin.
  modifier onlyAdmin() {
    if (!IAdminRole(treasury).isAdmin(msg.sender)) {
      revert TreasuryNode_Caller_Not_Admin();
    }
    _;
  }
  // Requires the caller is a smart operator.
  modifier onlyOperator() {
    if (!IOperatorRole(treasury).isOperator(msg.sender)) {
      revert TreasuryNode_Caller_Not_Operator();
    }
    _;
  }
  constructor(address payable _treasury) {
    treasury = _treasury;
  }
  function getTreasury() public view returns (address payable treasuryAddress) {
    return treasury;
  }
  uint256[2000] private __gap;
}