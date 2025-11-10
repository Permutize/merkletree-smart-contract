// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import OpenZeppelin upgradeable modules
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title MultiTokenDistributor
 * @notice A Merkle-based token and ETH distributor that supports multiple token claims.
 * Each claim is verified using a Merkle proof.
 */
contract MultiTokenDistributor is 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Merkle root that represents all valid claims
    bytes32 public merkleRoot;

    /// @notice Bitmap to track which claim indices have already been claimed
    /// Each uint256 can store 256 claim states (1 bit per index)
    mapping(uint256 => uint256) private claimedBitMap;

    // ======== Events ========

    /// @notice Emitted when a single claim is successfully processed
    event Claimed(uint256 indexed index, address indexed account, address token, uint256 amount);

    /// @notice Emitted when multiple claims are processed in one transaction
    event ClaimedMany(address indexed account, uint256 count);

    /// @notice Emitted when the Merkle root is updated by the owner
    event MerkleRootUpdated(bytes32 merkleRoot);

    /// @notice Emitted when the owner withdraws all ETH and tokens from the contract
    event WithdrawAll(address indexed owner, uint256 ethAmount, address[] tokens);

    // ======== Initialization ========

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Disable direct initialization for proxy safety
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract (used instead of a constructor in upgradeable contracts)
     * @param _merkleRoot Initial Merkle root
     */
    function initialize(bytes32 _merkleRoot) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        merkleRoot = _merkleRoot;
    }

    // ======== Admin Functions ========

    /**
     * @notice Updates the Merkle root to a new one
     * @dev Only callable by the contract owner
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /// @notice Pause claiming (for emergency situations)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause claiming
    function unpause() external onlyOwner {
        _unpause();
    }

    // ======== Claim Tracking ========

    /**
     * @notice Check if a given index has already been claimed
     * @param index Claim index from the Merkle tree
     */
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 wordIndex = index >> 8; // index / 256
        uint256 bitIndex = index & 255; // index % 256
        uint256 word = claimedBitMap[wordIndex];
        return (word & (1 << bitIndex)) != 0;
    }

    /**
     * @notice Mark a claim index as claimed (set bit to 1)
     */
    function _setClaimed(uint256 index) private {
        uint256 wordIndex = index >> 8;
        uint256 bitIndex = index & 255;
        claimedBitMap[wordIndex] |= (1 << bitIndex);
    }

    // ======== Core Claim Logic ========

    /**
     * @notice Internal function to claim a single reward
     * @dev Verifies Merkle proof and transfers ETH or ERC20 tokens
     */
    function claim(
        uint256 index,
        address account,
        address token,
        uint256 amount,
        bytes32[] calldata proof
    ) internal {
        require(!isClaimed(index), "Already claimed");

        // Compute leaf node hash (must match Merkle tree structure off-chain)
        bytes32 node = keccak256(abi.encode(index, account, token, amount));

        // Verify proof against stored Merkle root
        require(MerkleProofUpgradeable.verify(proof, merkleRoot, node), "Invalid proof");

        // Mark as claimed
        _setClaimed(index);

        // Transfer ETH or ERC20
        if (token == address(0)) {
            (bool sent, ) = account.call{value: amount}("");
            require(sent, "ETH transfer failed");
        } else {
            IERC20Upgradeable(token).safeTransfer(account, amount);
        }

        emit Claimed(index, account, token, amount);
    }

    /**
     * @notice Allows users to claim multiple rewards in one transaction
     * @param indices Claim indices
     * @param account The receiver address
     * @param tokens Array of token addresses (use address(0) for ETH)
     * @param amounts Amounts to claim
     * @param proofs Array of Merkle proofs (each proof corresponds to one claim)
     */
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

        // Process each claim
        for (uint256 i = 0; i < len; i++) {
            claim(indices[i], account, tokens[i], amounts[i], proofs[i]);
        }

        emit ClaimedMany(account, len);
    }

    // ======== Withdraw Logic ========

    /**
     * @notice Withdraws all remaining ETH and tokens to the owner
     * @param tokens List of ERC20 token addresses to withdraw
     */
    function withdrawAll(address[] calldata tokens) external onlyOwner nonReentrant {
        // Withdraw ETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            payable(owner()).transfer(ethBalance);
        }

        // Withdraw tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20Upgradeable token = IERC20Upgradeable(tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            if (balance > 0) {
                token.safeTransfer(owner(), balance);
            }
        }

        emit WithdrawAll(owner(), ethBalance, tokens);
    }

    // ======== Fallbacks ========

    /// @notice Allow contract to receive ETH
    receive() external payable {}

    /// @notice Allow fallback calls with ETH
    fallback() external payable {}
}

/* ----------------------------------------------------------------
   🧩 Notes on Merkle Tree Usage:
   - Each leaf node in the Merkle tree should be constructed as:
       keccak256(abi.encode(index, account, token, amount))
   - `proof` is an array of sibling hashes used to verify the leaf.
   - Off-chain, you must generate:
        • merkleRoot (set by owner)
        • proofs (for each user's claim)
   - Claim flow:
        1️⃣ Off-chain system publishes merkleRoot and user proofs.
        2️⃣ User calls `claimMany()` with proof data.
        3️⃣ Contract verifies proof and sends rewards.
   ---------------------------------------------------------------- */
