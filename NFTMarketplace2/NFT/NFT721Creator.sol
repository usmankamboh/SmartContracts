// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./Initializable.sol";
import "./ERC721Upgradeable.sol";
import "./AccountMigration.sol";
import "./BytesLibrary.sol";
import "./NFT721ProxyCall.sol";
import "./ITokenCreator.sol";
import "./ITokenCreatorPaymentAddress.sol";
abstract contract NFT721Creator is
  Initializable,
  AccountMigration,
  ERC721Upgradeable,
  ITokenCreator,
  ITokenCreatorPaymentAddress,
  NFT721ProxyCall
{
  using BytesLibrary for bytes;
  mapping(uint256 => address payable) private tokenIdToCreator;
  mapping(uint256 => address payable) private tokenIdToCreatorPaymentAddress;
  event TokenCreatorUpdated(address indexed fromCreator, address indexed toCreator, uint256 indexed tokenId);
  event TokenCreatorPaymentAddressSet(
    address indexed fromPaymentAddress,
    address indexed toPaymentAddress,
    uint256 indexed tokenId
  );
  event NFTCreatorMigrated(uint256 indexed tokenId, address indexed originalAddress, address indexed newAddress);
  event NFTOwnerMigrated(uint256 indexed tokenId, address indexed originalAddress, address indexed newAddress);
  event PaymentAddressMigrated(
    uint256 indexed tokenId,
    address indexed originalAddress,
    address indexed newAddress,
    address originalPaymentAddress,
    address newPaymentAddress
  );
  modifier onlyCreatorAndOwner(uint256 tokenId) {
    require(tokenIdToCreator[tokenId] == msg.sender, "NFT721Creator: Caller is not creator");
    require(ownerOf(tokenId) == msg.sender, "NFT721Creator: Caller does not own the NFT");
    _;
  }
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    if (
      interfaceId == type(ITokenCreator).interfaceId || interfaceId == type(ITokenCreatorPaymentAddress).interfaceId
    ) {
      return true;
    }
    return super.supportsInterface(interfaceId);
  }
  function tokenCreator(uint256 tokenId) public view override returns (address payable) {
    return tokenIdToCreator[tokenId];
  }
  function getTokenCreatorPaymentAddress(uint256 tokenId)
    public
    view
    override
    returns (address payable tokenCreatorPaymentAddress)
  {
    tokenCreatorPaymentAddress = tokenIdToCreatorPaymentAddress[tokenId];
    if (tokenCreatorPaymentAddress == address(0)) {
      tokenCreatorPaymentAddress = tokenIdToCreator[tokenId];
    }
  }
  function _updateTokenCreator(uint256 tokenId, address payable creator) internal {
    emit TokenCreatorUpdated(tokenIdToCreator[tokenId], creator, tokenId);
    tokenIdToCreator[tokenId] = creator;
  }
  function _setTokenCreatorPaymentAddress(uint256 tokenId, address payable tokenCreatorPaymentAddress) internal {
    emit TokenCreatorPaymentAddressSet(tokenIdToCreatorPaymentAddress[tokenId], tokenCreatorPaymentAddress, tokenId);
    tokenIdToCreatorPaymentAddress[tokenId] = tokenCreatorPaymentAddress;
  }
  function burn(uint256 tokenId) public onlyCreatorAndOwner(tokenId) {
    _burn(tokenId);
  }
  function adminAccountMigration(
    uint256[] calldata createdTokenIds,
    uint256[] calldata ownedTokenIds,
    address originalAddress,
    address payable newAddress,
    bytes calldata signature
  ) public onlyAuthorizedAccountMigration(originalAddress, newAddress, signature) {
    for (uint256 i = 0; i < ownedTokenIds.length; i++) {
      uint256 tokenId = ownedTokenIds[i];
      // Check that the token exists and still owned by the originalAddress
      // so that frontrunning a burn or transfer will not cause the entire tx to revert
      if (_exists(tokenId) && ownerOf(tokenId) == originalAddress) {
        _transfer(originalAddress, newAddress, tokenId);
        emit NFTOwnerMigrated(tokenId, originalAddress, newAddress);
      }
    }
    for (uint256 i = 0; i < createdTokenIds.length; i++) {
      uint256 tokenId = createdTokenIds[i];
      // The creator would be 0 if the token was burned before this call
      if (tokenIdToCreator[tokenId] != address(0)) {
        require(
          tokenIdToCreator[tokenId] == originalAddress,
          "NFT721Creator: Token was not created by the given address"
        );
        _updateTokenCreator(tokenId, newAddress);
        emit NFTCreatorMigrated(tokenId, originalAddress, newAddress);
      }
    }
  }
  function adminAccountMigrationForPaymentAddresses(
    uint256[] calldata paymentAddressTokenIds,
    address paymentAddressFactory,
    bytes memory paymentAddressCallData,
    uint256 addressLocationInCallData,
    address originalAddress,
    address payable newAddress,
    bytes calldata signature
  ) public onlyAuthorizedAccountMigration(originalAddress, newAddress, signature) {
    _adminAccountRecoveryForPaymentAddresses(
      paymentAddressTokenIds,
      paymentAddressFactory,
      paymentAddressCallData,
      addressLocationInCallData,
      originalAddress,
      newAddress
    );
  }
  function _adminAccountRecoveryForPaymentAddresses(
    uint256[] calldata paymentAddressTokenIds,
    address paymentAddressFactory,
    bytes memory paymentAddressCallData,
    uint256 addressLocationInCallData,
    address originalAddress,
    address payable newAddress
  ) private {
    // Call the factory and get the originalPaymentAddress
    address payable originalPaymentAddress = _proxyCallAndReturnContractAddress(
      paymentAddressFactory,
      paymentAddressCallData
    );
    // Confirm the original address and swap with the new address
    paymentAddressCallData.replaceAtIf(addressLocationInCallData, originalAddress, newAddress);
    // Call the factory and get the newPaymentAddress
    address payable newPaymentAddress = _proxyCallAndReturnContractAddress(
      paymentAddressFactory,
      paymentAddressCallData
    );
    // For each token, confirm the expected payment address and then update to the new one
    for (uint256 i = 0; i < paymentAddressTokenIds.length; i++) {
      uint256 tokenId = paymentAddressTokenIds[i];
      require(
        tokenIdToCreatorPaymentAddress[tokenId] == originalPaymentAddress,
        "NFT721Creator: Payment address is not the expected value"
      );
      _setTokenCreatorPaymentAddress(tokenId, newPaymentAddress);
      emit PaymentAddressMigrated(tokenId, originalAddress, newAddress, originalPaymentAddress, newPaymentAddress);
    }
  }
  function _burn(uint256 tokenId) internal virtual override {
    delete tokenIdToCreator[tokenId];
    super._burn(tokenId);
  }
  uint256[999] private ______gap;
}