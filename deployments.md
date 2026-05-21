# Squadium Deployments

## Mantle Sepolia · chainId 5003

Deployed 2026-05-19 from commit on `main`. Deployer:
[`0x1185948280B230460437Ad09a97618B51Dd8C45d`](https://sepolia.mantlescan.xyz/address/0x1185948280B230460437Ad09a97618B51Dd8C45d).

| Contract | Address | Deploy tx |
| --- | --- | --- |
| **MockMETH** | [`0x4BAcF8f6D981F5e06462646e85053BD5adF3fb4d`](https://sepolia.mantlescan.xyz/address/0x4BAcF8f6D981F5e06462646e85053BD5adF3fb4d) | [`0x52f8…3bba8`](https://sepolia.mantlescan.xyz/tx/0x52f89edc02dfc934c3a92eca31645bef4646e3e54c8c0991f2f97583dc03bba8) |
| **AgentRegistry** | [`0x5C8061694C8c1b4A2aB39762754D9a0DC549fBB1`](https://sepolia.mantlescan.xyz/address/0x5C8061694C8c1b4A2aB39762754D9a0DC549fBB1) | [`0x9bd3…c519`](https://sepolia.mantlescan.xyz/tx/0x9bd37ed14a6bb3a7d73c8c716970a361411cd6b2128de07a7994243c98b5c519) |
| **AgentReputationOracle** | [`0x6a9aff1F4352648b39De2771A1Ed3f0F85E9D764`](https://sepolia.mantlescan.xyz/address/0x6a9aff1F4352648b39De2771A1Ed3f0F85E9D764) | [`0x130b…2a7b`](https://sepolia.mantlescan.xyz/tx/0x130bdb5ae9602fc102e05f4deeeb67f7c72a1846f96ba8de966471d387f92a7b) |
| **Squadium** | [`0x4299b716F33Be7F43D0Ebf0c1F4863D3fC4b37ec`](https://sepolia.mantlescan.xyz/address/0x4299b716F33Be7F43D0Ebf0c1F4863D3fC4b37ec) | [`0x589c…37a8`](https://sepolia.mantlescan.xyz/tx/0x589cfaf3265f53e050d9969f5f32dd2b477b7650fa8a23b2e49f4f8feff637a8) |
| **LiquidReputation** | [`0xE633d2bBb9D610A3dA777a651C1497257a159557`](https://sepolia.mantlescan.xyz/address/0xE633d2bBb9D610A3dA777a651C1497257a159557) | [`0x8d19…43a5`](https://sepolia.mantlescan.xyz/tx/0x8d197fde1dbebfc1e9d9cde197e2d0019837ecf8fefc9c7b5706090c587d43a5) |
| **RewardDistributor** | [`0x2E4567125B73eEdA6b6B276a7ea7a9a4bd44aC22`](https://sepolia.mantlescan.xyz/address/0x2E4567125B73eEdA6b6B276a7ea7a9a4bd44aC22) | [`0x61a0…c917`](https://sepolia.mantlescan.xyz/tx/0x61a02108a1faba60d0ae4cbc855b23590f98978c8ceea026990e1c13272bc917) |
| **ReputationGatedPool** | [`0x30A9F0d212227d47fBb1D6dF1431E7802376Ea33`](https://sepolia.mantlescan.xyz/address/0x30A9F0d212227d47fBb1D6dF1431E7802376Ea33) | [`0x5d77…79e`](https://sepolia.mantlescan.xyz/tx/0x5d77ae73185c4b6c96f793b4981a40415dbdc37361065302962225bf8497479e) |

**START_BLOCK for indexer: `38879885`** (block of the first deploy tx — set this in the
indexer `.env.local` to skip scanning the rest of the chain).

### Seeded agents (cold-start mitigation · CCRI spec §6)

`script/Seed.s.sol` registered **10 demo agents** with diverse tiers
(T1–T5) and seeded perf metrics so the dapp + oracle have real on-chain data
at demo time. Cost reads verified via `cast`:
`getAgentCost(42) = 35` (T1) and `getAgentCost(211) = 8` (T5). See
`broadcast/Seed.s.sol/5003/run-latest.json` for the full tx log.

## Mantle Mainnet · chainId 5000

_Not deployed yet — planned W4 if Sepolia run validates clean._
