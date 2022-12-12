// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {Ownable} from "./utils/Ownable.sol";

contract Arblet is Ownable {
    bool public borrowLocked;
    uint256 public fee = 3 * 10 ** 15; // 3000000000000000 = 0.3%
    uint256 public protocolFee = 1 * 10 ** 15; // 1000000000000000 = 0.1%
    uint256 public shareSupply;
    address public protocol;

    mapping(address => uint256) public providerShares;
    mapping(address => uint256) public borrowerDebt;

    modifier borrowLock() {
        require(!borrowLocked, "Functions locked during a loan");
        _;
    }

    event LiquidityAdded(address indexed provider, uint256 ethAdded, uint256 sharesMinted);

    event LiquidityRemoved(address indexed provider, uint256 ethRemoved, uint256 sharesBurned);

    event LoanCompleted(address indexed borrower, uint256 debtRepayed);

    event LoanRepayed(address indexed borrower, address indexed payee, uint256 debtRepayed);

    receive() external payable {}

    // Auto repay debt from msg.sender
    fallback() external payable {
        // Shortcut for raw calls to repay debt
        repayDebt(msg.sender);
    }

    function provideLiquidity() external payable borrowLock {
        require(msg.value > 1 wei, "Non-dust value required");
        uint256 sharesMinted = msg.value;
        providerShares[msg.sender] = providerShares[msg.sender] + sharesMinted;
        shareSupply = shareSupply + sharesMinted;

        emit LiquidityAdded(msg.sender, msg.value, sharesMinted);
    }

    function withdrawLiquidity(uint256 shareAmount) external borrowLock {
        require(shareAmount > 0, "non-zero value required");
        require(shareAmount <= providerShares[msg.sender], "insufficient user balance");
        require(shareAmount <= shareSupply, "insufficient global supply");

        uint256 sharePer = (address(this).balance * 10 ** 18 / shareSupply);
        uint256 shareValue = (sharePer * (shareAmount)) / 10 ** 18;

        providerShares[msg.sender] = providerShares[msg.sender] - shareAmount;
        shareSupply = shareSupply - shareAmount;

        (bool sent,) = msg.sender.call{value: shareValue}("");
        require(sent, "Failed to send Ether");

        emit LiquidityRemoved(msg.sender, shareValue, shareAmount);
    }

    //issue a new loan
    function borrow(uint256 ethAmount) external borrowLock {
        require(ethAmount >= 1 wei, "non-dust value required");
        require(ethAmount <= address(this).balance, "insufficient global liquidity");
        require(borrowerDebt[msg.sender] == 0, "active loan in progress");

        uint256 initialLiquidity = address(this).balance;
        uint256 interest = calculateInterest(ethAmount);
        uint256 protocolInterest = calculateProtocolInterest(ethAmount);
        uint256 outstandingDebt = ethAmount + interest;

        borrowLocked = true;
        borrowerDebt[msg.sender] = outstandingDebt;

        (bool result0,) = msg.sender.call{gas: (gasleft() - 10000), value: ethAmount}("");
        require(result0, "the call must return true");

        require(address(this).balance >= (initialLiquidity + interest), "funds must be returned plus interest");
        require(borrowerDebt[msg.sender] == 0, "borrower debt must be repaid in full");

        (bool result1,) = protocol.call{gas: (gasleft() - 10000), value: protocolInterest}("");
        require(result1, "the call must return true");

        borrowLocked = false;

        emit LoanCompleted(msg.sender, outstandingDebt);
    }

    function repayDebt(address borrower) public payable {
        require(borrowLocked == true, "can only repay active loans");
        require(borrowerDebt[borrower] != 0, "must repay outstanding debt");
        require(msg.value == borrowerDebt[borrower], "debt must be repaid in full");

        uint256 outstandingDebt = borrowerDebt[borrower];
        borrowerDebt[borrower] = 0;

        emit LoanRepayed(borrower, msg.sender, outstandingDebt);
    }

    function setProtocol(address protocol_) public onlyOwner borrowLock {
        protocol = protocol_;
    }

    function setFee(uint256 protocolFee_, uint256 providerFee_) public onlyOwner borrowLock {
        protocolFee = protocolFee_;
        fee = protocolFee_ + providerFee_;
    }
    /**
     * VIEW FUNCTIONS
     */

    // 1000000000000000000 = 100
    //
    // 10000000000000000 = 1
    //
    // 1000000000000000 = 0.1
    function liquidityAsPercentage(uint256 addedLiquidity) public view returns (uint256 liquidityPercentage) {
        if (address(this).balance <= 0) {
            liquidityPercentage = 10 ** 18;
        } else {
            uint256 liquidity = addedLiquidity + address(this).balance;
            liquidityPercentage = (addedLiquidity * 10 ** 18 / liquidity);
        }
    }

    function shareValue_(uint256 shareProportion) public view returns (uint256 value) {
        uint256 interestValue = address(this).balance - shareSupply;
        value = (interestValue * 10 ** 18) / shareProportion;
    }

    function calculateInterest(uint256 loanAmount) public view returns (uint256 interest) {
        interest = (loanAmount * fee) / 10 ** 18;
    }

    function calculateProtocolInterest(uint256 loanAmount) public view returns (uint256 protocolInterest) {
        protocolInterest = (loanAmount * protocolFee) / 10 ** 18;
    }

    function currentLiquidity() external view returns (uint256 avialableLiquidity) {
        avialableLiquidity = address(this).balance;
    }

    function getShares(address provider) public view returns (uint256) {
        return (providerShares[provider]);
    }
}
