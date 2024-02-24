// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ITrainersDeployer {
    event SendMTRFee(uint256);
    event SendTokensFee(uint256);

    struct ContractData {
        uint8 tokenBurning;
        uint8 tokenStaking;
        uint8 tokenProject;
        uint256 feeMTR;
        uint256 feeToken;
        address burning;
        address staking;
        address project;
    }

    struct PaymentData {
        uint256 burning;
        uint256 staking;
        uint256 project;
        uint256 rewards;
    }

    function setProjectAddress(address _a) public virtual;

    function setStakingAddress(address _a) public virtual;

    function setFeeWallet(address _a) public virtual;

    function setRewardsWallet(address _a) public virtual;

    function getContractData()
        public
        view
        virtual
        returns (ContractData memory);

    function mintTrainer(uint8 _model) external payable virtual;

    function getPaymentValues(
        uint256 _amount
    ) public view virtual returns (PaymentData memory);
}
