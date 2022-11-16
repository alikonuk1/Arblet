// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

contract Arblet {
    // TODO: make a function to set the interest rate
    bool public reentracyGuard;
    uint256 public constant FEE = 3 * 10 ** 15; //0.3%
    uint256 public shareSupply;

    mapping(address => uint256) public providerShares;
    mapping(address => uint256) public borrowerDebt;

    modifier borrowLock() {
        require(!reentracyGuard, "functions locked during active loan");
        _;
    }

    event LiquidityAdded(address indexed provider, uint256 ethAdded, uint256 sharesMinted);

    event LiquidityRemoved(address indexed provider, uint256 ethRemoved, uint256 sharesBurned);

    event LoanCompleted(address indexed borrower, uint256 debtRepayed);

    event LoanRepayed(address indexed borrower, address indexed payee, uint256 debtRepayed);

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    //auto repay debt from msg.sender
    fallback() external payable {
        //shortcut for raw calls to repay debt
        repayDebt(msg.sender);
    }

    //add ether liquidity and receive newly minted shares
    function provideLiquidity() external payable borrowLock {
        require(msg.value > 1 wei, "non-dust value required");
        //new liquidity as a percentage of total liquidity
        uint256 liquidityProportion = liquidityAsPercentage(msg.value);
        //new shares minted to the same ratio
        uint256 sharesMinted = sharesAfterDeposit(liquidityProportion);
        //share balances updated in storage
        providerShares[msg.sender] = providerShares[msg.sender] + sharesMinted;
        shareSupply = shareSupply + sharesMinted;

        emit LiquidityAdded(msg.sender, msg.value, sharesMinted);
    }

    //withdraw a portion of liquidtiy by burning shares owned
    function withdrawLiquidity(uint256 _shareAmount) external borrowLock {
        require(_shareAmount > 0, "non-zero value required");
        require(_shareAmount <= providerShares[msg.sender], "insufficient user balance");
        require(_shareAmount <= shareSupply, "insufficient global supply");

        //percentage and value of shares calcuated
        uint256 shareProportion = sharesAsPercentage(_shareAmount);
        uint256 shareValue = shareValue_(shareProportion);
        //share balances updated in storage
        providerShares[msg.sender] = providerShares[msg.sender] - _shareAmount;
        shareSupply = shareSupply - _shareAmount;
        //ether returned to user
        //msg.sender.transfer(shareValue);
        (bool sent,) = msg.sender.call{value: shareValue}("");
        require(sent, "Failed to send Ether");

        emit LiquidityRemoved(msg.sender, shareValue, _shareAmount);
    }

    //issue a new loan
    function borrow(uint256 _ethAmount) external borrowLock {
        require(_ethAmount >= 1 wei, "non-dust value required");
        require(_ethAmount <= address(this).balance, "insufficient global liquidity");
        //@dev this should really be unreachable given the modifier
        require(borrowerDebt[msg.sender] == 0, "active loan in progress");
        //current balance recored and debt calculated
        uint256 initialLiquidity = address(this).balance;
        uint256 interest = calculateInterest(_ethAmount);
        uint256 outstandingDebt = _ethAmount + interest;
        //global mutex activated, pauding all functions except repayDebt()
        reentracyGuard = true;
        //debt recoreded in storage (but gas will be partially refunded when it's zeroed out)
        borrowerDebt[msg.sender] = outstandingDebt;
        //requested funds sent to user via raw call with empty data
        //additional gas withheld to ensure the completion of this function
        //data is ignored
        bool result;
        (result,) = msg.sender.call{gas: (gasleft() - 10000), value: _ethAmount}("");
        //borrower can now execute actions triggered by a fallback function in their contract
        //they need to call repayDebt() and return the funds before this function continues
        require(result, "the call must return true");
        //will revert full tx if loan is not repaid
        require(address(this).balance >= (initialLiquidity + interest), "funds must be returned plus interest");
        // prevents mutex being locked via ether forced into contract rather than via repayDebt()
        require(borrowerDebt[msg.sender] == 0, "borrower debt must be repaid in full");
        //mutex disabled
        reentracyGuard = false;

        emit LoanCompleted(msg.sender, outstandingDebt);
    }

    //debt can be repaid from another address than the original borrower
    function repayDebt(address _borrower) public payable {
        require(reentracyGuard == true, "can only repay active loans");
        require(borrowerDebt[_borrower] != 0, "must repay outstanding debt");
        require(msg.value == borrowerDebt[_borrower], "debt must be repaid in full");

        uint256 outstandingDebt = borrowerDebt[_borrower];
        borrowerDebt[_borrower] = 0;

        emit LoanRepayed(_borrower, msg.sender, outstandingDebt);
    }

    /**
     * VIEW FUNCTIONS
     */

    function sharesAsPercentage(uint256 _shareAmount) public view returns (uint256 _sharePercentage) {
        _sharePercentage = _shareAmount / shareSupply;
    }

    function shareValue_(uint256 _shareAmount) public view returns (uint256 _value) {
        _value = address(this).balance / _shareAmount;
    }

    function liquidityAsPercentage(uint256 _newLiquidity) public view returns (uint256 _liquidityPercentage) {
        _liquidityPercentage = (10**18 * _newLiquidity) / address(this).balance;
    }

    function sharesAfterDeposit(uint256 _liquidityProportion) public view returns (uint256 _shares) {
        uint256 newShareSupply;

        if (shareSupply == 0 || 10**18 == _liquidityProportion) {
            newShareSupply = 10**18;
        } else {
            newShareSupply = (10**18 * shareSupply) / _liquidityProportion;
        }

        _shares = newShareSupply - shareSupply;
    }

    function calculateInterest(uint256 _loanAmount) public pure returns (uint256 _interest) {
        _interest = _loanAmount * FEE;
    }

    function currentLiquidity() external view returns (uint256 _avialableLiquidity) {
        _avialableLiquidity = address(this).balance;
    }
}
