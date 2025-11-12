import fs from "fs";
import hre from "hardhat";

async function main() {
  // Đọc địa chỉ contract đã deploy
  // const address = fs.readFileSync("deployed_address.txt", "utf8").trim();
  const address = '0x62c60E1f71feb81bB2efE5d7049097d6668DB5DC';
  
  console.log("Using distributor at:", address);

  // Đọc Merkle root mới
  const out = JSON.parse(fs.readFileSync("merkle_output.json", "utf8"));
  const root = out.root;
  console.log("Adding new round with root:", root);

  // Kết nối contract
  const Distributor = await hre.ethers.getContractFactory("MultiTokenDistributor");
  const distributor = Distributor.attach(address);

  // Gọi setMerkleRoot
  const tx = await distributor.setMerkleRoot(root);
  console.log("⏳ Sending transaction:", tx.hash);
  await tx.wait();

  console.log("✅ Round added successfully!");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});