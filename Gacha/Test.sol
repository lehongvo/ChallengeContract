// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./SafeMath.sol";

contract Demo{
    using SafeMath for uint256;

    function getData(uint256 a, uint256 b) public view returns(uint256) {
        return a.div(b);
    }
}