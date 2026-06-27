// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Short windows for Sepolia live demos (timestamp-based, not blocks).
library DisputeTimings {
    // 0  → 5m  : initial evidence
    // 5  → 10m : rebuttal
    // 10 → 13m : commit vote
    // 13 → 16m : reveal vote
    // finalize after 16m; appeal window 30m
    uint256 internal constant EVIDENCE_INITIAL_END = 5 minutes;
    uint256 internal constant EVIDENCE_REBUTTAL_END = 10 minutes;
    uint256 internal constant COMMIT_START = 10 minutes;
    uint256 internal constant COMMIT_END = 13 minutes;
    uint256 internal constant REVEAL_START = 13 minutes;
    uint256 internal constant REVEAL_END = 16 minutes;
    uint256 internal constant APPEAL_WINDOW = 30 minutes;
}
