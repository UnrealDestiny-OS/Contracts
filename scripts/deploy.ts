import { ethers } from "hardhat";

async function main() {
  const trainersNFTs = await ethers.deployContract("TrainersERC721", ["Unreal Destiny Trainers", "UDTNFT"], {});

  await trainersNFTs.waitForDeployment();

  console.log(`Deployed TrainersNFT contract on ${trainersNFTs.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
