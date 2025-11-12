import fs from "fs";
import hre from "hardhat";

async function main() {
  // Deploy contract
  console.log("✅ Start deploying MultiTokenDistributor...");

  const Distributor = await hre.ethers.getContractFactory("MultiTokenDistributor");
  console.log("⏳ Deploying, please wait...");
  const distributor = await Distributor.deploy('0x0000000000000000000000000000000000000000000000000000000000000000');
  // Đợi deploy xong
  await distributor.deployed();
  
  // console.log("📌 Deploy tx sent:", distributor.deploymentTransaction().hash);
  console.log('distributor')
  const address = distributor.address;
  console.log("✅ MultiRoundDistributor deployed to:", address);

  // Lưu địa chỉ ra file
  fs.writeFileSync("deployed_address.txt", address);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});