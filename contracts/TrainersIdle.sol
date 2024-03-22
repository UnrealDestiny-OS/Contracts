// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract TrainersIDLE is AccessControl {
    event Join(uint256, uint256);
    event CollectIDLEPoints(uint256, uint256, uint256);
    event CollectTransactionPoints(uint256, uint256, uint256);
    event BuyImprovement(uint256, uint256, uint256, uint256);
    event InjectFeeBalance(address, uint256, uint256);
    event WithdrawBalance(address, uint256, uint256);
    event TakeFees(address, uint256, uint256, uint256);

    struct IDLEConfiguration {
        uint8 projectPercentage;
        uint8 injectPercentage;
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
        uint256 userFeesBalance;
        uint256 takedFees;
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
    string public constant MTR_SEND_ERROR = "MTR_SEND_ERROR";
    string public constant OWNER_ERROR = "OWNER_ERROR";
    string public constant ACTIVE_TRAINER_ERROR = "ACTIVE_TRAINER_ERROR";
    string public constant CANT_GET_IT = "CANT_GET_IT";

    mapping(uint256 => uint256) private blockStartTracker_;
    mapping(uint256 => Improvement) private tImprovements_;
    mapping(uint256 => EntityData) private trainersData_;
    mapping(uint256 => mapping(uint256 => bool)) private bTrainerImprovements_;
    mapping(uint256 => uint8) private rewardsP_;

    //Users accounts
    mapping(address => uint256) private feeBalance_;

    uint256 private gameRewards_;
    uint256 private takedFees_;
    address private executor_;

    bytes32 public constant EXECUTOR = keccak256("EXECUTOR");

    constructor(address _trainersContract) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        trainers_ = IERC721(_trainersContract);
        config_.startBlock = block.number;
    }

    function setExecutor(address _e) external onlyRole(DEFAULT_ADMIN_ROLE) {
        executor_ = _e;
        _grantRole(EXECUTOR, executor_);
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
                feeBalance_[trainers_.ownerOf(_trainer)],
                takedFees_,
                gameRewards_,
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

    function getUserFeesBalance(address _e) external view returns (uint256) {
        return feeBalance_[_e];
    }

    function getTakedFees() external view returns (uint256) {
        return takedFees_;
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

    function setPercentages(
        uint8 _project,
        uint8 _inject
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config_.projectPercentage = _project;
        config_.injectPercentage = _inject;
    }

    function setRewardsP(
        uint256 _i,
        uint8 _p
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardsP_[_i] = _p;
    }

    // Executions
    // All the users function to join, buy or interact with the game

    function joinWithTrainer(
        address _e,
        uint256 _trainer
    ) external onlyRole(EXECUTOR) {
        takeFees(_e);
        require(!isActive(_trainer), ACTIVE_TRAINER_ERROR);
        require(trainers_.ownerOf(_trainer) == _e, OWNER_ERROR);
        blockStartTracker_[_trainer] = block.number;
        if (trainersData_[_trainer].mult == 0) trainersData_[_trainer].mult = 1;
        emit Join(_trainer, block.timestamp);
    }

    function collectIDLEPoints(
        address _e,
        uint256 _trainer
    ) external onlyRole(EXECUTOR) {
        takeFees(_e);
        require(isActive(_trainer), ACTIVE_TRAINER_ERROR);
        trainersData_[_trainer].points += unlockedIdlePoints(_trainer);
        blockStartTracker_[_trainer] = block.number;
        emit CollectIDLEPoints(
            _trainer,
            trainersData_[_trainer].points,
            block.timestamp
        );
    }

    function collectTransPoints(
        address _e,
        uint256 _trainer
    ) external onlyRole(EXECUTOR) {
        takeFees(_e);
        trainersData_[_trainer].points += transactionPoints(_trainer);
        emit CollectTransactionPoints(
            _trainer,
            trainersData_[_trainer].points,
            block.timestamp
        );
    }

    function buyTrainerImprovement(
        address _e,
        uint256 _t,
        uint256 _i
    ) external onlyRole(EXECUTOR) {
        takeFees(_e);
        require(canGetItTrainerImprovement(_t, _i), CANT_GET_IT);
        bTrainerImprovements_[_t][_i] = true;
        trainersData_[_t].mult += tImprovements_[_i].mult;
        trainersData_[_t].points -= tImprovements_[_i].value;
        emit BuyImprovement(
            _i,
            trainersData_[_t].mult,
            trainersData_[_t].points,
            block.timestamp
        );
    }

    // Accounts managers

    function injectBalance() external payable {
        address _sender = _msgSender();
        uint256 _feeMTR = (config_.injectPercentage * msg.value) / 100;
        uint256 _agregatedValue = msg.value - _feeMTR;
        takedFees_ += _feeMTR;
        feeBalance_[_sender] += _agregatedValue;
        emit InjectFeeBalance(_sender, feeBalance_[_sender], block.timestamp);
    }

    function withdrawBalance(uint256 _balance) external {
        address _sender = _msgSender();
        require(feeBalance_[_sender] >= _balance, MTR_FEE_ERROR);
        uint256 _feeMTR = (config_.injectPercentage * _balance) / 100;
        uint256 _withdrawnFees = _balance - _feeMTR;
        takedFees_ += _feeMTR;
        feeBalance_[_sender] -= _balance;
        (bool sent, ) = _sender.call{value: _withdrawnFees}("");
        require(sent, MTR_SEND_ERROR);
        emit WithdrawBalance(_sender, feeBalance_[_sender], block.timestamp);
    }

    function takeFees(address _e) private {
        uint256 _totalFee = config_.feeMTR;
        require(feeBalance_[_e] >= _totalFee, MTR_FEE_ERROR);
        uint256 _projectFee = (config_.projectPercentage * _totalFee) / 100;
        uint256 _fee = _totalFee - _projectFee;
        feeBalance_[_e] -= _totalFee;
        takedFees_ += _projectFee;
        gameRewards_ += _fee;
        emit TakeFees(_e, feeBalance_[_e], takedFees_, gameRewards_);
    }

    function sendFeesToExecutor() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool sent, ) = executor_.call{value: takedFees_}("");
        require(sent, MTR_SEND_ERROR);
        takedFees_ = 0;
    }
}
