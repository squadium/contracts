# Squadium · Contracts

> Smart contracts for **Squadium** — the fantasy league for on-chain AI trading agents on Mantle.

Part of the [Squadium](https://github.com/squadium) project, built for [The Turing Test Hackathon 2026](https://dorahacks.io/hackathon/mantleturingtesthackathon2026).

Companion repos (when ready): `squadium/frontend` · `squadium/indexer`

---

## Contracts

| Contract | Purpose |
| --- | --- |
| `Squadium.sol` | Core game logic — draft squads, lock weeks, settle, claim rewards |
| `AgentRegistry.sol` | ERC-8004 reader + tier storage (T1–T5) + Nansen labels mirror |
| `SortinoOracle.sol` | ECDSA-signed Sortino score updates from off-chain indexer |
| `LiquidReputation.sol` | _(coming)_ Stake mETH against agent future performance, mint rWAY tokens |
| `RewardDistributor.sol` | _(coming)_ Weekly mETH reward distribution with cliff-vesting for top winners |

---

## Stack

- **Solidity** 0.8.26
- **Foundry** (forge / cast / anvil)
- **OpenZeppelin Contracts** (access control, ERC standards)
- **forge-std** (testing utilities)
- Target chain: **Mantle Sepolia** (W1) → **Mantle Mainnet** (W3-W4)

---

## Quick Start

```bash
git clone --recurse-submodules https://github.com/squadium/contracts.git
cd contracts

forge build
forge test -vvv
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

---

## Deploy

```bash
cp .env.example .env
# Fill DEPLOYER_PRIVATE_KEY, RPC, etc.

# Mantle Sepolia
forge script script/Deploy.s.sol \
  --rpc-url mantle_sepolia \
  --broadcast \
  --verify

# Mantle Mainnet (W3-W4)
forge script script/Deploy.s.sol \
  --rpc-url mantle_mainnet \
  --broadcast \
  --verify
```

---

## Design Notes

### Tier / Salary Cap
- Salary cap: **100 credits**, squad size: **5 agents**
- T1 Legendary = 35 credits, T2 Elite = 25, T3 Pro = 18, T4 Rising = 12, T5 Rookie = 8
- Tier assigned by multi-factor TierScore: `0.5 × SortinoNorm + 0.2 × VolumeNorm + 0.2 × NansenScore + 0.1 × Consistency`

### Scoring (weekly settlement)
```
Score = Σ (PnL × CaptainWeight × ConsistencyMultiplier) − DrawdownPenalty

CaptainWeight        = 2.0 for captain, 1.0 others
ConsistencyMultiplier = 1 + min(SortinoWeek / 3, 1.0)    [cap 2x]
DrawdownPenalty      = -50% if weekly DD > 15%
```

### Sortino on-chain
- Stored as signed basis points (int256, e.g. 2.5 → `25_000`)
- Pushed by `SortinoOracle.sol` via ECDSA-signed payload from off-chain indexer
- Indexer signer is a single trusted key (multi-sig planned for v2)

### Chips (one-time per season)
- **Wildcard** — bypass salary cap once
- **Triple Captain** — captain scores 3x
- **Bench Boost** — all 5 picks score at captain rate
- **Free Hit** — one-week throwaway squad, doesn't carry over

---

## Track Mapping (for hackathon judges)

| Track / Award | Status |
| --- | --- |
| **Grand Champion** | Primary goal — Top Overall Business Potential, Completion, Mantle Ecosystem Fit |
| **Consumer & Viral DApps — First Prize** | Primary track |
| Community Voting | Cross-cut |
| Best UI/UX Award | Cross-cut |
| 20 Project Deployment Award | Cross-cut |

---

## License

MIT — see [LICENSE](./LICENSE).
