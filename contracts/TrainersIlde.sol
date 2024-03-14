// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract TrainersIDLE is AccessControl {
    event Join(uint256, uint256);
    event CollectIDLEPoints(uint256, uint256);
    event CollectTransactionPoints(uint256, uint256);
    event BuyImprovement(uint256, uint256);

    struct IDLEConfiguration {
        uint8 projectPercentage;
        uint256 pPerBlock;
        uint256 pPerTrans;
        uint256 feeMTR;
        uint256 startBlock;
        uint256 maxWinners;
    }

    struct Improvement {
        uint256 value;
        uint256 mult;
    }

    struct EntityData {
        uint256 mult;
        uint256 points;
    }

    struct ContractData {
        bool trainerIsActive;
        uint256 startBlock;
        uint256 currentBlock;
        uint256 rewardsBalance;
        uint256 availableIdlePoints;
        uint256 availableTransactionPoints;
        EntityData trainerData;
        IDLEConfiguration idleConfig;
        Improvement[] tImprovements;
        bool[] trainerImprovements;
        uint8[] userRewardsPercentage;
        uint256[] userRewardsValues;
    }

    IERC721 public trainers_;
    IDLEConfiguration public config_;

    string public constant MTR_FEE_ERROR = "MTR_FEE_ERROR";
    string public constant OWNER_ERROR = "OWNER_ERROR";
    string public constant ACTIVE_TRAINER_ERROR = "ACTIVE_TRAINER_ERROR";
    string public constant CANT_GET_IT = "CANT_GET_IT";

    mapping(uint256 => uint256) private blockStartTracker_;
    mapping(uint256 => Improvement) private tImprovements_;
    mapping(uint256 => EntityData) private trainersData_;
    mapping(uint256 => mapping(uint256 => bool)) private bTrainerImprovements_;
    mapping(uint256 => uint8) private rewardsP_;

    constructor(address _trainersContract) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        trainers_ = IERC721(_trainersContract);
        config_.startBlock = block.number;
    }

    function getContractData(
        uint256 _to,
        uint256 _trainer
    ) public view returns (ContractData memory) {
        return
            ContractData(
                isActive(_trainer),
                blockStartTracker_[_trainer],
                block.number,
                address(this).balance,
                unlockedIdlePoints(_trainer),
                transactionPoints(_trainer),
                getTrainerData(_trainer),
                config_,
                getTrainersImprovements(_to),
                getTrainerImprovements(_to, _trainer),
                getUsersRewardsPercentages(config_.maxWinners),
                getUserRewardsValues(config_.maxWinners)
            );
    }

    function getUsersRewardsPercentages(
        uint256 _max
    ) public view returns (uint8[] memory) {
        uint8[] memory _r = new uint8[](_max);
        for (uint256 i = 0; i < _max; i++) _r[i] = rewardsP_[i];
        return _r;
    }

    function getUserRewardsValues(
        uint256 _max
    ) public view returns (uint256[] memory) {
        uint256 _b = address(this).balance;
        uint256[] memory _r = new uint256[](_max);
        for (uint256 i = 0; i < _max; i++) _r[i] = (rewardsP_[i] * _b) / 100;
        return _r;
    }

    function getTrainerData(
        uint256 _t
    ) public view returns (EntityData memory) {
        return trainersData_[_t];
    }

    function getTrainersImprovements(
        uint256 _to
    ) public view returns (Improvement[] memory) {
        Improvement[] memory _i = new Improvement[](_to);
        for (uint256 i = 0; i < _to; i++) _i[i] = tImprovements_[i];
        return _i;
    }

    function getTrainerImprovements(
        uint256 _to,
        uint256 _t
    ) public view returns (bool[] memory) {
        bool[] memory _i = new bool[](_to);
        for (uint256 i = 0; i < _to; i++) _i[i] = bTrainerImprovements_[_t][i];
        return _i;
    }

    // The function returns if a trainer is active on the game
    // It will be 0 when the user restarts the trainer on the new game every week
    function isActive(uint256 _trainer) public view returns (bool) {
        return blockStartTracker_[_trainer] != 0;
    }

    // When the trainer was active in the block
    // It will be reset when the new game starts every week
    function activationBlock(uint256 _trainer) public view returns (uint256) {
        return blockStartTracker_[_trainer];
    }

    // How many block the trainer was active without withdraw the rewards
    function idleBlocks(uint256 _trainer) public view returns (uint256) {
        return block.number - blockStartTracker_[_trainer];
    }

    // How many points the users can withdraw based on the multiplier and on the idle blocks
    // Also the variable depends on how many points the users can get per block
    function unlockedIdlePoints(uint256 _t) public view returns (uint256) {
        return config_.pPerBlock * idleBlocks(_t) * trainersData_[_t].mult;
    }

    function transactionPoints(uint256 _t) public view returns (uint256) {
        return config_.pPerTrans * trainersData_[_t].mult;
    }

    // Validate if a traiuner already have an improvement
    function trainerHadImprovement(
        uint256 _t,
        uint256 _i
    ) public view returns (bool) {
        return bTrainerImprovements_[_t][_i];
    }

    // Validate if an user has enought points to buy trainer improvements
    function hasEnoughtForTrainerI(
        uint256 _t,
        uint256 _i
    ) public view returns (bool) {
        return trainersData_[_t].points >= tImprovements_[_i].value;
    }

    // Validate all conditions to get an trainer improvement
    function canGetItTrainerImprovement(
        uint256 _t,
        uint256 _i
    ) public view returns (bool) {
        return !trainerHadImprovement(_t, _i) && hasEnoughtForTrainerI(_t, _i);
    }

    // Change the trainer improvement values (ADMIN_ROLE)
    function setTrainerImprovementValue(
        uint256 _i,
        uint256 _value,
        uint256 _mult
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tImprovements_[_i].value = _value;
        tImprovements_[_i].mult = _mult;
    }

    // Change config values
    function setMTRFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.feeMTR = _fee;
    }

    function setPPerBlock(uint256 _v) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.pPerBlock = _v;
    }

    function setPPerTrans(uint256 _v) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.pPerTrans = _v;
    }

    function setMaxWinners(uint256 _i) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.maxWinners = _i;
    }

    function setPPercentage(uint8 _p) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.projectPercentage = _p;
    }

    function setRewardsP(
        uint256 _i,
        uint8 _p
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardsP_[_i] = _p;
    }

    // Executions
    // All the users function to join, buy or interact with the game

    function joinWithTrainer(uint256 _trainer) external payable {
        require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
        require(!isActive(_trainer), ACTIVE_TRAINER_ERROR);
        require(trainers_.ownerOf(_trainer) == _msgSender(), OWNER_ERROR);
        blockStartTracker_[_trainer] = block.number;
        if (trainersData_[_trainer].mult == 0) trainersData_[_trainer].mult = 1;
        emit Join(_trainer, block.timestamp);
    }

    function collectIDLEPoints(uint256 _trainer) external payable {
        require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
        require(isActive(_trainer), ACTIVE_TRAINER_ERROR);
        trainersData_[_trainer].points += unlockedIdlePoints(_trainer);
        blockStartTracker_[_trainer] = block.number;
        emit CollectIDLEPoints(_trainer, block.timestamp);
    }

    function collectTransPoints(uint256 _trainer) external payable {
        require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
        trainersData_[_trainer].points += transactionPoints(_trainer);
        emit CollectTransactionPoints(_trainer, block.timestamp);
    }

    function buyTrainerImprovement(uint256 _t, uint256 _i) external payable {
        require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
        require(canGetItTrainerImprovement(_t, _i), CANT_GET_IT);
        bTrainerImprovements_[_t][_i] = true;
        trainersData_[_t].mult += tImprovements_[_i].mult;
        trainersData_[_t].points -= tImprovements_[_i].value;
        emit BuyImprovement(_i, block.timestamp);
    }
}
