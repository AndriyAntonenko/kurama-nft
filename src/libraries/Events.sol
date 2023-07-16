// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DataTypes } from "./DataTypes.sol";

library Events {
  /*//////////////////////////////////////////////////////////////
                                 EVENTS
  //////////////////////////////////////////////////////////////*/
  event KuramaReadyToPurchase(uint256 indexed tokenId, DataTypes.KuramaPhoto photo, uint256 price);
  event KuramaPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);
  event KuramaPriceChanged(uint256 indexed tokenId, uint256 newPrice);
}
