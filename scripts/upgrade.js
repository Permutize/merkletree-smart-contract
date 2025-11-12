import hre from "hardhat";
async function main() {
  const newImpl = await hre.ethers.getContractFactory("MultiTokenDistributorUpgradeableV2");
  const proxyAddress = "0x62c60E1f71feb81bB2efE5d7049097d6668DB5DC";

  await hre.upgrades.upgradeProxy(proxyAddress, newImpl);
  console.log("✅ Upgraded to V2 successfully");
}

main();
