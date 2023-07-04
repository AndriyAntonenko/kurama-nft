// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { FailedTreasuryMock } from "../mocks/FailedTreasuryMock.sol";
import { DeployKurama } from "../../script/DeployKurama.sol";
import { Kurama } from "../../src/Kurama.sol";
import { Errors } from "../../src/libraries/Errors.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { Events } from "../../src/libraries/Events.sol";

contract KuramaTest is Test {
  using console for *;

  DeployKurama public deployer;
  Kurama public kurama;
  address public OWNER = makeAddr("owner");
  address public USER = makeAddr("user");
  address public TREASURY = makeAddr("treasury");

  DataTypes.KuramaPhoto public SNOW_PHOTO = DataTypes.KuramaPhoto({
    name: "First snow",
    description: "This photo was made when Kurama saw the snow in the first time",
    image: SNOW_IPFS_URL
  });

  string public constant SNOW_IPFS_URL = "ipfs://QmUYNVue6P9CfyPvHWmKjioAEKzher29wtg5ZkBrZRh6n3";
  uint256 public constant INIT_PRICE = 0.1 ether;
  uint256 public constant USER_BALANCE = 1 ether;

  function setUp() public {
    deployer = new DeployKurama();
    kurama = deployer.run(OWNER, TREASURY);
    deal(USER, USER_BALANCE);
  }

  function testOwnerIsCorrect() public view {
    assert(kurama.owner() == OWNER);
  }

  function testNameIsCorrect() public view {
    string memory expectedName = "Kurama";
    string memory actualName = kurama.name();
    assert(keccak256(abi.encodePacked(expectedName)) == keccak256(abi.encodePacked(actualName)));
  }

  function testRevertIfMinterNotOwner() public {
    vm.startPrank(USER);
    vm.expectRevert();
    kurama.mint(SNOW_PHOTO, INIT_PRICE);
    vm.stopPrank();
  }

  function testMint() public {
    uint256 tokenId = mint();
    assert(kurama.balanceOf(address(kurama)) == 1);
    assert(kurama.priceOf(tokenId) == INIT_PRICE);
  }

  function testGetPhotosToSale() public {
    uint256 tokenId = mint();
    (uint256[] memory ids, DataTypes.KuramaPhoto[] memory photos, uint256[] memory prices) = kurama.getPhotosToSale();
    assert(ids.length == 1);
    assert(ids[0] == tokenId);
    assert(photos.length == 1);
    assert(keccak256(bytes(photos[0].name)) == keccak256(bytes(SNOW_PHOTO.name)));
    assert(keccak256(bytes(photos[0].description)) == keccak256(bytes(SNOW_PHOTO.description)));
    assert(keccak256(bytes(photos[0].image)) == keccak256(bytes(SNOW_PHOTO.image)));
    assert(prices.length == 1);
    assert(prices[0] == INIT_PRICE);
  }

  function testGetEmptyPhotosToSale() public view {
    (uint256[] memory ids, DataTypes.KuramaPhoto[] memory photos, uint256[] memory prices) = kurama.getPhotosToSale();
    assert(ids.length == 0);
    assert(photos.length == 0);
    assert(prices.length == 0);
  }

  function testPurchase() public {
    uint256 tokenId = mint();
    vm.startPrank(USER);
    kurama.purchase{value: INIT_PRICE}(tokenId);
    vm.stopPrank();
    assert(kurama.balanceOf(address(kurama)) == 0);
    assert(kurama.balanceOf(USER) == 1);
    assert(kurama.ownerOf(tokenId) == USER);
  }

  function testPurchaseRevertIfValueToLow() public {
    uint256 tokenId = mint();
    vm.startPrank(USER);
    vm.expectRevert(Errors.Kurama__NotEnoughMoney.selector);
    kurama.purchase{value: INIT_PRICE - 1}(tokenId);
    vm.stopPrank();
  }

  function testChangePrice() public {
    uint256 tokenId = mint();
    vm.startPrank(OWNER);
    kurama.changePrice(tokenId, 0.2 ether);
    vm.stopPrank();
    assert(kurama.priceOf(tokenId) == 0.2 ether);
  }

  function testChangePriceRevertIfNotOwner() public {
    uint256 tokenId = mint();
    vm.startPrank(USER);
    vm.expectRevert();
    kurama.changePrice(tokenId, 0.2 ether);
    vm.stopPrank();
  }

  function testGetTreasury() public view {
    assert(kurama.getTreasury() == TREASURY);
  }

  function testGetTokensAmountToPurchase() public {
    uint256 tokenId = mint();
    assert(kurama.getTokensAmountToPurchase() == 1);
    vm.startPrank(USER);
    kurama.purchase{value: INIT_PRICE}(tokenId);
    vm.stopPrank();
    assert(kurama.getTokensAmountToPurchase() == 0);
  }

  function testRevertPurchaseIfSaleOnPause() public {
    uint256 tokenId = mint();
    vm.startPrank(OWNER);
    kurama.pause();
    vm.stopPrank();

    vm.startPrank(USER);
    vm.expectRevert();
    kurama.purchase{value: INIT_PRICE}(tokenId);
    vm.stopPrank();
  }

  function testRevertPurchaseIfNoTokensToSale() public {
    vm.startPrank(USER);
    vm.expectRevert();
    kurama.purchase{value: INIT_PRICE}(0);
    vm.stopPrank();
  }

  function testRevertIfTokenNotAllowedToSale() public {
    (uint256 t1,) = mintTwo();
    vm.startPrank(USER);
    kurama.purchase{value: INIT_PRICE}(t1);
    vm.expectRevert(Errors.Kurama__TokenNotAllowedForSale.selector);
    kurama.purchase{value: INIT_PRICE}(t1);
    vm.stopPrank();
  }

  function testTokenURI() public {
    uint256 tokenId = mint();
    string memory expectedURI = string(
      abi.encodePacked(
        "data:application/json;base64,",
        Base64.encode(
          bytes(
            string(
              abi.encodePacked(
                '{"name": "',
                SNOW_PHOTO.name,
                '", "id": "',
                tokenId,
                '", "description": "',
                SNOW_PHOTO.description,
                '", "image": "',
                SNOW_PHOTO.image,
                '"}'
              )
            )
          )
        )
      )
    );
    assert(keccak256(bytes(kurama.tokenURI(tokenId))) == keccak256(bytes(expectedURI)));
  }

  function testTransferingToTreasury() public {
    uint256 tokenId = mint();
    vm.startPrank(USER);
    kurama.purchase{value: INIT_PRICE}(tokenId);
    vm.stopPrank();
    assert(payable(TREASURY).balance == INIT_PRICE);
  }

  function testRevertOnFailedTransferToTreasury() public {
    FailedTreasuryMock failedTreasury = new FailedTreasuryMock();
    Kurama kuramaWithFailedTreasury = new Kurama(OWNER, address(failedTreasury));

    vm.startPrank(OWNER);
    uint256 tokenId = kuramaWithFailedTreasury.mint(SNOW_PHOTO, INIT_PRICE);
    vm.stopPrank();

    vm.startPrank(USER);
    vm.expectRevert(Errors.Kurama__CannotTransferToTreasury.selector);
    kuramaWithFailedTreasury.purchase{value: INIT_PRICE}(tokenId);
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                                HELPERS
  //////////////////////////////////////////////////////////////*/

  function mint() private returns (uint256) {
    vm.startPrank(OWNER);
    uint256 tokenId = kurama.mint(SNOW_PHOTO, INIT_PRICE);
    vm.stopPrank();
    return tokenId;
  }

  function mintTwo() private returns (uint256 t1, uint256 t2) {
    vm.startPrank(OWNER);
    t1 = kurama.mint(SNOW_PHOTO, INIT_PRICE);
    t2 = kurama.mint(SNOW_PHOTO, INIT_PRICE);
    vm.stopPrank();
  }
}
