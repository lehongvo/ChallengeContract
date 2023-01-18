// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./EnumerableSet.sol";
import "./Counters.sol";
import "./IERC1155.sol";
import "./IERC721Receiver.sol";
import "./TransferHelper.sol";
import "./TransferHelper.sol";
import "./SafeMath.sol";
import "./IChallenge.sol";

contract Gacha is IERC721Receiver{
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    enum TypeToken { ERC20, ERC721, ERC1155 }
    enum BetStatus { PENDING, SUCCESS, FAIL }
    enum ChallengeState{PROCESSING, SUCCESS, FAILED, GAVE_UP,CLOSED}

    modifier onlyAdmin() {
        require(admins.contains(msg.sender), "NOT ADMIN.");
        _;
    }

    // This is a function to add the sender to the admins.
    constructor(){
        admins.add(msg.sender);
    }

    //This is RewardToken struct.
    struct RewardToken{
        address addressToken;
        uint256 totalRate;
        uint256 unlockRate;
        uint256 rawardValue;
        TypeToken typeToken;
        ChallengeInfo challengeInfo;
    }

    //This is ChallengeInfo struct.
    struct ChallengeInfo{
        uint256 targetStepPerDay;
        uint256 challengeDuration;
        uint256 stepDataToSend;
        uint256 minimumAchievementDays;
        bool isDividendSuccessOrFailure;
        uint256 amountDeposit;
    }

    //This is UserInfo struct.
    struct UserInfo{
        uint256[] historyDate;
        uint256[] historyData;
        BetStatus betStatus;
        mapping(address => ChallengeInfo) challengeInfo;
    }

    // This is a function to add new reward.
    event AddNewReward(address indexed _addressToken, uint256 _totalRate, uint256 _unlockRate, TypeToken _typeToken);
    // This is a function to delete reward.
    event DeleteReward(address indexed _addressToken, address _caller);
    // This is a function to send daily result gacha.
    event SendDailyResultGacha(address indexed _caller, uint256[] _listIndexReward);

    EnumerableSet.AddressSet private admins;// This is a function to store the address of admin.
    mapping(uint256 => RewardToken) public rewardTokens; // This is a mapping to store the reward token.
    mapping(uint256 => UserInfo) public userInfo; // This is a mapping to store the user info.
    Counters.Counter private totalNumberReward; // This is a function to count the total number of reward.
    address public mainNFTAddress; // Declaring a public variable of type address.

    // This function is used to send daily result gacha.
    function sendDailyResultGacha(uint256[] memory _listIndexReward, address _challengerAddress) external returns(bool){
        // This is a function to check if the list index reward is empty or not.
        if(_listIndexReward.length == 0) {
            return false; 
        }

        bool isWonThePrize = false;
        // This is a loop to check if the reward token is exist or not.
        for(uint256 i = 0 ; i < _listIndexReward.length ; i++) {
            // This is a function to get the random value.
            uint256 ramdomWithLimitValue = (rewardTokens[_listIndexReward[i]].totalRate).div(
                rewardTokens[_listIndexReward[i]].unlockRate
            );

            // This is a function to check if the reward token is exist or not.
            if(checkRamdomNumber(ramdomWithLimitValue)) {
                if(rewardTokens[_listIndexReward[i]].typeToken == TypeToken.ERC20) {
                    // This is a function to transfer the reward token to the challenger address.
                    TransferHelper.safeTransfer(
                        rewardTokens[_listIndexReward[i]].addressToken,
                        _challengerAddress,
                        rewardTokens[_listIndexReward[i]].rawardValue
                    );
                    isWonThePrize = true;
                }
            }
        }

        emit SendDailyResultGacha(msg.sender, _listIndexReward);

        return isWonThePrize;
    }
    
    // This function is used to add new reward.
    function updateReward(
        address _addressToken,
        uint256 _totalRate,
        uint256 _unlockRate,
        uint256 _rawardValue,
        TypeToken _typeToken,
        ChallengeInfo memory _challengeInfo
    ) external onlyAdmin{
        /*
        This is a function to check if the address token is not zero, 
        unlock rate is less than total rate and reward value is greater than zero.
        */
        require(_addressToken != address(0), "ZERO ADDRESS.");
        require(_unlockRate < _totalRate, "UNLOCK RATE MUST BE LESS THAN TOTAL RATE.");
        require(_rawardValue > 0, "VALUE ");

        if(!isRewardTokenExist(_addressToken)){
            totalNumberReward.increment(); 
            uint256 indexOfTokenReward;
            //This is a loop to check if the reward token is exist or not.
            for(uint256 i = 1; i <= totalNumberReward.current(); i++) {
                if(rewardTokens[i].addressToken == address(0)) {
                    indexOfTokenReward = i;
                    break;
                }
            }
            // This function is used to add or update reward.
            addReward(indexOfTokenReward, _addressToken, _totalRate, _unlockRate, _rawardValue, _typeToken, _challengeInfo);
        } else {
            // This function is used to add or update reward.
            addReward(findIndexOfTokenReward(_addressToken), _addressToken, _totalRate, _rawardValue, _unlockRate, _typeToken, _challengeInfo);
        }

        emit AddNewReward(_addressToken, _totalRate, _unlockRate, _typeToken);
    }
    
    function checkRewardConditions(uint256 _indexOfTokenReward, address _challengerAddress) public view returns(bool){
        uint256 challengeDuration = IChallange(_challengerAddress).duration();
        if(rewardTokens[_indexOfTokenReward].challengeInfo.targetStepPerDay <= IChallange(_challengerAddress).goal()){
            if(rewardTokens[_indexOfTokenReward].challengeInfo.challengeDuration <= challengeDuration){
                uint256[] memory challengeHiostoryData;
                (, challengeHiostoryData) = IChallange(_challengerAddress).getChallengeHistory();
                bool isCorrectStepDataToSend = true;
                for(uint256 i = 0; i < challengeHiostoryData.length; i++) {
                    if(rewardTokens[_indexOfTokenReward].challengeInfo.stepDataToSend > challengeHiostoryData[i]) {
                        isCorrectStepDataToSend = false;
                        break;
                    }
                }
                if(isCorrectStepDataToSend) {
                    if(challengeDuration > challengeDuration.sub(challengeDuration.div(7))) {
                        if(rewardTokens[_indexOfTokenReward].challengeInfo.amountDeposit <= IChallange(_challengerAddress).totalReward()) {
                            address danationAddress = IChallange(mainNFTAddress).donationWalletAddress();
                            address admin = admins.values()[0];
                            if(rewardTokens[_indexOfTokenReward].challengeInfo.isDividendSuccessOrFailure) {
                                if(IChallange(_challengerAddress).getAwardReceiversPercent()[1] == 98) {
                                    
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    // This function is used to delete reward.
    function deleteReward(address _addressToken) external {
        // This function is used to find index of token reward.
        uint256 indexOfTokenReward = findIndexOfTokenReward(_addressToken);
        require(indexOfTokenReward > 0 ,"ADDRESS TOKEN NOT EXIST.");

        // Used to delete the reward token.
        delete rewardTokens[indexOfTokenReward];

        emit DeleteReward (_addressToken, msg.sender);
    }

    // This function is used to check if the reward token is exist or not.
    function isRewardTokenExist(address _addressToken) public view returns(bool) {
        if(totalNumberReward.current() == 0) {
            return false;
        } else {
            // This is a loop to check if the reward token is exist or not.
            for(uint256 i = 1; i <= totalNumberReward.current(); i++) {
                if(rewardTokens[i].addressToken == _addressToken) {
                    return true;
                }
            }
        }
        return false;
    }

    // This function is used to add or update reward.
    function addReward(
        uint256 _indexOfTokenReward,
        address _addressToken,
        uint256 _totalRate,
        uint256 _unlockRate,
        uint256 _rawardValue,
        TypeToken _typeToken,
        ChallengeInfo memory _challengeInfo
    ) internal {
        // This is a struct.
        rewardTokens[_indexOfTokenReward] = RewardToken(
            _addressToken,
            _totalRate,
            _unlockRate,
            _rawardValue,
            _typeToken,
            _challengeInfo
        );
    }

    // This function is used to find index of token reward.
    function findIndexOfTokenReward(address _addressToken) public view returns(uint256 indexOfTokenReward) {
        // This is a loop to check if the reward token is exist or not.
        for(uint256 i = 1; i <= totalNumberReward.current(); i++) {
            if(rewardTokens[i].addressToken == _addressToken) {
                indexOfTokenReward = i;
                break;
            }
        }
    }

    // This function is used to get total number of reward.
    function getTotalNumberReward() public view returns(uint256) {
        return totalNumberReward.current();
    }

    // This function is used to add or remove admin.
    function updateAdmin(address _adminAddr, bool _flag) external onlyAdmin {
        require(_adminAddr != address(0), "INVALID ADDRESS.");
        // This is a function to add or remove admin.
        if (_flag) {
            admins.add(_adminAddr);
        } else {
            admins.remove(_adminAddr);
        }
    }

    // This function is used to get all admins.
    function getAdmins() external view returns (address[] memory) {
        return admins.values();
    }

    // This function is used to generate random number.
    function checkRamdomNumber(uint256 _ramdomWithLimitValue) public view returns(bool){
        // This is a function to generate random number.
        uint256 firstRamdomValue = uint256(
            keccak256(abi.encodePacked(
                block.number, block.difficulty, msg.sender)
            )
        ) % _ramdomWithLimitValue;

        uint256 secondRamdomValue = uint256(
            keccak256(abi.encodePacked(
                block.timestamp, block.difficulty, msg.sender)
            )
        ) % _ramdomWithLimitValue;

        // This is a function to check if the first random value is equal to the second random value or not.
        if(firstRamdomValue == secondRamdomValue) {
            return true;
        } else {
            return false;
        }
    }

    function setMainNFTAdress(address _mainNFTAddress) external onlyAdmin{
        require(_mainNFTAddress != address(0), "INVALID MAIN NFT ADDRESS.");
        mainNFTAddress = _mainNFTAddress;
    }

    /**
     * @dev onERC721Received.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    /**
     * @dev onERC1155Received.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
