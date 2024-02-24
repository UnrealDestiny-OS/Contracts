// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITrainersDeployer.sol";
import "./ITrainersERC721.sol";

contract TrainersDeployer is AccessControl, ITrainersDeployer {
    uint8 public tokenBurning_ = 20;
    uint8 public tokenStaking_ = 30;
    uint8 public tokenRewards_ = 30;
    uint8 public tokenProject_ = 20;

    uint256 public feeMTR_ = 10000000000000000;
    uint256 public feeThreshold_ = 1000000000000000000;
    uint256 public feeToken_ = 10000000000000000000000;
    uint256 public tokenThreshold_ = 100000000000000000000000;

    address public burning_ = 0x000000000000000D0e0A0D000000000000000000;
    address public staking_ = address(0);
    address public project_ = address(0);
    address public rewards_ = address(0);
    address public feeWallet_ = address(0);

    ITrainersERC721 public trainers_;
    IERC20 public token_;

    string public constant MTR_FEE_ERROR = "MTR_FEE_ERROR";
    string public constant PAY_ERROR = "PAY_ERROR";

    constructor(address _trainersContract, address _token) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        trainers_ = ITrainersERC721(_trainersContract);
        token_ = IERC20(_token);
    }

    function setProjectAddress(
        address _a
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        project_ = _a;
    }

    function setStakingAddress(
        address _a
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        staking_ = _a;
    }

    function setFeeWallet(
        address _a
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        feeWallet_ = _a;
    }

    function setRewardsWallet(
        address _a
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        rewards_ = _a;
    }

    function getPaymentValues(
        uint256 _total
    ) public view override returns (PaymentData memory) {
        return
            PaymentData(
                (tokenBurning_ * _total) / 100,
                (tokenStaking_ * _total) / 100,
                (tokenRewards_ * _total) / 100,
                (tokenProject_ * _total) / 100
            );
    }

    function validateThresholds() private {
        uint256 balance_ = token_.balanceOf(address(this));
        uint256 feeBalance = address(this).balance;

        if (balance_ >= tokenThreshold_) {
            PaymentData memory _payment = getPaymentValues(balance_);
            require(token_.transfer(burning_, _payment.burning), PAY_ERROR);
            require(token_.transfer(staking_, _payment.staking), PAY_ERROR);
            require(token_.transfer(project_, _payment.project), PAY_ERROR);
            require(token_.transfer(rewards_, _payment.rewards), PAY_ERROR);
            emit SendTokensFee(balance_);
        }

        if (feeBalance >= feeThreshold_) {
            payable(feeWallet_).transfer(feeBalance);
            emit SendMTRFee(feeBalance);
        }
    }

    function mintTrainer(uint8 _model) external payable override {
        require(msg.value == feeMTR_, MTR_FEE_ERROR);
        address _sender = _msgSender();

        require(
            token_.transferFrom(_sender, address(this), feeToken_),
            PAY_ERROR
        );

        validateThresholds();
        trainers_.mint(_sender, _model);
    }

    function getContractData()
        public
        view
        override
        returns (ContractData memory)
    {
        return
            ContractData(
                tokenBurning_,
                tokenStaking_,
                tokenProject_,
                feeMTR_,
                feeToken_,
                burning_,
                staking_,
                project_
            );
    }
}
