// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract MultiTokenDistributorUpgradeable is 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public merkleRoot;
    mapping(uint256 => uint256) private claimedBitMap;

    event Claimed(uint256 indexed index, address indexed account, address token, uint256 amount);
    event ClaimedMany(address indexed account, uint256 count);
    event MerkleRootUpdated(bytes32 merkleRoot);
    event WithdrawAll(address indexed owner, uint256 ethAmount, address[] tokens);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); //prevent constructor directly
    }

    /// @notice initialize contract
    function initialize(bytes32 _merkleRoot) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        merkleRoot = _merkleRoot;
    }

    // --- Admin functions ---
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // --- Claim logic ---
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 wordIndex = index >> 8;
        uint256 bitIndex = index & 255;
        uint256 word = claimedBitMap[wordIndex];
        return (word & (1 << bitIndex)) != 0;
    }

    function _setClaimed(uint256 index) private {
        uint256 wordIndex = index >> 8;
        uint256 bitIndex = index & 255;
        claimedBitMap[wordIndex] |= (1 << bitIndex);
    }

    function claim(
        uint256 index,
        address account,
        address token,
        uint256 amount,
        bytes32[] calldata proof
    ) internal {
        require(!isClaimed(index), "Already claimed");

        bytes32 node = keccak256(abi.encode(index, account, token, amount));
        require(MerkleProofUpgradeable.verify(proof, merkleRoot, node), "Invalid proof");

        _setClaimed(index);

        if (token == address(0)) {
            (bool sent, ) = account.call{value: amount}("");
            require(sent, "ETH transfer failed");
        } else {
            IERC20Upgradeable(token).safeTransfer(account, amount);
        }

        emit Claimed(index, account, token, amount);
    }

    function claimMany(
        uint256[] calldata indices,
        address account,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external whenNotPaused nonReentrant {
        uint256 len = indices.length;
        require(
            len == tokens.length && len == amounts.length && len == proofs.length,
            "Length mismatch"
        );

        for (uint256 i = 0; i < len; i++) {
            claim(indices[i], account, tokens[i], amounts[i], proofs[i]);
        }

        emit ClaimedMany(account, len);
    }

    // --- Withdraw all assets ---
    function withdrawAll(address[] calldata tokens) external onlyOwner nonReentrant {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            payable(owner()).transfer(ethBalance);
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20Upgradeable token = IERC20Upgradeable(tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            if (balance > 0) {
                token.safeTransfer(owner(), balance);
            }
        }

        emit WithdrawAll(owner(), ethBalance, tokens);
    }

    // --- Receive ETH ---
    receive() external payable {}
    fallback() external payable {}
}
