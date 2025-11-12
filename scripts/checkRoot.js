import fs from "fs";
import hre from "hardhat";

async function checkRoot() {
    const address = fs.readFileSync("deployed_address.txt", "utf8").trim();
    const distributor = await hre.ethers.getContractAt("MultiTokenDistributor", address);

    const current = await distributor.currentRound();
    console.log("📌 Current round:", current.toString());

    for (let i = 1; i <= current; i++) {
        const root = await distributor.getMerkleRoot(i);
        console.log(`Round ${i} root: ${root}`);
    }
}
checkRoot();