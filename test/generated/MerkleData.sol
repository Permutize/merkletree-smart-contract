// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library MerkleData {
    function MERKLE_ROOT() internal pure returns (bytes32) {
        return 0x0c962258c375c03a0ac3b42c5c6e42b96aa01eabffb540d5e213173bdf29aa99;
    }

    function COUNT() internal pure returns (uint256) {
        return 1;
    }

    function getClaim_0() internal pure returns (uint256 index, address account, address token, uint256 amount, bytes32[] memory proof) {
        index = 0;
        account = 0x3afb97a6b4483ede589333D8383059A5D53534FF;
        token = 0x0000000000000000000000000000000000000000;
        amount = 1000000000000000000;
        proof = new bytes32[](0);
        return (index, account, token, amount, proof);
    }

    function getClaim(uint256 i) internal pure returns (uint256, address, address, uint256, bytes32[] memory) {
        if (i == 0) return getClaim_0();
        revert("Invalid claim index");
    }
}
