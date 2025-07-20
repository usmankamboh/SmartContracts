// SPDX-License-Identifier: MIT 
pragma solidity 0.8.15;
import "./AddressUpgradeable.sol";
import "./IRoyaltyRegistry.sol";
import "./IGetFees.sol";
import "./IGetRoyalties.sol";
import "./IOwnable.sol";
import "./IRoyaltyInfo.sol";
import "./ITokenCreator.sol";
import "./SendValueWithFallbackWithdraw.sol";
import "./TreasuryNode.sol";
import "./ERC165Checker.sol";
error NFTMarketFees_Address_Does_Not_Support_IRoyaltyRegistry();
abstract contract NFTMarketFees is TreasuryNode, SendValueWithFallbackWithdraw {
  using AddressUpgradeable for address;
  using OZERC165Checker for address;
  uint256[4] private __gap_was_fees;
  // The royalties sent to creator recipients on secondary sales.
  uint256 private constant CREATOR_ROYALTY_DENOMINATOR = BASIS_POINTS / 1000; // 10%
  // The fee collected by Smart for sales facilitated by this market contract.
  uint256 private constant PROTOCOL_FEE_DENOMINATOR = BASIS_POINTS / 500; // 5%
  // The fee collected by the buy referrer for sales facilitated by this market contract.
  // This fee is calculated from the total protocol fee.
  // 20% of protocol fee == 1% of total sale.
  uint256 private constant BUY_REFERRER_PROTOCOL_FEE_DENOMINATOR = 5;
  IRoyaltyRegistry private immutable royaltyRegistry;
  event BuyReferralPaid(
    address indexed nftContract,
    uint256 indexed tokenId,
    address buyReferrer,
    uint256 buyReferrerProtocolFee,
    uint256 buyReferrerSellerFee
  );
  constructor(address _royaltyRegistry) {
    royaltyRegistry = IRoyaltyRegistry(_royaltyRegistry);
  }
  function _distributeFunds(
    address nftContract,
    uint256 tokenId,
    address payable seller,
    uint256 price,
    address payable buyReferrer
  )
    internal
    returns (
      uint256 protocolFee,
      uint256 creatorFee,
      uint256 sellerRev
    )
  {
    address payable[] memory creatorRecipients;
    uint256[] memory creatorShares;
    address payable creator;
    address payable sellerRevTo;
    (protocolFee, creator, creatorRecipients, creatorShares, creatorFee, sellerRevTo, sellerRev) = _getFees(
      nftContract,
      tokenId,
      seller,
      price
    );
    if (creatorFee != 0) {
      uint256 creatorRecipientsLength = creatorRecipients.length;
      if (creatorRecipientsLength > 1) {
        if (creatorRecipientsLength > MAX_ROYALTY_RECIPIENTS) {
          creatorRecipientsLength = MAX_ROYALTY_RECIPIENTS;
        }
        // Determine the total shares defined so it can be leveraged to distribute below
        uint256 totalShares;
        unchecked {
          // The array length cannot overflow 256 bits.
          for (uint256 i = 0; i < creatorRecipientsLength; ++i) {
            if (creatorShares[i] > BASIS_POINTS) {
              // If the numbers are >100% we ignore the fee recipients and pay just the first instead
              creatorRecipientsLength = 1;
              break;
            }
            // The check above ensures totalShares wont overflow.
            totalShares += creatorShares[i];
          }
        }
        if (totalShares == 0) {
          creatorRecipientsLength = 1;
        }
        // Send payouts to each additional recipient if more than 1 was defined
        uint256 totalRoyaltiesDistributed;
        for (uint256 i = 1; i < creatorRecipientsLength; ) {
          uint256 royalty = (creatorFee * creatorShares[i]) / totalShares;
          totalRoyaltiesDistributed += royalty;
          _sendValueWithFallbackWithdraw(creatorRecipients[i], royalty, SEND_VALUE_GAS_LIMIT_MULTIPLE_RECIPIENTS);
          unchecked {
            ++i;
          }
        }
        // Send the remainder to the 1st creator, rounding in their favor
        _sendValueWithFallbackWithdraw(
          creatorRecipients[0],
          creatorFee - totalRoyaltiesDistributed,
          SEND_VALUE_GAS_LIMIT_MULTIPLE_RECIPIENTS
        );
      } else {
        _sendValueWithFallbackWithdraw(creatorRecipients[0], creatorFee, SEND_VALUE_GAS_LIMIT_MULTIPLE_RECIPIENTS);
      }
    }
    _sendValueWithFallbackWithdraw(sellerRevTo, sellerRev, SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT);

    _distributeProtocolFees(nftContract, tokenId, seller, creator, protocolFee, buyReferrer);
  }
  function _distributeProtocolFees(
    address nftContract,
    uint256 tokenId,
    address payable seller,
    address payable creator,
    uint256 protocolFee,
    address payable buyReferrer
  ) private {
    uint256 buyReferrerProtocolFee;
    if (buyReferrer != address(0) && buyReferrer != msg.sender && buyReferrer != seller && buyReferrer != creator) {
      // SafeMath is not required since the referrer fee is less than the total protocol fee calculated above.
      unchecked {
        buyReferrerProtocolFee = protocolFee / BUY_REFERRER_PROTOCOL_FEE_DENOMINATOR;
        if (_trySendValue(buyReferrer, buyReferrerProtocolFee, SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT)) {
          emit BuyReferralPaid(nftContract, tokenId, buyReferrer, buyReferrerProtocolFee, 0);
        } else {
          // If we are unable to pay the referrer than the money is returned to the original protocolFee.
          buyReferrerProtocolFee = 0;
        }
      }
    }
    // Calculate the Smart fee using the total protocol fee minus any referrals paid.
    unchecked {
      uint256 ProtocolFee = protocolFee - buyReferrerProtocolFee;
      _sendValueWithFallbackWithdraw(
        getTreasury(),
        ProtocolFee,
        SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT
      );
    }
  }
  function getFeesAndRecipients(
    address nftContract,
    uint256 tokenId,
    uint256 price
  )
    external
    view
    returns (
      uint256 protocolFee,
      uint256 creatorRev,
      address payable[] memory creatorRecipients,
      uint256[] memory creatorShares,
      uint256 sellerRev,
      address payable owner
    )
  {
    address payable seller = _getSellerFor(nftContract, tokenId);
    (protocolFee, , creatorRecipients, creatorShares, creatorRev, owner, sellerRev) = _getFees(
      nftContract,
      tokenId,
      seller,
      price
    );
  }
  function getCreatorAndImmutableRoyalties(address nftContract, uint256 tokenId)
    external
    view
    returns (
      address payable creator,
      address payable[] memory recipients,
      uint256[] memory splitPerRecipientInBasisPoints
    )
  {
    // lookup for tokenCreator
    try ITokenCreator(nftContract).tokenCreator{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
      address payable _creator
    ) {
      creator = _creator;
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }
    // 1st priority: ERC-2981
    if (nftContract.supportsERC165Interface(type(IRoyaltyInfo).interfaceId)) {
      try IRoyaltyInfo(nftContract).royaltyInfo{ gas: READ_ONLY_GAS_LIMIT }(tokenId, BASIS_POINTS) returns (
        address receiver,
        uint256 royaltyAmount
      ) {
        // Manifold contracts return (address(this), 0) when royalties are not defined
        // - so ignore results when the amount is 0
        if (royaltyAmount > 0) {
          recipients = new address payable[](1);
          recipients[0] = payable(receiver);
          // splitPerRecipientInBasisPoints is not relevant when only 1 recipient is defined
          return (creator, recipients, splitPerRecipientInBasisPoints);
        }
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }
    // 2nd priority: getRoyalties
    if (nftContract.supportsERC165Interface(type(IGetRoyalties).interfaceId)) {
      try IGetRoyalties(nftContract).getRoyalties{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
        address payable[] memory _recipients,
        uint256[] memory recipientBasisPoints
      ) {
        uint256 recipientLen = _recipients.length;
        if (recipientLen != 0 && recipientLen == recipientBasisPoints.length) {
          return (creator, _recipients, recipientBasisPoints);
        }
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }
  }
  function getMutableRoyalties(address nftContract, uint256 tokenId)
    external
    view
    returns (address payable[] memory recipients, uint256[] memory splitPerRecipientInBasisPoints)
  {
    try royaltyRegistry.getRoyaltyLookupAddress{ gas: READ_ONLY_GAS_LIMIT }(nftContract) returns (
      address overrideContract
    ) {
      if (overrideContract != nftContract) {
        nftContract = overrideContract;
        // The functions above are repeated here if an override is set.
        // 3rd priority: ERC-2981 override
        if (nftContract.supportsERC165Interface(type(IRoyaltyInfo).interfaceId)) {
          try IRoyaltyInfo(nftContract).royaltyInfo{ gas: READ_ONLY_GAS_LIMIT }(tokenId, BASIS_POINTS) returns (
            address receiver,
            uint256 /* royaltyAmount */
          ) {
            recipients = new address payable[](1);
            recipients[0] = payable(receiver);
            // splitPerRecipientInBasisPoints is not relevant when only 1 recipient is defined
            return (recipients, splitPerRecipientInBasisPoints);
          } catch // solhint-disable-next-line no-empty-blocks
          {
            // Fall through
          }
        }
        // 4th priority: getRoyalties override
        if (recipients.length == 0 && nftContract.supportsERC165Interface(type(IGetRoyalties).interfaceId)) {
          try IGetRoyalties(nftContract).getRoyalties{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
            address payable[] memory _recipients,
            uint256[] memory recipientBasisPoints
          ) {
            uint256 recipientLen = _recipients.length;
            if (recipientLen != 0 && recipientLen == recipientBasisPoints.length) {
              return (_recipients, recipientBasisPoints);
            }
          } catch // solhint-disable-next-line no-empty-blocks
          {
            // Fall through
          }
        }
      }
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Ignore out of gas errors and continue using the nftContract address
    }
    // 5th priority: getFee* from contract or override
    if (nftContract.supportsERC165Interface(type(IGetFees).interfaceId)) {
      try IGetFees(nftContract).getFeeRecipients{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
        address payable[] memory _recipients
      ) {
        uint256 recipientLen = _recipients.length;
        if (recipientLen != 0) {
          try IGetFees(nftContract).getFeeBps{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
            uint256[] memory recipientBasisPoints
          ) {
            if (recipientLen == recipientBasisPoints.length) {
              return (_recipients, recipientBasisPoints);
            }
          } catch // solhint-disable-next-line no-empty-blocks
          {
            // Fall through
          }
        }
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }
    // 6th priority: tokenCreator w/ or w/o requiring 165 from contract or override
    try ITokenCreator(nftContract).tokenCreator{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
      address payable _creator
    ) {
      // Only pay the tokenCreator if there wasn't another royalty defined
      recipients = new address payable[](1);
      recipients[0] = _creator;
      // splitPerRecipientInBasisPoints is not relevant when only 1 recipient is defined
      return (recipients, splitPerRecipientInBasisPoints);
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }
    // 7th priority: owner from contract or override
    try IOwnable(nftContract).owner{ gas: READ_ONLY_GAS_LIMIT }() returns (address owner) {
      // Only pay the owner if there wasn't another royalty defined
      recipients = new address payable[](1);
      recipients[0] = payable(owner);
      // splitPerRecipientInBasisPoints is not relevant when only 1 recipient is defined
      return (recipients, splitPerRecipientInBasisPoints);
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }
    // If no valid payment address or creator is found, return 0 recipients
  }
  function getRoyaltyRegistry() public view returns (address registry) {
    return address(royaltyRegistry);
  }
  function _getFees(
    address nftContract,
    uint256 tokenId,
    address payable seller,
    uint256 price
  )
    private
    view
    returns (
      uint256 protocolFee,
      address payable creator,
      address payable[] memory creatorRecipients,
      uint256[] memory creatorShares,
      uint256 creatorRev,
      address payable sellerRevTo,
      uint256 sellerRev
    )
  {
    try this.getCreatorAndImmutableRoyalties(nftContract, tokenId) returns (
      address payable _creator,
      address payable[] memory _recipients,
      uint256[] memory _splitPerRecipientInBasisPoints
    ) {
      (creator, creatorRecipients, creatorShares) = (_creator, _recipients, _splitPerRecipientInBasisPoints);
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }
    if (creatorRecipients.length == 0) {
      // Check mutable royalties only if we didn't find results from the immutable API
      try this.getMutableRoyalties(nftContract, tokenId) returns (
        address payable[] memory _recipients,
        uint256[] memory _splitPerRecipientInBasisPoints
      ) {
        (creatorRecipients, creatorShares) = (_recipients, _splitPerRecipientInBasisPoints);
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }
    // Calculate the protocol fee
    unchecked {
      // SafeMath is not required when dividing by a non-zero constant.
      protocolFee = price / PROTOCOL_FEE_DENOMINATOR;
    }
    if (creatorRecipients.length != 0) {
      if (seller == creator || (creatorRecipients.length == 1 && seller == creatorRecipients[0])) {
        // When sold by the creator, all revenue is split if applicable.
        unchecked {
          // protocolFee is always < price.
          creatorRev = price - protocolFee;
        }
      } else {
        // Rounding favors the owner first, then creator, and smart last.
        unchecked {
          // SafeMath is not required when dividing by a non-zero constant.
          creatorRev = price / CREATOR_ROYALTY_DENOMINATOR;
        }
        sellerRevTo = seller;
        sellerRev = price - protocolFee - creatorRev;
      }
    } else {
      // No royalty recipients found.
      sellerRevTo = seller;
      unchecked {
        // protocolFee is always < price.
        sellerRev = price - protocolFee;
      }
    }
  }
  uint256[1000] private __gap;
}