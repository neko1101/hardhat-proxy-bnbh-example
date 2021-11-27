const { ethers, upgrades } = require("hardhat");

async function main() {
  const BNBHeroToken = await ethers.getContractFactory("BNBHeroToken");
  const bnbHeroToken = await BNBHeroToken.deploy();
  await bnbHeroToken.deployed();
  console.log("bnbHeroToken deployed to:", bnbHeroToken.address);

  // Pool
  const BNBHPool = await ethers.getContractFactory("BNBHPool");
  const bnbhPool = await BNBHPool.deploy();
  await bnbhPool.deployed();
  console.log("bnbhPool deployed to:", bnbhPool.address);

  // Char
  const BNBHCharacter = await ethers.getContractFactory("BNBHCharacter");
  const bnbhCharacter = await upgrades.deployProxy(BNBHCharacter);
  await bnbhCharacter.deployed();
  console.log("bnbhCharacter deployed to:", bnbhCharacter.address);

  // Oracle
  const BNBHPriceOracle = await ethers.getContractFactory("BNBHPriceOracle");
  const bnbhPriceOracle = await upgrades.deployProxy(BNBHPriceOracle, [bnbHeroToken.address]);
  await bnbhPriceOracle.deployed();
  console.log("bnbhPriceOracle deployed to:", bnbhPriceOracle.address);

  // ChainLink Randoms
  const Randoms = await ethers.getContractFactory("ChainlinkRandoms");
  const randoms = await Randoms.deploy("0xa555fC018435bef5A13C6c6870a9d4C11DEC329C", "0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06", "0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186", "100000000000000000");
  await randoms.deployed();
  console.log("randoms deployed to:", randoms.address);

  // BNBHero
  const BNBHero = await ethers.getContractFactory("BNBHero");
  const bnbHero = await upgrades.deployProxy(BNBHero, [bnbHeroToken.address, bnbhCharacter.address, bnbhPool.address, bnbhPriceOracle.address, randoms.address]);
  await bnbHero.deployed();
  console.log("bnbHero deployed to:", bnbHero.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
