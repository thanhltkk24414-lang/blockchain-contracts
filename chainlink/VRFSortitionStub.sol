// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VRF Sortition stub (v2 — not deployed on current Sepolia)
/// @notice Documents intended Chainlink VRF integration for ArbitratorPanel sortition.
/// @dev Production panel uses block.prevrandao. Replace with VRF callback in v2 redeploy.
interface IVRFSortitionConsumer {
    event SortitionRequested(uint256 indexed jobId, uint256 indexed requestId);

    function requestArbitratorSortition(uint256 jobId) external;

  /// @param randomWords VRF fulfillment — select 5 arbitrators from staked pool
    function fulfillArbitratorSortition(
        uint256 jobId,
        uint256[] calldata randomWords
    ) external;
}
