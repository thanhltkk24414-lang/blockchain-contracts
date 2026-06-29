# FAPEX — Smart Contracts

> Solidity escrow + dispute contracts for the FAPEX freelance platform on Sepolia.

Submodule của monorepo [`Blockchain`](../README.md). Source chính: `FreelanceSystem.sol`, `MockUSDC.sol`.

**Cập nhật:** 2026-06-28

---

## Contracts

| Contract | Vai trò |
|----------|---------|
| `MockUSDC` | Test token 6 decimals, `mint()` permissionless |
| `JobRegistry` | Job lifecycle, proposals, deliverable CID |
| `EscrowVault` | Escrow deposit/release, dispute orchestration |
| `ArbitratorPanel` | Pool, sortition, evidence, commit–reveal vote |
| `PlatformTreasury` | Arbitrator stake (50 USDC), slash, rewards |
| `ReputationStore` | Soulbound reputation scores |

---

## Sepolia deployment

**File:** [`../deployments/sepolia.json`](../deployments/sepolia.json) · `disputeTimings: demo`

| Contract | Address |
|----------|---------|
| MockUSDC | `0x2293193Eaa5CE5253d5e081046a06dB077f26f8e` |
| JobRegistry | `0x302629f82d51b0972ffc3A99cbE355F4acEf908d` |
| EscrowVault | `0x5f8C4c552F49103cA84dF455571155C8268C2aF5` |
| ArbitratorPanel | `0x490Afc952af85aB0dEb375Bd36A65db5E1F47418` |
| PlatformTreasury | `0x666aF0Ec040377026E0D40870Bce7c165f741530` |
| ReputationStore | `0x5e457db6a8A44C143180043c5Bb7223C7222898E` |

**Legacy JobRegistry:** `0xE5425cFE21BAe73d54138Bb290B671bF4c55FBC9` (jobs trước redeploy)

---

## Setup

```bash
# Từ monorepo root
cp contracts/.env.example contracts/.env
# PRIVATE_KEY, SEPOLIA_RPC_URL, ETHERSCAN_API_KEY

npm install
npm run compile          # exports ABIs → backend + frontend
npm test                 # prod dispute timings
```

---

## Deploy & seed

```bash
npm run deploy:sepolia        # DisputeTimings.demo (phút)
npm run deploy:sepolia:prod   # DisputeTimings.prod (giờ)
npm run seed:arbitrators      # 5 arbitrators vào pool
npm run verify:sepolia
```

### Dispute timings

| Mode | Evidence | Commit | Reveal | Appeal |
|------|----------|--------|--------|--------|
| **demo** | 0–10 min | 10–13 min | 13–16 min | 30 min |
| **prod** | 0–120 h | 120–144 h | 144–168 h | 72 h |

Chọn trước compile: `node scripts/prepare-dispute-timings.js demo|prod`

---

## Fees (on-chain)

- Platform fee on deposit: **3%**
- Service fee on release: **2%**
- Dispute fee: **2%** (cap 50 USDC)
- Arbitrator min stake: **50 USDC**

---

## Chainlink

- **VRF sortition:** deferred v2 — MVP dùng `block.prevrandao`
- Stub: `chainlink/VRFSortitionStub.sol`

Chi tiết: [docs/guides/chainlink-integration-vi.md](../docs/guides/chainlink-integration-vi.md)

---

## Docs

- [Contract interaction guide](../docs/guides/contract-interaction.md)
- [System design](../docs/guides/system-design-vi.md)
- [Dispute vs Kleros](../docs/guides/dispute-kleros-comparison-vi.md)
