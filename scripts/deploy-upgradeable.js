import hre from "hardhat";

async function main() {
  const Distributor = await hre.ethers.getContractFactory("MultiTokenDistributorUpgradeable");
  const merkleRoot = "0x0000000000000000000000000000000000000000000000000000000000000000"; // Merkle root ban đầu

  const distributor = await hre.upgrades.deployProxy(Distributor, [merkleRoot], {
    initializer: "initialize",
  });

  await distributor.deployed();

  console.log("✅ MultiTokenDistributor deployed to:", distributor.address);
}

main();
