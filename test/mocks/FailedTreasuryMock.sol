// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FailedTreasuryMock {
  receive() external payable {
    revert("FailedTreasuryMock: receive failed");
  }
}
