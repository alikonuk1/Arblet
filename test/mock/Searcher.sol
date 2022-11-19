// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IArblet {
    function borrow(uint256 _ethAmount) external;
    function repayDebt(address _borrower) external payable;
}

contract Searcher {

    address public arblet;

    receive() external payable {}
    fallback() external payable {}

    function setArblet(address arblet_) public {
        arblet = arblet_;
    }

    function exc(uint256 amount_) public {
        IArblet arb = IArblet(arblet);

        arb.borrow(amount_);
        arb.repayDebt(address(this));
    }

}