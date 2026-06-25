// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Short windows for Sepolia live demos (timestamp-based, not blocks).
library DisputeTimings {
    // 0  → 15m : initial evidence
    // 15 → 30m : rebuttal
    // 30 → 45m : commit vote
    // 45 → 60m : reveal vote
    // finalize after 60m; appeal window 2h
    uint256 internal constant EVIDENCE_INITIAL_END = 15 minutes;
    uint256 internal constant EVIDENCE_REBUTTAL_END = 30 minutes;
    uint256 internal constant COMMIT_START = 30 minutes;
    uint256 internal constant COMMIT_END = 45 minutes;
    uint256 internal constant REVEAL_START = 45 minutes;
    uint256 internal constant REVEAL_END = 60 minutes;
    uint256 internal constant APPEAL_WINDOW = 2 hours;
}
