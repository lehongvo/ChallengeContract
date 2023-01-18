// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface IChallange {
    //It returns the goal of the challenge.
    function goal() external view returns(uint256);

    //It returns the duration of the challenge.
    function duration() external view returns(uint256);

    //It returns the history of the challenge.
    function getChallengeHistory() external view returns(uint256[] memory date, uint256[] memory data);

    //It returns the number of days required to complete the challenge.
    function dayRequired() external view returns(uint256);

    //It returns the total balance of the base token.
    function totalReward() external view returns(uint256);

    //It returns the balance of the token.
    function getBalanceToken() external view returns(uint256[] memory);

    function allowGiveUp(uint256 _index) external view returns(bool);

    function donationWalletAddress() external view returns(address);

    function getAwardReceiversPercent() external view returns(uint256[] memory);
}

contract Demo {
    function getData(address _address) public view returns(uint256[] memory) {
        return IChallange(_address).getAwardReceiversPercent();
    }
}