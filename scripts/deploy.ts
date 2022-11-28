import { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

const GLANGER_NFT_ADDRESS = process.env.GLANGER_NFT_ADDRESS || '';
const GLANGER_COIN_ADDRESS = process.env.GLANGER_COIN_ADDRESS || '';

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const GlangerStaking = await ethers.getContractFactory("GlangerStaking");
  const glangerStaking = await GlangerStaking.deploy(GLANGER_NFT_ADDRESS, GLANGER_COIN_ADDRESS);

  console.log("Token address:", glangerStaking.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
