// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {Arblet} from "../src/Arblet.sol";

import {Searcher} from "./mock/Searcher.sol";

contract ArbletTest is Test {
    Arblet arb;
    Searcher searcher;

    address creator = address(1);
    address borrower1 = address(2);
    address borrower2 = address(3);
    address borrower3 = address(4);
    address provider1 = address(5);
    address provider2 = address(6);
    address provider3 = address(7);
    address hacker = address(9);
    address protocol = address(32);

    function setUp() public {
        vm.startPrank(creator);
        arb = new Arblet();
        arb.setProtocol(address(protocol));
        vm.stopPrank();

        //top up accounts with ether
        vm.deal(borrower1, 999 ether);
        vm.deal(borrower2, 999 ether);
        vm.deal(borrower3, 999 ether);
        vm.deal(provider1, 999 ether);
        vm.deal(provider2, 999 ether);
        vm.deal(provider3, 999 ether);
        vm.deal(hacker, 9999 ether);
    }

    function testSuccess_provideLiquidity() public {
        vm.startPrank(provider1);
        arb.provideLiquidity{value: 1 ether}();
        vm.stopPrank();

        assertEq(address(arb).balance, 1 ether);

        vm.startPrank(provider2);
        arb.provideLiquidity{value: 3 ether}();
        vm.stopPrank();

        assertEq(address(arb).balance, 4 ether);
    }

    function testRevert_provideLiquidity_MoreThanBalance(uint256 amount) public {
        vm.assume(amount > 999 ether);

        vm.startPrank(provider1);

        vm.expectRevert();
        arb.provideLiquidity{value: amount}();
        vm.stopPrank();
    }

    function testSuccess_withdrawLiquidity() public {
        vm.startPrank(provider1);
        arb.provideLiquidity{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(provider1);
        arb.withdrawLiquidity(1 ether);
        vm.stopPrank();
    }

    function testRevert_withdrawLiquidity_MoreThanShares(uint256 amount) public {
        vm.assume(amount > 1 ether);

        vm.startPrank(provider1);
        arb.provideLiquidity{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(provider1);
        vm.expectRevert("insufficient user balance");
        arb.withdrawLiquidity(amount);
        vm.stopPrank();
    }

    function testRevert_withdrawLiquidity_Hacker() public {
        vm.startPrank(provider1);
        arb.provideLiquidity{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(hacker);
        vm.expectRevert("insufficient user balance");
        arb.withdrawLiquidity(1 ether);
        vm.stopPrank();
    }

    function testSuccess_currentLiquidity() public {
        vm.startPrank(provider1);
        arb.provideLiquidity{value: 3 ether}();
        vm.stopPrank();

        assertEq(arb.currentLiquidity(), 3 ether);

        vm.startPrank(provider2);
        arb.provideLiquidity{value: 6 ether}();
        vm.stopPrank();

        assertEq(arb.currentLiquidity(), 9 ether);

        vm.startPrank(provider3);
        arb.provideLiquidity{value: 9 ether}();
        vm.stopPrank();

        assertEq(arb.currentLiquidity(), 18 ether);
    }

    function testSuccess_calculateInterest(uint256 amount) public {
        vm.assume(amount > 100000);
        vm.assume(amount < 3 * 10 ** 61);

        uint256 interestRate = 3 * 10 ** 15; // 0.3%

        uint256 expectedInterest = (amount * interestRate) / 10 ** 18;
        uint256 actualInterest = arb.calculateInterest(amount);

        assertEq(actualInterest, expectedInterest);
    }

    function testSuccess_excArb() public {
        vm.startPrank(provider1);
        arb.provideLiquidity{value: 33 ether}();
        vm.stopPrank();

        vm.startPrank(hacker);
        searcher = new Searcher();
        vm.deal(address(searcher), 999 ether);
        searcher.setArblet(address(arb));
        uint256 amount_ = arb.currentLiquidity();
        searcher.exc(amount_);
        vm.stopPrank();

        uint256 providerRate = 2 * 10 ** 15; // 0.3%
        uint256 protocolRate = 1 * 10 ** 15; // 0.1%

        uint256 expectedAmount = amount_ + (33 ether * (providerRate)) / 10 ** 18;
        uint256 actualAmount = arb.currentLiquidity();

        assertEq(expectedAmount, actualAmount);

        uint256 expectedBalance = address(protocol).balance;
        uint256 actualBalance = (33 ether * protocolRate) / 10 ** 18;

        assertEq(expectedBalance, actualBalance);
    }

    function testSuccess_endToEnd() public {
        vm.startPrank(provider1);
        arb.provideLiquidity{value: 3 ether}();
        vm.stopPrank();

        assertEq(arb.currentLiquidity(), 3 ether);

        vm.startPrank(provider2);
        arb.provideLiquidity{value: 6 ether}();
        vm.stopPrank();

        assertEq(arb.currentLiquidity(), 9 ether);

        vm.startPrank(provider3);
        arb.provideLiquidity{value: 9 ether}();
        vm.stopPrank();

        assertEq(arb.currentLiquidity(), 18 ether);

        emit log_string("c");
        emit log_uint(address(arb).balance);

        vm.startPrank(hacker);
        searcher = new Searcher();
        vm.deal(address(searcher), 999 ether);
        searcher.setArblet(address(arb));
        uint256 amount_ = arb.currentLiquidity();
        searcher.exc(amount_);
        vm.stopPrank();

        uint256 providerRate = 2 * 10 ** 15; // 0.2%
        uint256 protocolRate = 1 * 10 ** 15; // 0.1%

        uint256 expectedAmount = amount_ + (18 ether * (providerRate)) / 10 ** 18;
        uint256 actualAmount = arb.currentLiquidity();

        assertEq(expectedAmount, actualAmount);

        uint256 expectedBalance = address(protocol).balance;
        uint256 actualBalance = (18 ether * protocolRate) / 10 ** 18;

        assertEq(expectedBalance, actualBalance);

        emit log_string("c");
        emit log_uint(address(arb).balance);

        emit log_string("p1");
        emit log_uint(address(provider1).balance);
        emit log_string("p2");
        emit log_uint(address(provider2).balance);
        emit log_string("p3");
        emit log_uint(address(provider3).balance);

        vm.startPrank(provider1);
        uint256 shares1 = arb.getShares(provider1);
        arb.withdrawLiquidity(shares1);
        vm.stopPrank();

        emit log_string("c");
        emit log_uint(address(arb).balance);

        vm.startPrank(provider2);
        uint256 shares2 = arb.getShares(provider2);
        arb.withdrawLiquidity(shares2);
        vm.stopPrank();

        emit log_string("c");
        emit log_uint(address(arb).balance);

        vm.startPrank(provider3);
        uint256 shares3 = arb.getShares(provider3);
        arb.withdrawLiquidity(shares3);
        vm.stopPrank();

        emit log_string("p1");
        emit log_uint(address(provider1).balance);
        emit log_string("p2");
        emit log_uint(address(provider2).balance);
        emit log_string("p3");
        emit log_uint(address(provider3).balance);
        emit log_string("p");
        emit log_uint(address(protocol).balance);
        emit log_string("c");
        emit log_uint(address(arb).balance);
    }

    function testSuccess_setFees() public {
        assertEq(arb.fee(), 3 * 10 ** 15);
        assertEq(arb.protocolFee(), 1 * 10 ** 15);

        vm.startPrank(creator);
        arb.setFee(3 * 10 ** 15, 6 * 10 ** 15);
        vm.stopPrank();

        assertEq(arb.fee(), 9 * 10 ** 15);
        assertEq(arb.protocolFee(), 3 * 10 ** 15);
    }

    function testRevert_setFees_nonOwner() public {
        assertEq(arb.fee(), 3 * 10 ** 15);
        assertEq(arb.protocolFee(), 1 * 10 ** 15);

        vm.startPrank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        arb.setFee(3 * 10 ** 15, 6 * 10 ** 15);
        vm.stopPrank();

        assertEq(arb.fee(), 3 * 10 ** 15);
        assertEq(arb.protocolFee(), 1 * 10 ** 15);
    }
}
