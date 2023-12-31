// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { ERC721Pausable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Errors } from "./libraries/Errors.sol";
import { DataTypes } from "./libraries/DataTypes.sol";
import { Events } from "./libraries/Events.sol";

contract Kurama is Ownable, ERC721Pausable, IERC721Receiver {
  /*//////////////////////////////////////////////////////////////
                                 STATE
  //////////////////////////////////////////////////////////////*/
  address private s_treasury; // The address that will receive the money from the sales
  uint256 private s_tokenCounter; // The counter of the tokens minted. It also used to generate the ids
  // The mapping from the token id to the KuramaPhoto struct
  mapping(uint256 => DataTypes.KuramaPhoto) private s_tokenIdToPhoto;
  mapping(uint256 => uint256) s_prices; // The mapping from the token id to the price

  /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
  //////////////////////////////////////////////////////////////*/
  modifier saleIsOpen() {
    if (balanceOf(address(this)) == 0) {
      revert Errors.Kurama__NoTokensToSale();
    }
    if (paused()) {
      revert Errors.Kurama__SaleOnPause();
    }
    _;
  }

  constructor(address _owner, address _treasury) ERC721("Kurama", "KUR") {
    if (_treasury == address(0) && _owner == address(0)) {
      revert Errors.Kurama__ZeroAddress();
    }

    s_tokenCounter = 0;
    s_treasury = _treasury;

    if (_owner != msg.sender) {
      transferOwnership(_owner);
    }
  }

  /*//////////////////////////////////////////////////////////////
                                 LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Any minted photo will be sent to the contract address. After this user can buy it using purchase() function
   * @param _photo The photo to mint
   * @param _initialPrice The initial price of the photo in wei
   */
  function mint(DataTypes.KuramaPhoto memory _photo, uint256 _initialPrice) public onlyOwner returns (uint256) {
    uint256 newTokenId = s_tokenCounter;
    s_tokenIdToPhoto[newTokenId] = _photo;
    s_prices[newTokenId] = _initialPrice;
    _safeMint(address(this), newTokenId);
    s_tokenCounter = s_tokenCounter + 1;
    emit Events.KuramaReadyToPurchase(newTokenId, _photo, _initialPrice);
    return newTokenId;
  }

  /**
   * This function pauses the contract. It can be used by the owner
   */
  function pause() public onlyOwner {
    _pause();
  }

  /**
   * This function changes the price of the token
   * @param _tokenId The id of the token to change the price
   * @param _newPrice The new price of the token
   */
  function changePrice(uint256 _tokenId, uint256 _newPrice) public onlyOwner {
    s_prices[_tokenId] = _newPrice;
    emit Events.KuramaPriceChanged(_tokenId, _newPrice);
  }

  /**
   * This function will transfer the token to the buyer and send the money to the treasury
   * @param _tokenId The id of the token to change the price
   */
  function purchase(uint256 _tokenId) public payable saleIsOpen {
    address owner = ownerOf(_tokenId);
    if (owner != address(this)) {
      revert Errors.Kurama__TokenNotAllowedForSale();
    }
    if (msg.value < s_prices[_tokenId]) {
      revert Errors.Kurama__NotEnoughMoney();
    }

    s_prices[_tokenId] = 0;
    _transfer(owner, msg.sender, _tokenId);
    emit Events.KuramaPurchased(_tokenId, msg.sender, msg.value);
  }

  function withdraw() public onlyOwner {
    (bool success,) = payable(s_treasury).call{value: address(this).balance}("");
    if (!success) {
      revert Errors.Kurama__CannotTransferToTreasury();
    }
  }

  /*//////////////////////////////////////////////////////////////
                                 VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * This function returns the price of the token in wei
   * @param _tokenId The id of the token to get the price
   */
  function priceOf(uint256 _tokenId) public view returns (uint256) {
    return s_prices[_tokenId];
  }

  /**
   * This function returns the treasury address. It usefull for people who want to check the treasury address before
   * buying
   */
  function getTreasury() public view returns (address) {
    return s_treasury;
  }

  /**
   * Get the photo of the token and metadata
   * @param _tokenId The id of the token to get the photo
   */
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    DataTypes.KuramaPhoto memory photo = s_tokenIdToPhoto[_tokenId];
    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "',
            photo.name,
            '", "id": "',
            _tokenId,
            '", "description": "',
            photo.description,
            '", "image": "',
            photo.image,
            '"}'
          )
        )
      )
    );
    return string(abi.encodePacked("data:application/json;base64,", json));
  }

  function getTokensAmountToPurchase() public view returns (uint256) {
    return balanceOf(address(this));
  }

  function getPhotosToSale() public view returns (uint256[] memory, DataTypes.KuramaPhoto[] memory, uint256[] memory) {
    uint256 tokensAmount = getTokensAmountToPurchase();
    uint256[] memory ids = new uint256[](tokensAmount);
    DataTypes.KuramaPhoto[] memory photos = new DataTypes.KuramaPhoto[](tokensAmount);
    uint256[] memory prices = new uint256[](tokensAmount);

    uint256 photosAdded = 0;
    for (uint256 tokenId = 0; tokenId < s_tokenCounter; tokenId++) {
      if (ownerOf(tokenId) == address(this)) {
        ids[photosAdded] = tokenId;
        photos[photosAdded] = s_tokenIdToPhoto[tokenId];
        prices[photosAdded] = s_prices[tokenId];
        photosAdded++;
      }
    }

    return (ids, photos, prices);
  }

  function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
    return this.onERC721Received.selector;
  }
}
