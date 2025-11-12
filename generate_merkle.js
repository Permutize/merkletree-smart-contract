// scripts/generate_merkle.js
// Run: npx hardhat run scripts/generate_merkle.js
import fs from "fs";
import hre from "hardhat";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";

async function main() {
  // input file
  const inputPath = "input.json";
  let claims;

  if (fs.existsSync(inputPath)) {
    claims = JSON.parse(fs.readFileSync(inputPath, "utf8"));
  } else {
    claims = [
      {
        index: 0,
        account: "0x813E5fbBb229c88406533ef67e441ABa7e6ca5Dd",
        tokens: [
          "0xf817257fed379853cde0fa4f97ab987181b1e5ea",
          "0x0000000000000000000000000000000000000000",
        ],
        amounts: ["1000000", "100000"],
      },
    ];
  }

  const abiCoder = hre.ethers.utils.defaultAbiCoder;
  const leavesBuf = [];
  const leafHexes = [];

  // output structure
  const output = {
    root: "",
    claims: {},
  };

  let globalIndex = 99;

  // build leaves per token
  for (const c of claims) {
    console.log('claims', claims)
    const account = c.account;

    for (let i = 0; i < c.tokens.length; i++) {
      const token = c.tokens[i];
      const amount = c.amounts[i].toString();

      const encoded = abiCoder.encode(
        ["uint256", "address", "address", "uint256"],
        [globalIndex, account, token, amount]
      );

      const leaf = hre.ethers.utils.keccak256(encoded);
      leafHexes.push(leaf);
      leavesBuf.push(Buffer.from(leaf.slice(2), "hex"));

      if (!output.claims[account]) {
        output.claims[account] = [];
      }

      output.claims[account].push({
        index: globalIndex,
        token,
        amount,
        proof: [], // fill later
      });

      globalIndex++;
    }
  }

  // build Merkle tree
  const tree = new MerkleTree(leavesBuf, keccak256, {
    sortPairs: true,
    hashLeaves: false,
  });

  const rootBuf = tree.getRoot();
  const rootHex = rootBuf.length
    ? "0x" + rootBuf.toString("hex")
    : "0x" + leavesBuf[0].toString("hex");

  output.root = rootHex;

  // fill proofs
  for (const account of Object.keys(output.claims)) {
    for (let i = 0; i < output.claims[account].length; i++) {
      const { index, token, amount } = output.claims[account][i];

      const encoded = abiCoder.encode(
        ["uint256", "address", "address", "uint256"],
        [index, account, token, amount]
      );
      const leaf = hre.ethers.utils.keccak256(encoded);
      const proof = tree.getHexProof(Buffer.from(leaf.slice(2), "hex"));

      output.claims[account][i].proof = proof;
    }
  }

  fs.writeFileSync("merkle_output.json", JSON.stringify(output, null, 2));
  console.log("Leaves:");
  console.log(leafHexes);
  console.log("Merkle Root:", rootHex);
  console.log("✅ merkle_output.json generated for per-token claims.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
