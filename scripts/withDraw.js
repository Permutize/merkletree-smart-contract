// scripts/claim-many.js
import hre from "hardhat";
import fs from "fs";

async function main() {
    const address = fs.readFileSync("deployed_address.txt", "utf8").trim();
    const distributor = await hre.ethers.getContractAt("MultiTokenDistributor", '0xB40F9CA3172b5F30BD4ba0b033c59D69E192dc25');
    const tokenAddresses = [
'0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
    ];
    const tx = await distributor.withdrawAll(tokenAddresses);
    console.log(`⏳ Tx sent: ${tx.hash}`);
    await tx.wait()

    console.log("✅ All tokens claimed successfully!");
}

main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
});
