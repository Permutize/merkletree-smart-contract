// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MultiTokenDistributor.sol";
import "./generated/MerkleData.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract TestToken is ERC20Upgradeable {
    function initialize() public initializer {
        __ERC20_init("Test", "TST");
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract MultiTokenDistributorTest is Test {
    MultiTokenDistributor distributor;
    TestToken token;
    address user1;
    address user2;
    address user3;

    function setUp() public {
    token = new TestToken();
    token.initialize();

    user1 = address(0x1001);
    user2 = address(0x1002);
    user3 = address(0x1003);

    distributor = new MultiTokenDistributor();

    // Try-catch tránh lỗi “already initialized” khi chạy lại test
    try distributor.initialize(MerkleData.MERKLE_ROOT()) {
    } catch {
        // ignore nếu đã initialized
    }

    token.transfer(address(distributor), 1000 ether);
    (bool ok, ) = payable(address(distributor)).call{value: 5 ether}("");
    require(ok, "fund failed");
}

    function test_claims_and_withdraw() public {
        uint256 n = MerkleData.COUNT();

        // build arrays for claimMany for user1 (we will claim all entries for their respective accounts)
        // We'll call claimMany separately for each account with the subset that belongs to them.

        // For demonstration, iterate through all claims and call claim for each where account == user
        for (uint i = 0; i < n; i++) {
            (uint idx, address acct, address tkn, uint256 amt, bytes32[] memory proof) = MerkleData.getClaim(i);
            // call claim via claimMany with single-element arrays
            uint[] memory indices = new uint[](1);
            indices[0] = idx;
            address[] memory tokensArr = new address[](1);
            tokensArr[0] = tkn;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amt;
            bytes32[][] memory proofs = new bytes32[][](1);
            proofs[0] = proof;

            // call as acct (simulate)
            vm.prank(acct);
            distributor.claimMany(indices, acct, tokensArr, amounts, proofs);
        }

        // After claiming, verify balances moved:
        // For token claims, token.balanceOf(owner) should have decreased; actual receivers have balances.
        // Check that our test token was transferred to recipients (sum of token claims)
        uint256 totalReceived = 0;
        for (uint i = 0; i < n; i++) {
            (,, address tkn, uint256 amt, ) = MerkleData.getClaim(i);
            if (tkn != address(0)) totalReceived += amt;
        }

        // sum of token balances of recipients equals totalReceived
        uint256 recipientsBalance = token.balanceOf(user1) + token.balanceOf(user2) + token.balanceOf(user3);
        assertEq(recipientsBalance, totalReceived);

        // ETH recipients: sum amounts and check their balances
        uint256 totalEth = 0;
        for (uint i = 0; i < n; i++) {
            (,, address tkn, uint256 amt, ) = MerkleData.getClaim(i);
            if (tkn == address(0)) totalEth += amt;
        }

        assertEq(address(user1).balance + address(user2).balance + address(user3).balance, totalEth);

        // Owner withdraws remaining assets
        address[] memory toks = new address[](1);
        toks[0] = address(token);
        // current owner is address(this) because Ownable initialized to deployer
        distributor.withdrawAll(toks);

        // distributor should have zero balances
        assertEq(token.balanceOf(address(distributor)), 0);
    }

    receive() external payable {}
}
