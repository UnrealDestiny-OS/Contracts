import { expect } from "chai";
import { ethers } from "hardhat";
import { TrainersDeployer, TrainersERC721, UDToken } from "../typechain-types";

const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Trainers Deployer", function () {
  async function deployFixture() {
    const token = await ethers.deployContract("UDToken", [], {});
    const trainersNFT = await ethers.deployContract("TrainersERC721", ["Unreal Destiny Trainers", "UDTNFT"], {});
    const trainersDeployer = await ethers.deployContract("TrainersDeployer", [trainersNFT.target, token.target], {});
    return { token, trainersNFT, trainersDeployer };
  }

  async function setAddressesFixture() {
    const { trainersDeployer } = await loadFixture(deployFixture);
    const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    const pTrainersDeployer = trainersDeployer as TrainersDeployer;

    await pTrainersDeployer.setProjectAddress(addr2);
    await pTrainersDeployer.setStakingAddress(addr3);
    await pTrainersDeployer.setRewardsWallet(addr4);

    return [];
  }

  describe("Configuration", function () {
    it("The contract fee percentages are correct", async function () {
      const { trainersDeployer } = await loadFixture(deployFixture);

      const pTrainersDeployer = trainersDeployer as TrainersDeployer;

      const deployerData = await pTrainersDeployer.getContractData();

      expect(await deployerData.tokenBurning).to.equal(20);
      expect(await deployerData.tokenStaking).to.equal(30);
      expect(await deployerData.tokenRewards).to.equal(30);
      expect(await deployerData.tokenProject).to.equal(20);
    });

    it("The NFT contract add the deployer role correctly", async function () {
      const { trainersNFT, trainersDeployer } = await loadFixture(deployFixture);

      const pTrainersNFT = trainersNFT as TrainersERC721;
      const pTrainersDeployer = trainersDeployer as TrainersDeployer;
      const deployedRole = await pTrainersNFT.DEPLOYER();

      await pTrainersNFT.grantRole(deployedRole, pTrainersDeployer.target);

      expect(await pTrainersNFT.hasRole(deployedRole, pTrainersDeployer.target)).to.equal(true);
    });

    it("The addresses are setted correctly", async function () {
      const { trainersDeployer } = await loadFixture(deployFixture);

      const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

      const pTrainersDeployer = trainersDeployer as TrainersDeployer;

      await pTrainersDeployer.setProjectAddress(addr2);
      await pTrainersDeployer.setStakingAddress(addr3);
      await pTrainersDeployer.setRewardsWallet(addr4);

      expect(await pTrainersDeployer.feeWallet_()).to.equal(addr1);
      expect(await pTrainersDeployer.project_()).to.equal(addr2);
      expect(await pTrainersDeployer.staking_()).to.equal(addr3);
      expect(await pTrainersDeployer.rewards_()).to.equal(addr4);
      expect(await pTrainersDeployer.burning_()).to.equal("0x000000000000000D0e0A0D000000000000000000");
    });

    it("All payment values are correct", async function () {
      const { trainersDeployer } = await loadFixture(deployFixture);

      const pTrainersDeployer = trainersDeployer as TrainersDeployer;

      const paymentInWEI = await pTrainersDeployer.feeToken_();
      const burningTotal = ((await pTrainersDeployer.tokenBurning_()) * paymentInWEI) / BigInt(100);
      const stakingTotal = ((await pTrainersDeployer.tokenStaking_()) * paymentInWEI) / BigInt(100);
      const rewardsTotal = ((await pTrainersDeployer.tokenRewards_()) * paymentInWEI) / BigInt(100);
      const projectTotal = ((await pTrainersDeployer.tokenProject_()) * paymentInWEI) / BigInt(100);

      const paymentValues = await pTrainersDeployer.getPaymentValues(paymentInWEI);

      expect(paymentValues.burning).to.be.equal(burningTotal);
      expect(paymentValues.staking).to.be.equal(stakingTotal);
      expect(paymentValues.rewards).to.be.equal(rewardsTotal);
      expect(paymentValues.project).to.be.equal(projectTotal);
    });
  });

  describe("Execution", () => {
    it("The deployer can mint an NFT, the user should have a new balance when he mint a trainer", async function () {
      const { token, trainersDeployer, trainersNFT } = await loadFixture(deployFixture);

      const [owner] = await ethers.getSigners();

      const pTrainersDeployer = trainersDeployer as TrainersDeployer;
      const pTrainersNFT = trainersNFT as TrainersERC721;
      const pToken = token as UDToken;

      await pToken.approve(pTrainersDeployer.target, await pToken.balanceOf(owner));
      await pTrainersNFT.grantRole(await pTrainersNFT.DEPLOYER(), pTrainersDeployer.target);

      const oldTokens = Number(await pTrainersNFT.balanceOf(owner));

      await pTrainersDeployer.mintTrainer(1, { value: await pTrainersDeployer.feeMTR_() });

      expect(Number(await pTrainersNFT.balanceOf(owner)) === oldTokens + 1).to.equal(true);
    });

    it("The thresholds validator has an execution when the contract reaches the threshold values (Only tokens fee, not gas fee)", async function () {
      const { token, trainersDeployer, trainersNFT } = await loadFixture(deployFixture);
      const {} = await loadFixture(setAddressesFixture);

      const [owner] = await ethers.getSigners();

      const pTrainersDeployer = trainersDeployer as TrainersDeployer;
      const pTrainersNFT = trainersNFT as TrainersERC721;
      const pToken = token as UDToken;

      await pToken.approve(pTrainersDeployer.target, await pToken.balanceOf(owner));
      await pTrainersNFT.grantRole(await pTrainersNFT.DEPLOYER(), pTrainersDeployer.target);

      const threshold = await pTrainersDeployer.tokenThreshold_();
      const amountPerTrainer = await pTrainersDeployer.feeToken_();

      let reachedThreshold = false;
      let totalExecutions = 0;

      for (let i = 0; i < 100; i++) {
        await pTrainersDeployer.mintTrainer(1, { value: await pTrainersDeployer.feeMTR_() });

        let totalTokens = await pToken.balanceOf(pTrainersDeployer.target);

        totalExecutions++;

        if (totalTokens === BigInt(0) && !reachedThreshold) {
          reachedThreshold = true;
          break;
        }
      }

      expect(threshold / amountPerTrainer).to.be.equal(BigInt(totalExecutions));
    });
  });
});
