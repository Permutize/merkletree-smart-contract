const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

const claimsPath = path.join(__dirname, "..", "claims.json");
const outDir = path.join(__dirname, "..", "test", "generated");
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

const claims = JSON.parse(fs.readFileSync(claimsPath, "utf8"));

// build leaves: keccak256(abi.encode(index, account, token, amount))
function encodeLeaf(c) {
  const abiCoder = ethers.utils.defaultAbiCoder;
  const encoded = abiCoder.encode(
    ["uint256", "address", "address", "uint256"],
    [c.index, c.account, c.token, c.amount.toString()]
  );
  return Buffer.from(ethers.utils.keccak256(encoded).slice(2), "hex");
}

const leaves = claims.map(encodeLeaf);
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const root = tree.getHexRoot();

let sol = `// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library MerkleData {
    function MERKLE_ROOT() internal pure returns (bytes32) {
        return ${root};
    }

    function COUNT() internal pure returns (uint256) {
        return ${claims.length};
    }

`;

for (let i = 0; i < claims.length; i++) {
  const c = claims[i];
  const accountAddr = ethers.utils.getAddress(c.account);
  const tokenAddr = ethers.utils.getAddress(c.token);
  const leaf = encodeLeaf(c);
  const proof = tree.getHexProof(leaf);
  const proofLen = proof.length;

  let proofSol = `new bytes32[](${proofLen})`;
  let proofAssign = "";

  if (proofLen > 0) {
    proofAssign = proof
      .map((p, idx) => `        proof[${idx}] = bytes32(${JSON.stringify(p)});`)
      .join("\n");
  }

  sol += `    function getClaim_${i}() internal pure returns (uint256 index, address account, address token, uint256 amount, bytes32[] memory proof) {
        index = ${c.index};
        account = ${accountAddr};
        token = ${tokenAddr};
        amount = ${c.amount};
        proof = ${proofSol};
${proofAssign ? proofAssign + "\n" : ""}        return (index, account, token, amount, proof);
    }

`;
}

// ✅ Thêm hàm getClaim(i)
sol += `    function getClaim(uint256 i) internal pure returns (uint256, address, address, uint256, bytes32[] memory) {
`;

for (let i = 0; i < claims.length; i++) {
  sol += `        if (i == ${i}) return getClaim_${i}();\n`;
}

sol += `        revert("Invalid claim index");
    }
}
`;

fs.writeFileSync(path.join(outDir, "MerkleData.sol"), sol, "utf8");
console.log("✅ Wrote", path.join(outDir, "MerkleData.sol"));
