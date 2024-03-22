import { ethers } from "hardhat";
import { GenerateDeployementFile } from "./deploymentGenerator";
import FS from "fs";

async function main() {
  const token = await ethers.deployContract("UDToken", [], {});
  const trainersNFTs = await ethers.deployContract("TrainersERC721", ["Unreal Destiny Trainers", "UDTNFT"], {});
  const trainersDeployer = await ethers.deployContract("TrainersDeployer", [trainersNFTs.target, token.target], {});
  const trainersIdle = await ethers.deployContract("TrainersIDLE", [trainersNFTs.target], {});

  await token.waitForDeployment();
  await trainersNFTs.waitForDeployment();
  await trainersDeployer.waitForDeployment();
  await trainersIdle.waitForDeployment();

  await trainersNFTs.grantRole(await trainersNFTs.DEPLOYER(), trainersDeployer.target);

  GenerateDeployementFile({
    UDToken: { address: token.target.toString(), abiPath: "Token.sol/UDToken.json" },
    TrainersERC721: { address: trainersNFTs.target.toString(), abiPath: "TrainersERC721.sol/TrainersERC721.json" },
    TrainersDeployer: { address: trainersDeployer.target.toString(), abiPath: "TrainersDeployer.sol/TrainersDeployer.json" },
    TrainersIDLE: { address: trainersIdle.target.toString(), abiPath: "TrainersIdle.sol/TrainersIDLE.json" },
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
