// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library Errors {
  error Kurama__TokenNotAllowedForSale();
  error Kurama__NotEnoughMoney();
  error Kurama__ZeroAddress();
  error Kurama__CannotTransferToTreasury();
  error Kurama__SaleOnPause();
  error Kurama__NoTokensToSale();
}
