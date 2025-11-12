import { ethers } from "ethers";

// Input
const index = 273;
const account = "0xad4bc536ca88e1f904abb9038519ace549945484";
const token = "0xe0590015a873bf326bd645c3e1266d4db41c4e6b";
const amount = "809959479391151";

const root = "0x58368898f38f68943be7fc399e63389c71dd84c0313c597ac7e80035d858b9fa";


const proof = [
  "0x4739e2e18563918fb293c1e4c8117f4dbef73d6b01b49fd67c8e4d975c257f87",
  "0xfef50fb3ddce5296bf7e5d95bfbed5e59e6d0deb5877f05e6f4c88a7cfd7ecdc",
  "0x9f4739dddb25546d3681534b75630eafb9ae64b10438a70491b8b27597a26283",
  "0x17751d03ec0f69904473dcec95ff93d6d794a25dd1399ea208418a2d4111d30c"
];
// 1. Tạo leaf
const leaf = ethers.utils.keccak256(
  ethers.utils.defaultAbiCoder.encode(
    ["uint256", "address", "address", "uint256"],
    [index, account, token, amount]
  )
);
console.log("leaf:", leaf);

// 2. Verify proof
function verifyProof(leaf, proof, root) {
  let hash = leaf;
  for (let p of proof) {
    if (hash.toLowerCase() < p.toLowerCase()) {
      hash = ethers.utils.keccak256(
        ethers.utils.solidityPack(["bytes32", "bytes32"], [hash, p])
      );
    } else {
      hash = ethers.utils.keccak256(
        ethers.utils.solidityPack(["bytes32", "bytes32"], [p, hash])
      );
    }
  }
  return { computed: hash, match: hash.toLowerCase() === root.toLowerCase() };
}

console.log(verifyProof(leaf, proof, root));
