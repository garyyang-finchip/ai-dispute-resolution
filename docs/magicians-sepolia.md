# Sepolia evidence note (reply for the Magicians thread)

*Posted as a reply on topic 30121 after the run of 2026-10-29.*

---

**Sepolia evidence — both flows executed against the live ERC-8436 registry.**

The reference implementation of ERC-8471 (revision 3) now has its evidence run on Sepolia: 46 transactions on 2026-10-29, blocks 12017706 to 12017916, all successful, 131.3 million gas under Sepolia's current schedule, 0.0077 ETH in fees. Dispute registry `0x4e27C4728B22c3306f2378b8B421774dc35fE0a9` (one address for the whole `IADRFDisputeRegistry`, over six modules of at most 8.5 KB; the three largest creations landed at 80% of the 16,777,216-gas cap, as estimated), policy registry `0x071093a38289b5f9578D0162727b05A52E07eed5`, bridge `0xeC31cb06CEFCd871Bc36cD5267bC3fe9A21c60EB` over the ERC-8436 revision-3 registry `0x3bE57E74f2E7c280073b6B16A1Db3F562758dB01`.

Two complete flows, each with a plain-account client and a model API service under ordinary terms, no agent identity anywhere:

- A double charge (call 1 settled twice): filed, admitted under the five criteria, verified on chain by the duplicate-settlement verifier (`TRUE`, support `computed`), decided `Sustained`, finalized after the review window, refund enacted by the escrow and reported `Enacted` — case `0x1bc24c2e…`.
- A delivery-quality claim (call 2): filed, admitted, one `JUDGED` sub-question opened as a `CONSUMER_FILED` issue with the live ERC-8436 registry under a 2-of-3 fast-track policy; two jurors blocked, the round settled, the appeal window lapsed, the Final result (Decided, no) was imported as the finding `FALSE` with support `judged` and full provenance (registry, issue, policy, source round 1 of 1), the claim decided `Sustained` through its own direction, finalized, refund enacted — case `0xee91e703…`, issue `0xbe51f9c5…`.

Every entry was logged under the registry's address (the modules never appear as emitters), and every read of the record comes back through the same address. The record — addresses, identifiers, every transaction with block, gas and status, the state read back from the chain, the gas schedule observed — is `docs/sepolia-evidence.md` in the repository, with `deployments/sepolia.json`, `deployments/sepolia.transactions.json` and a read-back script anyone can run against a Sepolia RPC. Sourcify verification of the thirteen contracts was submitted from the standard JSON input.

Repository: https://github.com/garyyang-finchip/ai-dispute-resolution · PR: https://github.com/ethereum/ERCs/pull/2123
