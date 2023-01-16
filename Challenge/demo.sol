// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./ExerciseSupplementNFT.sol";

contract Demo{
    address[] public erc20ListAddress;

    function updateBalance(address[] memory erc721Address) public {
        address data = erc721Address[0];
        erc20ListAddress = ExerciseSupplementNFT(data).getErc20ListAddress();
    }
}