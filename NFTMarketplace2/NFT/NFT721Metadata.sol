// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./StringsUpgradeable.sol";
import "./NFT721Core.sol";
import "./NFT721Creator.sol";
abstract contract NFT721Metadata is NFT721Creator {
  using StringsUpgradeable for uint256;
  mapping(address => mapping(string => bool)) private creatorToIPFSHashToMinted;
  event BaseURIUpdated(string baseURI);
  event TokenIPFSPathUpdated(uint256 indexed tokenId, string indexed indexedTokenIPFSPath, string tokenIPFSPath);
  // This event was used in an order version of the contract
  event NFTMetadataUpdated(string name, string symbol, string baseURI);
  function getTokenIPFSPath(uint256 tokenId) public view returns (string memory) {
    return _tokenURIs[tokenId];
  }
  function getHasCreatorMintedIPFSHash(address creator, string memory tokenIPFSPath) public view returns (bool) {
    return creatorToIPFSHashToMinted[creator][tokenIPFSPath];
  }
  function _updateBaseURI(string memory _baseURI) internal {
    _setBaseURI(_baseURI);

    emit BaseURIUpdated(_baseURI);
  }
  function _setTokenIPFSPath(uint256 tokenId, string memory _tokenIPFSPath) internal {
    // 46 is the minimum length for an IPFS content hash, it may be longer if paths are used
    require(bytes(_tokenIPFSPath).length >= 46, "NFT721Metadata: Invalid IPFS path");
    require(!creatorToIPFSHashToMinted[msg.sender][_tokenIPFSPath], "NFT721Metadata: NFT was already minted");
    creatorToIPFSHashToMinted[msg.sender][_tokenIPFSPath] = true;
    _setTokenURI(tokenId, _tokenIPFSPath);
  }
  function _burn(uint256 tokenId) internal virtual override {
    delete creatorToIPFSHashToMinted[msg.sender][_tokenURIs[tokenId]];
    super._burn(tokenId);
  }
  uint256[999] private ______gap;
}