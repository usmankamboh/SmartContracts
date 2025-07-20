// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./IERC165.sol";
interface IRoyaltyRegistry is IERC165 {
    event RoyaltyOverride(address owner, address tokenAddress, address royaltyAddress);
    function setRoyaltyLookupAddress(address tokenAddress, address royaltyAddress) external;
    function getRoyaltyLookupAddress(address tokenAddress) external view returns(address);
    function overrideAllowed(address tokenAddress) external view returns(bool);
}