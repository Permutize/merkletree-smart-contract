// scripts/claim-many.js
import hre from "hardhat";
import fs from "fs";

async function main() {
  // const address = fs.readFileSync("deployed_address.txt", "utf8").trim();
  const address = '0x62c60E1f71feb81bB2efE5d7049097d6668DB5DC';
  const distributor = await hre.ethers.getContractAt("MultiTokenDistributor", address);

  const out = JSON.parse(fs.readFileSync("merkle_output.json", "utf8"));
  const account = Object.keys(out.claims)[0];
  const claims = out.claims[account];

  const indices = claims.map((c) => c.index);
  const tokens = claims.map((c) => c.token);
  const amounts = claims.map((c) => c.amount);
  const proofs = claims.map((c) => c.proof);

  console.log(`📦 Checking ${claims.length} claims for ${account}`);
  console.log(`Merkle root: ${out.root}`);

  // try {
  //   // ✅ Step 1: simulate call (dry-run)
  //   const a = await distributor.callStatic.claimMany(indices, account, tokens, amounts, proofs);
  //   console.log(a);
  //   console.log("✅ Simulation success — Merkle proofs are valid!");
  // } catch (err) {
  //   console.error("❌ Simulation failed! Proof hoặc dữ liệu có thể sai:");
  //   console.error(err);
  //   process.exit(1);
  // }

  // ✅ Step 2: send transaction
  console.log("🚀 Sending transaction to claim all tokens...");
  const tx = await distributor.claimMany(indices, account, tokens, amounts, proofs);
  console.log(`⏳ Tx sent: ${tx.hash}`);
  await tx.wait();

  console.log("✅ All tokens claimed successfully!");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
