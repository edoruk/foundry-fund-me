//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

// 1. Unit - Testing a spesific part of our code
// 2. Integration - Testing how our code works with other parts of our code
// 3. Forked - Testing our code on a simulated real environment
// 4. Staging - Testing our code in a real environment that is not prod

contract FundMeTest is Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.2 ether; //10**17
    uint256 constant STARTING_BALANCE = 10 ether;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;
    int256 public constant MOCK_PRICE = 30000000000;
    address priceFeedAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployer = new DeployFundMe();
        (fundMe, helperConfig) = deployer.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 1e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoghETH() public {
        vm.expectRevert();
        fundMe.fund(); //send 0 value
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // Next tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(USER, funder);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert(); // skip vm cheatcode
        vm.prank(USER);
        fundMe.withdraw();
    }

    function test_WithdrawWithSingleFunder() public funded {
        // Arrange
        uint256 startOwnerBalance = fundMe.getOwner().balance;
        uint256 startFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endOwnerBalance = fundMe.getOwner().balance;
        uint256 endFundMeBalance = address(fundMe).balance;

        assertEq(endFundMeBalance, 0);
        assertEq(startOwnerBalance + startFundMeBalance, endOwnerBalance);
    }

    function test_WithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank()
            // vm.deal()
            // address
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startOwnerBalance = fundMe.getOwner().balance;
        uint256 startFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        uint256 endOwnerBalance = fundMe.getOwner().balance;
        uint256 endFundMeBalance = address(fundMe).balance;

        assertEq(endFundMeBalance, 0);
        assertEq(startFundMeBalance + startOwnerBalance, endOwnerBalance);
    }

    function test_PriceFeedSetCorrectly() public {
        address retrievedPriceFeed = address(fundMe.getPriceFeed());
        address expectedPriceFeed = helperConfig.activeNetworkConfig();
        console.log(expectedPriceFeed);
        assertEq(expectedPriceFeed, retrievedPriceFeed);
    }
}
