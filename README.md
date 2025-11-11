# MultiTokenDistributor

Foundry scaffold for `MultiTokenDistributor` with a Node script to generate Merkle tree + Solidity helper for tests.

Quick start:
1. Install Foundry (https://book.getfoundry.sh/)
2. Clone and run `npm install`
3. `forge install OpenZeppelin/openzeppelin-contracts@v4.9.6`
    `forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.6`
4. Run `npm run test` (this runs `node scripts/generateMerkle.js` then `forge test`)

Notes:
- The Node script writes `test/generated/MerkleData.sol` from `claims.json`.
- The sample `claims.json` references a token address `0x...1` — in tests we use a test ERC20 and don't rely on real token addresses.



# 🪂 MultiTokenDistributor-Doc

**MultiTokenDistributor** is an upgradeable smart contract for **Merkle-based token and ETH distribution**.  
It allows users to **claim multiple tokens (and ETH)** in a single transaction — ideal for **airdrops**, **reward distributions**, or **refund campaigns**.

---

## 🧩 Key Features

### 🎁 Token & ETH Distribution
- Supports both **ERC20 tokens** and **ETH**.
- Each claimable reward is defined by:
  ```solidity
  keccak256(abi.encode(index, account, token, amount))
  ```
- The Merkle tree is generated off-chain and verified on-chain.

### 🧺 Batch Claim
- `claimMany()` lets users claim **multiple rewards** (different tokens or ETH) in one transaction.
- Reduces gas cost and improves user experience.

### 🔐 Merkle Proof Verification
- The contract stores a single `merkleRoot` hash.
- Each claim is verified via `MerkleProofUpgradeable` from OpenZeppelin.
- Only addresses included in the tree can successfully claim.

### 🛑 Security & Safety
- **`ReentrancyGuardUpgradeable`**: protects from reentrancy attacks.  
- **`PausableUpgradeable`**: allows the owner to pause the contract in emergencies.  
- **`OwnableUpgradeable`**: restricts admin actions like updating roots or withdrawals.  
- Tracks claimed indexes to **prevent double claims**.

### 💸 Asset Management
- `withdrawAll()` lets the owner withdraw any unclaimed ETH or ERC20 tokens.
- Accepts ETH transfers directly via `receive()` and `fallback()` functions.

---

## ⚙️ Tech Stack

| Component | Description |
|------------|-------------|
| **Solidity** | Smart contract programming language |
| **OpenZeppelin Upgradeable** | Secure framework for proxy-based upgradeable contracts |
| **MerkleProofUpgradeable** | Library for Merkle proof validation |
| **SafeERC20Upgradeable** | Safe wrapper for ERC20 token operations |
| **Hardhat / Foundry** | Suggested tools for deployment and testing |
| **merkletreejs (Node.js)** | Generates Merkle tree & proofs off-chain |
| **ethers.js / web3.js** | Client-side or backend interaction library |

---

## 🧠 Merkle Tree (off-chain)

Each **leaf node** in the Merkle tree is built as:
```solidity
keccak256(abi.encode(index, account, token, amount))
```

Example dataset:
| index | account | token | amount |
|-------|----------|--------|--------|
| 0 | 0x123...abc | 0x000...000 (ETH) | 1 ether |
| 1 | 0x456...def | 0xTokenAddr | 1000e18 |

Merkle root can be updated via:
```solidity
setMerkleRoot(bytes32 newRoot)
```

Users must provide their **proof** (array of hashes) to claim rewards.

---

## 🚀 Deployment

### 1️⃣ Install dependencies
```bash
npm install
```

### 2️⃣ Deploy the contract (Hardhat example)
```bash
npx hardhat run scripts/deploy.js --network <your_network>
```

Initializer:
```solidity
initialize(bytes32 _merkleRoot)
```

### 3️⃣ Update Merkle Root
```solidity
setMerkleRoot(newRoot)
```

---

## 🧾 Example: Claim Multiple Tokens

```js
await distributor.claimMany(
  [0, 1],                                // indices
  user.address,                          // account
  [ETH_ADDRESS, TOKEN_ADDRESS],          // token addresses (ETH = address(0))
  [ethers.utils.parseEther("1"), "1000"],// amounts
  [proof1, proof2]                       // Merkle proofs
);
```

---

## 🔍 Quick Test (Hardhat)

```js
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

const leaves = [
  keccak256(ethers.utils.defaultAbiCoder.encode(['uint256','address','address','uint256'], [0, user.address, ETH_ADDRESS, ethers.utils.parseEther('1')]))
];
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const proof = tree.getHexProof(leaves[0]);

await distributor.claim(0, user.address, ETH_ADDRESS, ethers.utils.parseEther('1'), proof);
```

---

## 🧰 Admin Functions

| Function | Description |
|-----------|-------------|
| `setMerkleRoot(bytes32)` | Updates the Merkle root |
| `pause()` / `unpause()` | Pause or resume claiming |
| `withdrawAll()` | Withdraws all remaining ETH & tokens |
| `initialize()` | Initializes the contract with initial root |

---

## 📄 License
MIT License © 2025  
Developed for modular reward distribution with gas efficiency and strong security guarantees.
