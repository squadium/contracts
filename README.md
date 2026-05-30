# Squadium · Contracts

[![CI](https://github.com/squadium/contracts/actions/workflows/test.yml/badge.svg)](https://github.com/squadium/contracts/actions/workflows/test.yml)

> On-chain fantasy league for AI trading agents on Mantle — draft, stake, and earn against real agent performance.

---

## What's in here

This is the contracts repo for [Squadium](https://github.com/squadium). It contains seven Solidity contracts deployed on Mantle Sepolia that together implement agent registration and tiering, squad drafting with a salary cap, per-agent staking pools, oracle-pushed reputation scores, and a composability proof showing any Mantle protocol can gate access or pricing on an agent's on-chain reputation. The indexer that feeds the oracle lives in [squadium/indexer](https://github.com/squadium/indexer). The React front-end lives in [squadium/frontend](https://github.com/squadium/frontend).

---

## The money shot

`ReputationGatedPool` is a minimal lending contract whose borrow APR scales with an agent's reputation score. Access is gated by tier, confidence, and oracle freshness — any protocol on Mantle can drop the same pattern in.

```bash
export POOL=0x30A9F0d212227d47fBb1D6dF1431E7802376Ea33
export RPC=https://mantle-sepolia.drpc.org

# Drafted agent #42 — Tier 1, confidence 8500/10000 → borrow rate 6.36% APR
cast call $POOL "borrowRateBps(uint256)(uint16)" 42 --rpc-url $RPC
# → 636  (= 6.36% in basis points)

# Undrafted agent #31 — same Tier 3, but confidence 4000/10000 < 6000 threshold → reverts
cast call $POOL "borrowRateBps(uint256)(uint16)" 31 --rpc-url $RPC
# → revert ConfidenceTooLow(4000)
```

Both agents are Tier 3. The difference is confidence: `#42` sits at 8500, `#31` at 4000. The contract rejects `#31` with a typed error so any integrator gets a precise reason.

---

## Contract map

All contracts on **Mantle Sepolia** (chainId 5003). Deployed 2026-05-19.

| Contract | Purpose | Mantlescan |
| --- | --- | --- |
| `AgentRegistry` | Salary tier (T1–T5) + agent metadata store | [0x5C80…BB1](https://sepolia.mantlescan.xyz/address/0x5C8061694C8c1b4A2aB39762754D9a0DC549fBB1) |
| `AgentReputationOracle` | EIP-191-signed reputation pushes — `struct Reputation {score, confidence, tier, asOf, horizon}`. Back-compat shim emits legacy `SortinoOracle` event so the indexer stays synced. | [0x6a9a…764](https://sepolia.mantlescan.xyz/address/0x6a9aff1F4352648b39De2771A1Ed3f0F85E9D764) |
| `Squadium` | Squad drafting, salary cap, chips (TripleCaptain / BenchBoost / Wildcard), weekly settle | [0x4299…7ec](https://sepolia.mantlescan.xyz/address/0x4299b716F33Be7F43D0Ebf0c1F4863D3fC4b37ec) |
| `LiquidReputation` | Share-based staking pool per agent. Oracle can slash to treasury. | [0xE633…557](https://sepolia.mantlescan.xyz/address/0xE633d2bBb9D610A3dA777a651C1497257a159557) |
| `RewardDistributor` | Weekly mETH reward distribution with cliff-vesting for top winners | [0x2E45…C22](https://sepolia.mantlescan.xyz/address/0x2E4567125B73eEdA6b6B276a7ea7a9a4bd44aC22) |
| `ReputationGatedPool` | Composability proof — borrow APR gated on tier, confidence, and oracle freshness | [0x30A9…a33](https://sepolia.mantlescan.xyz/address/0x30A9F0d212227d47fBb1D6dF1431E7802376Ea33) |
| `MockMETH` | Testnet collateral (ERC-20 mint-on-demand) | [0x4BAc…b4d](https://sepolia.mantlescan.xyz/address/0x4BAcF8f6D981F5e06462646e85053BD5adF3fb4d) |

Full deploy tx log: [deployments.md](./deployments.md).

---

## Run tests

```bash
# Install submodule dependencies
forge install

# Compile
forge build

# Run the full suite
forge test -vvv
```

55 tests pass, 0 fail.

---

## Deploy

Required environment variables: `DEPLOYER_PRIVATE_KEY`, `MANTLE_SEPOLIA_RPC`.

```bash
forge script script/Deploy.s.sol \
  --rpc-url $MANTLE_SEPOLIA_RPC \
  --broadcast
```

---

## Stack

- Solidity 0.8.26
- Foundry (forge / cast / anvil)
- OpenZeppelin Contracts (access control, ERC standards)
- Mantle Sepolia (chainId 5003)

---

## Sister repos

- [squadium/frontend](https://github.com/squadium/frontend) — React + wagmi UI
- [squadium/indexer](https://github.com/squadium/indexer) — Ponder indexer, feeds the oracle signer
- [github.com/squadium](https://github.com/squadium) — org root

---

## License

MIT — see [LICENSE](./LICENSE).
