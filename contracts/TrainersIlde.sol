// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract TrainersIDLE is AccessControl {
    event Join(address, uint256, uint256);
    event CollectIDLEPoints(address, uint256, uint256);
    event CollectTransactionPoints(address, uint256, uint256);
    event BuyImprovement(address, uint256, uint256);

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
        uint256 rewardsBalance;
        EntityData userData;
        EntityData trainerData;
        IDLEConfiguration idleConfig;
        Improvement[] uImprovements;
        Improvement[] tImprovements;
        bool[] userImprovements;
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
    mapping(uint256 => Improvement) private pImprovements_;
    mapping(uint256 => Improvement) private tImprovements_;
    mapping(address => EntityData) private usersData_;
    mapping(uint256 => EntityData) private trainersData_;
    mapping(address => mapping(uint256 => bool)) private bUserImprovements_;
    mapping(uint256 => mapping(uint256 => bool)) private bTrainerImprovements_;
    mapping(uint256 => uint8) private rewardsP_;

    constructor(address _trainersContract) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        trainers_ = IERC721(_trainersContract);
        config_.startBlock = block.number;
    }

    function getContractData(
        address _user,
        uint256 _from,
        uint256 _to,
        uint256 _trainer
    ) public view returns (ContractData memory) {
        return
            ContractData(
                address(this).balance,
                getUserData(_user),
                getTrainerData(_trainer),
                config_,
                getImprovements(_from, _to),
                getTrainersImprovements(_from, _to),
                getUserImprovements(_from, _to, _user),
                getTrainerImprovements(_from, _to, _trainer),
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

    function getUserData(
        address _user
    ) public view returns (EntityData memory) {
        return usersData_[_user];
    }

    function getTrainerData(
        uint256 _t
    ) public view returns (EntityData memory) {
        return trainersData_[_t];
    }

    function getImprovements(
        uint256 _from,
        uint256 _to
    ) public view returns (Improvement[] memory) {
        uint256 _l = _to - _from;
        Improvement[] memory _improvements = new Improvement[](_l);
        for (uint256 i = 0; i < _l; i++) _improvements[i] = pImprovements_[i];
        return _improvements;
    }

    function getTrainersImprovements(
        uint256 _from,
        uint256 _to
    ) public view returns (Improvement[] memory) {
        uint256 _l = _to - _from;
        Improvement[] memory _i = new Improvement[](_l);
        for (uint256 i = 0; i < _l; i++) _i[i] = tImprovements_[i];
        return _i;
    }

    function getTrainerImprovements(
        uint256 _from,
        uint256 _to,
        uint256 _t
    ) public view returns (bool[] memory) {
        uint256 _l = _to - _from;
        bool[] memory _i = new bool[](_l);
        for (uint256 i = 0; i < _l; i++) _i[i] = bTrainerImprovements_[_t][i];
        return _i;
    }

    function getUserImprovements(
        uint256 _from,
        uint256 _to,
        address _user
    ) public view returns (bool[] memory) {
        uint256 _l = _to - _from;
        bool[] memory _i = new bool[](_l);
        for (uint256 i = 0; i < _l; i++) _i[i] = bUserImprovements_[_user][i];
        return _i;
    }

    // The function returns if a trainer is active on the game
    // It will be 0 when the user restarts the trainer on the new game every week
    function isActive(uint256 _trainer) public view returns (bool) {
        return blockStartTracker_[_trainer] == 0;
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

    function transactionPoints(address _o) public view returns (uint256) {
        return config_.pPerTrans * usersData_[_o].mult;
    }

    // It only works for the user improvements, the users will decide if they want to make trainers or users improvements
    function userHadImprovement(
        address _o,
        uint256 _i
    ) public view returns (bool) {
        return bUserImprovements_[_o][_i];
    }

    // Validate if a traiuner already have an improvement
    function trainerHadImprovement(
        uint256 _t,
        uint256 _i
    ) public view returns (bool) {
        return bTrainerImprovements_[_t][_i];
    }

    // Validate if an user has enought points to buy user improvements
    function hasEnoughtForUserI(
        address _o,
        uint256 _i
    ) public view returns (bool) {
        return usersData_[_o].points > pImprovements_[_i].value;
    }

    // Validate if an user has enought points to buy trainer improvements
    function hasEnoughtForTrainerI(
        address _o,
        uint256 _i
    ) public view returns (bool) {
        return usersData_[_o].points > tImprovements_[_i].value;
    }

    // Validate all conditions to get an user improvement
    function canGetItUserImprovement(
        address _o,
        uint256 _i
    ) public view returns (bool) {
        return !userHadImprovement(_o, _i) && hasEnoughtForUserI(_o, _i);
    }

    // Validate all conditions to get an trainer improvement
    function canGetItUserImprovement(
        address _o,
        uint256 _t,
        uint256 _i
    ) public view returns (bool) {
        return !trainerHadImprovement(_t, _i) && hasEnoughtForTrainerI(_o, _i);
    }

    // Setters by the admin role
    // Change the user improvement values (ADMIN_ROLE)
    function setUserImprovementValue(
        uint256 _i,
        uint256 _value,
        uint256 _mult
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pImprovements_[_i].value = _value;
        pImprovements_[_i].mult = _mult;
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
        usersData_[_owner].points += transactionPoints(_owner);
        emit CollectTransactionPoints(_owner, _trainer, block.timestamp);
    }

    // function buyImprovement(uint256 _i) external payable {
    //     require(msg.value == config_.feeMTR, MTR_FEE_ERROR);
    //     address _owner = _msgSender();
    //     require(canGetIt(_owner, _i), CANT_GET_IT);
    //     boughtImprovements_[_owner][_i] = true;
    //     usersData_[_owner].mult += pImprovements_[_i].mult;
    //     usersData_[_owner].points -= pImprovements_[_i].value;
    //     emit BuyImprovement(_owner, _i, block.timestamp);
    // }
}
