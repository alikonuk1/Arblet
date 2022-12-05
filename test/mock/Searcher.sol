// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IArblet {
    function borrow(uint256 _ethAmount) external;
    function repayDebt(address _borrower) external payable;
    function calculateInterest(uint256 loanAmount) external returns (uint256 interest);
    function calculateProtocolInterest(uint256 loanAmount) external returns (uint256 protocolInterest);
}

contract Searcher {
    address public arblet;
    uint256 public amount;

    receive() external payable {
        IArblet arb = IArblet(arblet);

        uint256 amount_ = arb.calculateInterest(amount) + amount;

        arb.repayDebt{gas: (gasleft() - 10000), value: amount_}(address(this));
    }

    fallback() external payable {
        //repay(address(this), amount);
    }

    function setArblet(address arblet_) public {
        arblet = arblet_;
    }

    function exc(uint256 amount_) public {
        amount = amount_;
        IArblet arb = IArblet(arblet);

        arb.borrow(amount_);
    }
}
