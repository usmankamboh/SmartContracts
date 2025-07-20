// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./ERC721Upgradeable.sol";
import "./Initializable.sol";
import "./NFT721Creator.sol";
import "./NFT721Market.sol";
import "./NFT721Metadata.sol";
import "./NFT721ProxyCall.sol";
abstract contract NFT721Mint is
  Initializable,
  ERC721Upgradeable,
  NFT721ProxyCall,
  NFT721Creator,
  NFT721Market,
  NFT721Metadata
{
  uint256 private nextTokenId;
  event Minted(
    address indexed creator,
    uint256 indexed tokenId,
    string indexed indexedTokenIPFSPath,
    string tokenIPFSPath
  );
  function getNextTokenId() public view returns (uint256) {
    return nextTokenId;
  }
  function _initializeNFT721Mint() internal initializer {
    // Use ID 1 for the first NFT tokenId
    nextTokenId = 1;
  }
  function mint(string memory tokenIPFSPath) public returns (uint256 tokenId) {
    tokenId = nextTokenId++;
    _mint(msg.sender, tokenId);
    _updateTokenCreator(tokenId, payable(msg.sender));
    _setTokenIPFSPath(tokenId, tokenIPFSPath);
    emit Minted(msg.sender, tokenId, tokenIPFSPath, tokenIPFSPath);
  }
  function mintAndApproveMarket(string memory tokenIPFSPath) public returns (uint256 tokenId) {
    tokenId = mint(tokenIPFSPath);
    setApprovalForAll(getNFTMarket(), true);
  }
  function mintWithCreatorPaymentAddress(string memory tokenIPFSPath, address payable tokenCreatorPaymentAddress)
    public
    returns (uint256 tokenId)
  {
    require(tokenCreatorPaymentAddress != address(0), "NFT721Mint: tokenCreatorPaymentAddress is required");
    tokenId = mint(tokenIPFSPath);
    _setTokenCreatorPaymentAddress(tokenId, tokenCreatorPaymentAddress);
  }
  function mintWithCreatorPaymentAddressAndApproveMarket(
    string memory tokenIPFSPath,
    address payable tokenCreatorPaymentAddress
  ) public returns (uint256 tokenId) {
    tokenId = mintWithCreatorPaymentAddress(tokenIPFSPath, tokenCreatorPaymentAddress);
    setApprovalForAll(getNFTMarket(), true);
  }
  function mintWithCreatorPaymentFactory(
    string memory tokenIPFSPath,
    address paymentAddressFactory,
    bytes memory paymentAddressCallData
  ) public returns (uint256 tokenId) {
    address payable tokenCreatorPaymentAddress = _proxyCallAndReturnContractAddress(
      paymentAddressFactory,
      paymentAddressCallData
    );
    tokenId = mintWithCreatorPaymentAddress(tokenIPFSPath, tokenCreatorPaymentAddress);
  }
  function mintWithCreatorPaymentFactoryAndApproveMarket(
    string memory tokenIPFSPath,
    address paymentAddressFactory,
    bytes memory paymentAddressCallData
  ) public returns (uint256 tokenId) {
    tokenId = mintWithCreatorPaymentFactory(tokenIPFSPath, paymentAddressFactory, paymentAddressCallData);
    setApprovalForAll(getNFTMarket(), true);
  }
  function _burn(uint256 tokenId) internal virtual override(ERC721Upgradeable, NFT721Creator, NFT721Metadata) {
    super._burn(tokenId);
  }
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721Upgradeable, NFT721Creator, NFT721Market)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
  uint256[1000] private ______gap;
}