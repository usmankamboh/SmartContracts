// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./Initializable.sol";
import "./ERC165.sol";
import "./IHasSecondarySaleFees.sol";
abstract contract HasSecondarySaleFees is Initializable, ERC165, IHasSecondarySaleFees {
  function getFeeRecipients(uint256 id) public view virtual override returns (address payable[] memory);

  function getFeeBps(uint256 id) public view virtual override returns (uint256[] memory);

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    if (interfaceId == type(IHasSecondarySaleFees).interfaceId) {
      return true;
    }
    return super.supportsInterface(interfaceId);
  }
}