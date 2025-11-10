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
