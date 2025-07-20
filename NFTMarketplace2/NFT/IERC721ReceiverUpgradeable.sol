// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
interface IERC721ReceiverUpgradeable {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}