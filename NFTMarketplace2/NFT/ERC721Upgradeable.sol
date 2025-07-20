// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./IERC721Upgradeable.sol";
import "./IERC721MetadataUpgradeable.sol";
import "./IERC721EnumerableUpgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "./SafeMathUpgradeable.sol";
import "./AddressUpgradeable.sol";
import "./ContextUpgradeable.sol";
import "./EnumerableSetUpgradeable.sol";
import "./EnumerableMapUpgradeable.sol";
import "./StringsUpgradeable.sol";
import "./Initializable.sol";
import "./ERC165.sol";
import "./ERC165UpgradeableGap.sol";
contract ERC721Upgradeable is
  Initializable,
  ContextUpgradeable,
  ERC165UpgradeableGap,
  ERC165,
  IERC721Upgradeable,
  IERC721MetadataUpgradeable,
  IERC721EnumerableUpgradeable
{
  using SafeMathUpgradeable for uint256;
  using AddressUpgradeable for address;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using EnumerableMapUpgradeable for EnumerableMapUpgradeable.UintToAddressMap;
  using StringsUpgradeable for uint256;

  // Mapping from holder address to their (enumerable) set of owned tokens
  mapping(address => EnumerableSetUpgradeable.UintSet) private _holderTokens;

  // Enumerable mapping from token ids to their owners
  EnumerableMapUpgradeable.UintToAddressMap private _tokenOwners;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  // Token name
  string private ____gap_was_name;

  // Token symbol
  string private ____gap_was_symbol;

  // Optional mapping for token URIs
  mapping(uint256 => string) internal _tokenURIs;

  // Base URI
  string private _baseURI;

  /**
   * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
   */
  function __ERC721_init() internal initializer {
    __Context_init_unchained();
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    if (
      interfaceId == type(IERC721Upgradeable).interfaceId ||
      interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
      interfaceId == type(IERC721EnumerableUpgradeable).interfaceId
    ) {
      return true;
    }
    return super.supportsInterface(interfaceId);
  }
  function balanceOf(address owner) public view override returns (uint256) {
    require(owner != address(0), "ERC721: balance query for the zero address");

    return _holderTokens[owner].length();
  }
  function ownerOf(uint256 tokenId) public view override returns (address) {
    return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
  }
  function name() public pure override returns (string memory) {
    return "Smart";
  }
  function symbol() public pure override returns (string memory) {
    return "SSS";
  }
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    string memory _tokenURI = _tokenURIs[tokenId];
    // If there is no base URI, return the token URI.
    if (bytes(_baseURI).length == 0) {
      return _tokenURI;
    }
    // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
    if (bytes(_tokenURI).length > 0) {
      return string(abi.encodePacked(_baseURI, _tokenURI));
    }
    // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
    return string(abi.encodePacked(_baseURI, tokenId.toString()));
  }
  function baseURI() public view returns (string memory) {
    return _baseURI;
  }
  function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
    return _holderTokens[owner].at(index);
  }
  function totalSupply() public view override returns (uint256) {
    // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
    return _tokenOwners.length();
  }
  function tokenByIndex(uint256 index) public view override returns (uint256) {
    (uint256 tokenId, ) = _tokenOwners.at(index);
    return tokenId;
  }
  function approve(address to, uint256 tokenId) public virtual override {
    address owner = ownerOf(tokenId);
    require(to != owner, "ERC721: approval to current owner");
    require(
      _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
      "ERC721: approve caller is not owner nor approved for all"
    );
    _approve(to, tokenId);
  }
  function getApproved(uint256 tokenId) public view override returns (address) {
    require(_exists(tokenId), "ERC721: approved query for nonexistent token");
    return _tokenApprovals[tokenId];
  }
  function setApprovalForAll(address operator, bool approved) public virtual override {
    require(operator != _msgSender(), "ERC721: approve to caller");
    _operatorApprovals[_msgSender()][operator] = approved;
    emit ApprovalForAll(_msgSender(), operator, approved);
  }
  function isApprovedForAll(address owner, address operator) public view override returns (bool) {
    return _operatorApprovals[owner][operator];
  }
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    //solhint-disable-next-line max-line-length
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    _transfer(from, to, tokenId);
  }
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) public virtual override {
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    _safeTransfer(from, to, tokenId, _data);
  }
  function _safeTransfer(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) internal virtual {
    _transfer(from, to, tokenId);
    require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
  }
  function _exists(uint256 tokenId) internal view returns (bool) {
    return _tokenOwners.contains(tokenId);
  }
  function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
    require(_exists(tokenId), "ERC721: operator query for nonexistent token");
    address owner = ownerOf(tokenId);
    return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
  }
  function _safeMint(address to, uint256 tokenId) internal virtual {
    _safeMint(to, tokenId, "");
  }
  function _safeMint(
    address to,
    uint256 tokenId,
    bytes memory _data
  ) internal virtual {
    _mint(to, tokenId);
    require(
      _checkOnERC721Received(address(0), to, tokenId, _data),
      "ERC721: transfer to non ERC721Receiver implementer"
    );
  }
  function _mint(address to, uint256 tokenId) internal virtual {
    require(to != address(0), "ERC721: mint to the zero address");
    require(!_exists(tokenId), "ERC721: token already minted");
    _beforeTokenTransfer(address(0), to, tokenId);
    _holderTokens[to].add(tokenId);
    _tokenOwners.set(tokenId, to);
    emit Transfer(address(0), to, tokenId);
  }
  function _burn(uint256 tokenId) internal virtual {
    address owner = ownerOf(tokenId);
    _beforeTokenTransfer(owner, address(0), tokenId);
    // Clear approvals
    _approve(address(0), tokenId);
    // Clear metadata (if any)
    if (bytes(_tokenURIs[tokenId]).length != 0) {
      delete _tokenURIs[tokenId];
    }
    _holderTokens[owner].remove(tokenId);
    _tokenOwners.remove(tokenId);
    emit Transfer(owner, address(0), tokenId);
  }
  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {
    require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
    require(to != address(0), "ERC721: transfer to the zero address");
    _beforeTokenTransfer(from, to, tokenId);
    // Clear approvals from the previous owner
    _approve(address(0), tokenId);
    _holderTokens[from].remove(tokenId);
    _holderTokens[to].add(tokenId);
    _tokenOwners.set(tokenId, to);
    emit Transfer(from, to, tokenId);
  }
  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
    require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
  }
  function _setBaseURI(string memory baseURI_) internal virtual {
    _baseURI = baseURI_;
  }
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) private returns (bool) {
    if (!to.isContract()) {
      return true;
    }
    bytes memory returndata = to.functionCall(
      abi.encodeWithSelector(
        IERC721ReceiverUpgradeable(to).onERC721Received.selector,
        _msgSender(),
        from,
        tokenId,
        _data
      ),
      "ERC721: transfer to non ERC721Receiver implementer"
    );
    bytes4 retval = abi.decode(returndata, (bytes4));
    return (retval == type(IERC721ReceiverUpgradeable).interfaceId);
  }
  function _approve(address to, uint256 tokenId) private {
    _tokenApprovals[tokenId] = to;
    emit Approval(ownerOf(tokenId), to, tokenId);
  }
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {}
  uint256[41] private __gap;
}