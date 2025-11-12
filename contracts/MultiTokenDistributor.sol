// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract MultiTokenDistributor is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    bytes32 public merkleRoot;

    // bitmap: each uint256 stores 256 claim flags
    mapping(uint256 => uint256) private claimedBitMap;

    event Claimed(uint256 indexed index, address indexed account, address token, uint256 amount);
    event ClaimedMany(address indexed account, uint256 count);
    event MerkleRootUpdated(bytes32 merkleRoot);
    event WithdrawAll(address indexed owner, uint256 ethAmount, address[] tokens);

    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
    }

    /// @notice Set new merkle root (only owner)
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /// @notice Pause contract (only owner)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause contract (only owner)
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Check whether index has been claimed
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 wordIndex = index >> 8; // index / 256
        uint256 bitIndex = index & 255; // index % 256
        uint256 word = claimedBitMap[wordIndex];
        return (word & (1 << bitIndex)) != 0;
    }

    function _setClaimed(uint256 index) private {
        uint256 wordIndex = index >> 8;
        uint256 bitIndex = index & 255;
        claimedBitMap[wordIndex] |= (1 << bitIndex);
    }

    /// @notice Claim a single token (ETH if token == address(0))
    function claim(
        uint256 index,
        address account,
        address token,
        uint256 amount,
        bytes32[] calldata proof
    ) public whenNotPaused nonReentrant {
        require(!isClaimed(index), "Already claimed");

        bytes32 node = keccak256(abi.encode(index, account, token, amount));
        require(MerkleProof.verify(proof, merkleRoot, node), "Invalid proof");

        _setClaimed(index);

        if (token == address(0)) {
            // send ETH safely
            payable(account).sendValue(amount);
        } else {
            IERC20(token).safeTransfer(account, amount);
        }

        emit Claimed(index, account, token, amount);
    }

    /// @notice Claim multiple entries in one transaction
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
            // call internal variant to avoid extra external call overhead
            _claimInternal(indices[i], account, tokens[i], amounts[i], proofs[i]);
        }

        emit ClaimedMany(account, len);
    }

    /// @notice Internal claim used by claimMany to avoid external call overhead
    function _claimInternal(
        uint256 index,
        address account,
        address token,
        uint256 amount,
        bytes32[] calldata proof
    ) internal {
        require(!isClaimed(index), "Already claimed");

        bytes32 node = keccak256(abi.encode(index, account, token, amount));
        require(MerkleProof.verify(proof, merkleRoot, node), "Invalid proof");

        _setClaimed(index);

        if (token == address(0)) {
            payable(account).sendValue(amount);
        } else {
            IERC20(token).safeTransfer(account, amount);
        }

        emit Claimed(index, account, token, amount);
    }

    /// @notice Owner can withdraw all ETH + listed ERC20 tokens
    function withdrawAll(address[] calldata tokens) external onlyOwner nonReentrant {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            payable(owner()).sendValue(ethBalance);
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            if (balance > 0) {
                token.safeTransfer(owner(), balance);
            }
        }

        emit WithdrawAll(owner(), ethBalance, tokens);
    }

    // Allow contract to receive ETH
    receive() external payable {}
    fallback() external payable {}
}
