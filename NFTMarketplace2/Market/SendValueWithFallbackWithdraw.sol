// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.15;
import "./AddressUpgradeable.sol";
import "./ReentrancyGuardUpgradeable.sol";
import "./NFTMarketCore.sol";
error SendValueWithFallbackWithdraw_No_Funds_Available();
abstract contract SendValueWithFallbackWithdraw is NFTMarketCore, ReentrancyGuardUpgradeable {
  using AddressUpgradeable for address payable;
  // Tracks the amount of ETH that is stored in escrow for future withdrawal.
  mapping(address => uint256) private __gap_was_pendingWithdrawals;
  event WithdrawalToSETH(address indexed user, uint256 amount);
  function _sendValueWithFallbackWithdraw(
    address payable user,
    uint256 amount,
    uint256 gasLimit
  ) internal {
    if (amount == 0) {
      return;
    }
    // Cap the gas to prevent consuming all available gas to block a tx from completing successfully
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = user.call{ value: amount, gas: gasLimit }("");
    if (!success) {
      // Store the funds that failed to send for the user in the SETH token
      seth.depositFor{ value: amount }(user);
      emit WithdrawalToSETH(user, amount);
    }
  }
  function _trySendValue(
    address payable user,
    uint256 amount,
    uint256 gasLimit
  ) internal returns (bool success) {
    if (amount == 0) {
      return false;
    }
    // Cap the gas to prevent consuming all available gas to block a tx from completing successfully
    // solhint-disable-next-line avoid-low-level-calls
    (success, ) = user.call{ value: amount, gas: gasLimit }("");
  }
  uint256[999] private __gap;
}