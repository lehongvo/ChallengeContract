// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "./EnumerableSet.sol";
import "./Counters.sol";
import "./IERC1155.sol";
import "./IERC721Receiver.sol";
import "./TransferHelper.sol";
import "./TransferHelper.sol";
import "./SafeMath.sol";

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

    constructor(){
        admins.add(msg.sender);
    }

    struct RewardToken{
        address addressToken;
        uint256 totalRate;
        uint256 unlockRate;
        uint256 rawardValue;
        TypeToken typeToken;
    }

    struct ChallengeInfo{
        address challengeAddress;
        ChallengeState _statusChallenge;
    }

    struct UserInfo{
        uint256[] historyDate;
        uint256[] historyData;
        BetStatus betStatus;
        mapping(address => ChallengeInfo) challengeInfo;
    }

    event AddNewReward(address indexed _addressToken, uint256 _totalRate, uint256 _unlockRate, TypeToken _typeToken);
    event DeleteReward(address indexed _addressToken, address _caller);
    event SendDailyResultGacha(address indexed _caller, uint256[] _listIndexReward);
    
    EnumerableSet.AddressSet private admins;
    mapping(uint256 => RewardToken) public rewardTokens;
    mapping(uint256 => UserInfo) public userInfo;
    Counters.Counter private totalNumberReward;

    function sendDailyResultGacha(uint256[] memory _listIndexReward, address _challengerAddress) external returns(bool){
        if(_listIndexReward.length == 0) {
            return false; 
        }

        bool isWonThePrize = false;
        for(uint256 i = 0 ; i < _listIndexReward.length ; i++) {
            uint256 ramdomWithLimitValue = (rewardTokens[_listIndexReward[i]].totalRate).div(
                rewardTokens[_listIndexReward[i]].unlockRate
            );
            if(checkRamdomNumber(ramdomWithLimitValue)) {
                if(rewardTokens[_listIndexReward[i]].typeToken == TypeToken.ERC20) {
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
    }

    function addNewReward(
        address _addressToken,
        uint256 _totalRate,
        uint256 _unlockRate,
        uint256 _rawardValue,
        TypeToken _typeToken
    ) external onlyAdmin{
        require(_addressToken != address(0), "ZERO ADDRESS.");
        require(_unlockRate < _totalRate, "UNLOCK RATE MUST BE LESS THAN TOTAL RATE.");
        require(_rawardValue > 0, "VALUE ");

        if(!isRewardTokenExist(_addressToken)){
            totalNumberReward.increment(); 
            uint256 indexOfTokenReward;
            for(uint256 i = 1; i <= totalNumberReward.current(); i++) {
                if(rewardTokens[i].addressToken == address(0)) {
                    indexOfTokenReward = i;
                    break;
                }
            }
            addOrUpdateReward(indexOfTokenReward, _addressToken, _totalRate, _unlockRate, _rawardValue, _typeToken);
        } else {
            addOrUpdateReward(findIndexOfTokenReward(_addressToken), _addressToken, _totalRate, _rawardValue, _unlockRate, _typeToken);
        }

        emit AddNewReward(_addressToken, _totalRate, _unlockRate, _typeToken);
    }

    function deleteReward(address _addressToken) external {
        uint256 indexOfTokenReward = findIndexOfTokenReward(_addressToken);
        require(indexOfTokenReward > 0 ,"ADDRESS TOKEN NOT EXIST.");

        delete rewardTokens[indexOfTokenReward];

        emit DeleteReward (_addressToken, msg.sender);
    }

    function isRewardTokenExist(address _addressToken) public view returns(bool) {
        if(totalNumberReward.current() == 0) {
            return false;
        } else {
            for(uint256 i = 1; i <= totalNumberReward.current(); i++) {
                if(rewardTokens[i].addressToken == _addressToken) {
                    return true;
                }
            }
        }
        return false;
    }

    function addOrUpdateReward(
        uint256 _indexOfTokenReward,
        address _addressToken,
        uint256 _totalRate,
        uint256 _unlockRate,
        uint256 _rawardValue,
        TypeToken _typeToken
    ) internal {
        rewardTokens[_indexOfTokenReward] = RewardToken(
            _addressToken,
            _totalRate,
            _unlockRate,
            _rawardValue,
            _typeToken
        );
    }

    function findIndexOfTokenReward(address _addressToken) public view returns(uint256 indexOfTokenReward) {
        for(uint256 i = 1; i <= totalNumberReward.current(); i++) {
            if(rewardTokens[i].addressToken == _addressToken) {
                indexOfTokenReward = i;
                break;
            }
        }
    }

    function getTotalNumberReward() public view returns(uint256) {
        return totalNumberReward.current();
    }

    function updateAdmin(address _adminAddr, bool _flag) external onlyAdmin {
        require(_adminAddr != address(0), "INVALID ADDRESS.");
        if (_flag) {
            admins.add(_adminAddr);
        } else {
            admins.remove(_adminAddr);
        }
    }

    function getAdmins() external view returns (address[] memory) {
        return admins.values();
    }

    function checkRamdomNumber(uint256 _ramdomWithLimitValue) public view returns(bool){
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

        if(firstRamdomValue == secondRamdomValue) {
            return true;
        } else {
            return false;
        }
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
