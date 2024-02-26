// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract TrainersIDLE is AccessControl {
    event Join(address, uint256, uint256);
    event CollectIDLEPoints(address, uint256, uint256);
    event CollectTransPoints(address, uint256, uint256);
    event BuyImprovement(address, uint256, uint256);

    struct IDLEConfiguration {
        uint256 pPerBlock;
        uint256 pPerTrans;
        uint256 feeMTR;
        uint256 startBlock;
    }

    struct Improvement {
        uint256 value;
        uint256 mult;
    }

    struct UserData {
        uint256 mult;
        uint256 points;
    }

    IERC721 public trainers_;
    IDLEConfiguration public config_;

    string public constant MTR_FEE_ERROR = "MTR_FEE_ERROR";
    string public constant OWNER_ERROR = "OWNER_ERROR";
    string public constant ACTIVE_TRAINER_ERROR = "ACTIVE_TRAINER_ERROR";
    string public constant CANT_GET_IT = "CANT_GET_IT";

    mapping(uint256 => uint256) private blockStartTracker_;
    mapping(uint256 => Improvement) private payableImprovements_;
    mapping(address => UserData) private usersData_;
    mapping(address => mapping(uint256 => bool)) private boughtImprovements_;

    constructor(address _trainersContract) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        trainers_ = IERC721(_trainersContract);
        config_.startBlock = block.number;
    }

    function isActive(uint256 _trainer) public view returns (bool) {
        return blockStartTracker_[_trainer] == 0;
    }

    function activationBlock(uint256 _trainer) public view returns (uint256) {
        return blockStartTracker_[_trainer];
    }

    function idleBlocks(uint256 _trainer) public view returns (uint256) {
        return block.number - blockStartTracker_[_trainer];
    }

    function unlockedIdlePoints(uint256 _t) public view returns (uint256) {
        address _owner = trainers_.ownerOf(_t);
        return config_.pPerBlock * idleBlocks(_t) * usersData_[_owner].mult;
    }

    function transactionPoints(uint256 _t) public view returns (uint256) {
        address _owner = trainers_.ownerOf(_t);
        return config_.pPerTrans * usersData_[_owner].mult;
    }

    function hadImprovement(address _o, uint256 _i) public view returns (bool) {
        return boughtImprovements_[_o][_i];
    }

    function hasEnought(address _o, uint256 _i) public view returns (bool) {
        return usersData_[_o].points > payableImprovements_[_i].value;
    }

    function canGetIt(address _o, uint256 _i) public view returns (bool) {
        return !hadImprovement(_o, _i) && hasEnought(_o, _i);
    }

    function setImprovementValue(
        uint256 _i,
        uint256 _value,
        uint256 _mult
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        payableImprovements_[_i].value = _value;
        payableImprovements_[_i].mult = _mult;
    }

    function setMTRFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.feeMTR = _fee;
    }

    function setPPerBlock(uint256 _v) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.pPerBlock = _v;
    }

    function setPPerTrans(uint256 _v) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.pPerTrans = _v;
    }

    function joinWithTrainer(uint256 _trainer) external payable {
        require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
        address _sender = _msgSender();
        require(!isActive(_trainer), ACTIVE_TRAINER_ERROR);
        require(trainers_.ownerOf(_trainer) == _sender, OWNER_ERROR);
        blockStartTracker_[_trainer] = block.number;
        if (usersData_[_sender].mult == 0) usersData_[_sender].mult = 1;
        emit Join(_sender, _trainer, block.timestamp);
    }

    function collectIDLEPoints(uint256 _trainer) external payable {
        require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
        require(isActive(_trainer), ACTIVE_TRAINER_ERROR);
        address _owner = trainers_.ownerOf(_trainer);
        usersData_[_owner].points += unlockedIdlePoints(_trainer);
        blockStartTracker_[_trainer] = block.number;
        emit CollectIDLEPoints(_owner, _trainer, block.timestamp);
    }

    function collectTransPoints(uint256 _trainer) external payable {
        require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
        address _owner = trainers_.ownerOf(_trainer);
        usersData_[_owner].points += transactionPoints(_trainer);
        emit CollectTransPoints(_owner, _trainer, block.timestamp);
    }

    function buyImprovement(uint256 _i) external payable {
        require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
        address _owner = _msgSender();
        require(canGetIt(_owner, _i), CANT_GET_IT);
        boughtImprovements_[_owner][_i] = true;
        usersData_[_owner].mult += payableImprovements_[_i].mult;
        usersData_[_owner].points -= payableImprovements_[_i].value;
        emit BuyImprovement(_owner, _i, block.timestamp);
    }
}
