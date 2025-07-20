// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "./AddressUpgradeable.sol";
import "./ECDSA.sol";
import "./NFTMarketFees.sol";
import "./IERC721.sol";
error NFTMarketPrivateSale_Can_Be_Offered_For_24Hrs_Max();
error NFTMarketPrivateSale_Signature_Canceled_Or_Already_Claimed();
error NFTMarketPrivateSale_Proxy_Address_Is_Not_A_Contract();
error NFTMarketPrivateSale_Sale_Expired();
error NFTMarketPrivateSale_Signature_Verification_Failed();
error NFTMarketPrivateSale_Too_Much_Value_Provided();
abstract contract NFTMarketPrivateSale is NFTMarketFees {
  using AddressUpgradeable for address;
  using ECDSA for bytes32;
  // This value was replaced with an immutable version.
  bytes32 private __gap_was_DOMAIN_SEPARATOR;
  mapping(address => mapping(uint256 => mapping(address => mapping(address => mapping(uint256 => mapping(uint256 => bool))))))
  private privateSaleInvalidated;
  bytes32 private immutable DOMAIN_SEPARATOR;
  // The hash of the private sale method signature used for EIP-712 signatures.
  bytes32 private constant BUY_FROM_PRIVATE_SALE_TYPEHASH =
    keccak256("BuyFromPrivateSale(address nftContract,uint256 tokenId,address buyer,uint256 price,uint256 deadline)");
  // The name used in the EIP-712 domain.
  // If multiple classes use EIP-712 signatures in the future this can move to the shared constants file.
  string private constant NAME = "FNDNFTMarket";
  event PrivateSaleFinalized(
    address indexed nftContract,
    uint256 indexed tokenId,
    address indexed seller,
    address buyer,
    uint256 protocolFee,
    uint256 creatorFee,
    uint256 sellerRev,
    uint256 deadline
  );
  constructor(address marketProxyAddress) {
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(NAME)),
        // Incrementing the version can be used to invalidate previously signed messages.
        keccak256(bytes("1")),
        block.chainid,
        marketProxyAddress
      )
    );
  }
  function buyFromPrivateSale(
    address nftContract,
    uint256 tokenId,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external payable {
    buyFromPrivateSaleFor(nftContract, tokenId, msg.value, deadline, v, r, s);
  }
  function buyFromPrivateSaleFor(
    address nftContract,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public payable nonReentrant {
    // now + 2 days cannot overflow
    unchecked {
      if (deadline < block.timestamp) {
        // The signed message from the seller has expired.
        revert NFTMarketPrivateSale_Sale_Expired();
      } else if (deadline > block.timestamp + 2 days) {
        // Private sales typically expire in 24 hours, but 2 days is used here in order to ensure
        // that transactions do not fail due to a minor timezone error or similar during signing.
        // This prevents malicious actors from requesting signatures that never expire.
        revert NFTMarketPrivateSale_Can_Be_Offered_For_24Hrs_Max();
      }
    }
    // Cancel the buyer's offer if there is one in order to free up their SETH balance
    // even if they don't need the SETH for this specific purchase.
    _cancelSendersOffer(address(nftContract), tokenId);
    if (amount > msg.value) {
      // Withdraw additional ETH required from their available SETH balance.
      unchecked {
        // The if above ensures delta will not underflow
        seth.marketWithdrawFrom(msg.sender, amount - msg.value);
      }
    } else if (amount < msg.value) {
      // The terms of the sale cannot change, so if too much ETH is sent then something went wrong.
      revert NFTMarketPrivateSale_Too_Much_Value_Provided();
    }
    // The seller must have the NFT in their wallet when this function is called,
    // otherwise the signature verification below will fail.
    address payable seller = payable(IERC721(nftContract).ownerOf(tokenId));
    // Ensure that the offer can only be accepted once.
    if (privateSaleInvalidated[nftContract][tokenId][msg.sender][seller][amount][deadline]) {
      revert NFTMarketPrivateSale_Signature_Canceled_Or_Already_Claimed();
    }
    privateSaleInvalidated[nftContract][tokenId][msg.sender][seller][amount][deadline] = true;
    // Scoping this block to avoid a stack too deep error
    {
      bytes32 digest = keccak256(
        abi.encodePacked(
          "\x19\x01",
          DOMAIN_SEPARATOR,
          keccak256(abi.encode(BUY_FROM_PRIVATE_SALE_TYPEHASH, nftContract, tokenId, msg.sender, amount, deadline))
        )
      );
      // Revert if the signature is invalid, the terms are not as expected, or if the seller transferred the NFT.
      if (digest.recover(v, r, s) != seller) {
        revert NFTMarketPrivateSale_Signature_Verification_Failed();
      }
    }
    // This should revert if the seller has not given the market contract approval.
    IERC721(nftContract).transferFrom(seller, msg.sender, tokenId);
    // Distribute revenue for this sale.
    (uint256 protocolFee, uint256 creatorFee, uint256 sellerRev) = _distributeFunds(
      nftContract,
      tokenId,
      seller,
      amount,
      payable(address(0))
    );
    emit PrivateSaleFinalized(nftContract, tokenId, seller, msg.sender, protocolFee, creatorFee, sellerRev, deadline);
  }
  uint256[999] private __gap;
}