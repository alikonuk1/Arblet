// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {Ownable} from "./utils/Ownable.sol";

contract Arblet is Ownable {
    bool public borrowLocked;
    uint256 public constant fee = 3 * 10 ** 15; // 3000000000000000 = 0.3%
    uint256 public constant protocolFee = 1 * 10 ** 15; // 1000000000000000 = 0.1%
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

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Auto repay debt from msg.sender
    fallback() external payable {
        // Shortcut for raw calls to repay debt
        repayDebt(msg.sender);
    }

    // Add ether liquidity and receive newly minted shares
    function provideLiquidity() external payable borrowLock {
        require(msg.value > 1 wei, "Non-dust value required");
        // New shares minted to the same ratio
        uint256 sharesMinted = msg.value;
        // Share balances updated in storage
        providerShares[msg.sender] = providerShares[msg.sender] + sharesMinted;
        shareSupply = shareSupply + sharesMinted;

        emit LiquidityAdded(msg.sender, msg.value, sharesMinted);
    }

    //withdraw a portion of liquidity by burning shares owned
    function withdrawLiquidity(uint256 shareAmount) external borrowLock {
        require(shareAmount > 0, "non-zero value required");
        require(shareAmount <= providerShares[msg.sender], "insufficient user balance");
        require(shareAmount <= shareSupply, "insufficient global supply");

        //percentage and value of shares calcuated
        //uint256 shareProportion = liquidityAsPercentage(shareAmount);
        //uint256 shareValue = shareValue_(shareAmount);
        //share balances updated in storage
        providerShares[msg.sender] = providerShares[msg.sender] - shareAmount;
        shareSupply = shareSupply - shareAmount;
        //ether returned to user
        //msg.sender.transfer(shareValue);
        (bool sent,) = msg.sender.call{value: shareAmount}("");
        require(sent, "Failed to send Ether");

        emit LiquidityRemoved(msg.sender, shareAmount, shareAmount);
    }

    //issue a new loan
    function borrow(uint256 ethAmount) external borrowLock {
        require(ethAmount >= 1 wei, "non-dust value required");
        require(ethAmount <= address(this).balance, "insufficient global liquidity");
        //@dev this should really be unreachable given the modifier
        require(borrowerDebt[msg.sender] == 0, "active loan in progress");
        //current balance recored and debt calculated
        uint256 initialLiquidity = address(this).balance;
        uint256 interest = calculateInterest(ethAmount);
        uint256 protocolInterest = calculateProtocolInterest(ethAmount);
        uint256 outstandingDebt = ethAmount + interest;
        //global mutex activated, pausing all functions except repayDebt()
        borrowLocked = true;
        //debt recoreded in storage (but gas will be partially refunded when it's zeroed out)
        borrowerDebt[msg.sender] = outstandingDebt;
        //requested funds sent to user via raw call with empty data
        //additional gas withheld to ensure the completion of this function
        //data is ignored
        (bool result0,) = msg.sender.call{gas: (gasleft() - 10000), value: ethAmount}("");
        //borrower can now execute actions triggered by a fallback function in their contract
        //they need to call repayDebt() and return the funds before this function continues
        require(result0, "the call must return true");
        //will revert full tx if loan is not repaid
        require(
            address(this).balance >= (initialLiquidity + interest),
            "funds must be returned plus interest"
        );
        // prevents mutex being locked via ether forced into contract rather than via repayDebt()
        require(borrowerDebt[msg.sender] == 0, "borrower debt must be repaid in full");
        (bool result1,) = protocol.call{gas: (gasleft() - 10000), value: protocolInterest}("");
        //borrower can now execute actions triggered by a fallback function in their contract
        //they need to call repayDebt() and return the funds before this function continues
        require(result1, "the call must return true");
        //mutex disabled
        borrowLocked = false;

        emit LoanCompleted(msg.sender, outstandingDebt);
    }

    //debt can be repaid from another address than the original borrower
    function repayDebt(address borrower) public payable {
        require(borrowLocked == true, "can only repay active loans");
        require(borrowerDebt[borrower] != 0, "must repay outstanding debt");
        require(msg.value == borrowerDebt[borrower], "debt must be repaid in full");

        uint256 outstandingDebt = borrowerDebt[borrower];
        borrowerDebt[borrower] = 0;

        emit LoanRepayed(borrower, msg.sender, outstandingDebt);
    }

    /**
     * VIEW FUNCTIONS
     */

    // 1000000000000000000 = 100
    // 
    // 10000000000000000 = 1
    // 
    // 1000000000000000 = 0.1
    function liquidityAsPercentage(uint256 addedLiquidity) public view returns(uint256 liquidityPercentage){
        if(address(this).balance <= 0){
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

    function calculateInterest(uint256 loanAmount) public pure returns (uint256 interest) {
        interest = (loanAmount * fee) / 10 ** 18;
    }

    function calculateProtocolInterest(uint256 loanAmount) public pure returns (uint256 protocolInterest) {
        protocolInterest = (loanAmount * protocolFee) / 10 ** 18;
    }

    function currentLiquidity() external view returns (uint256 avialableLiquidity) {
        avialableLiquidity = address(this).balance;
    }

    function setProtocol(address protocol_) public onlyOwner {
        protocol = protocol_;
    }

    function getShares(address provider) public view returns (uint256) {
        return (providerShares[provider]);
    }
}
