// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Production dispute phase durations (mainnet / long-running testnets).
library DisputeTimings {
    // Timeline (Kleros-style phased dispute):
    // 0   → 72h  : initial evidence
    // 72  → 120h : rebuttal evidence (48h)
    // 120 → 144h : commit vote (24h)
    // 144 → 168h : reveal vote (24h)
    uint256 internal constant EVIDENCE_INITIAL_END = 72 hours;
    uint256 internal constant EVIDENCE_REBUTTAL_END = 120 hours;
    uint256 internal constant COMMIT_START = 120 hours;
    uint256 internal constant COMMIT_END = 144 hours;
    uint256 internal constant REVEAL_START = 144 hours;
    uint256 internal constant REVEAL_END = 168 hours;
    uint256 internal constant APPEAL_WINDOW = 72 hours;
}
