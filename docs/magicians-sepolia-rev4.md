# Sepolia evidence note, revision 4 (reply for the Magicians thread)

*Posted as a reply on topic 30121 after the second run of 2026-10-29.*

---

**Sepolia evidence, revision 4 — the revised contracts, both flows, 45 transactions.**

The revision-4 reference implementation of ERC-8471 has its own evidence run on Sepolia: 45 transactions on 2026-10-29, blocks 12021936 to 12022145, all successful, 132.4 million gas under Sepolia's current schedule, 0.0021 ETH in fees. Dispute registry `0x48aBDc76a736546CB3C3B122C9964BC294aE2508` (one address for the whole `IADRFDisputeRegistry`, over six modules), policy registry `0x9AA578eBbc6af2a3E0a015a0fFCc6330ba4BeEd5`, escrow `0x698E06aE8C3bc0aa1E2ec12D9A378341b71776B1`, bridge `0x5535588f5eA314B94Fa24567Bb3990Dfd7Ee0fE6` over the same live ERC-8436 registry as before (`0x3bE57E74…`). The revision-3 deployment stays where it is; this is a second deployment, not a replacement.

What the run shows that the revision-3 run could not:

- The double charge is filed as a claim about settlement 2 of call 1 — the event the escrow attests for it (`settlementEventRef(2)`) — with the verifier's proposition for that settlement as the decisive question; admission passed because the escrow recognizes that proposition being `TRUE` as a breach of the payment obligation (criterion 3 of revision 4). The exclusivity key read back from the case is the hash of the source, the attested obligation and that decisive proposition, not of the claim's headline: `exclusivityKeyOf(escrow, keccak(1, "payment"), proposition) = 0x5b362e7d…` matches `getCase`. Case `0xafb715e3…`: `TRUE`, `computed`, `Sustained`, Final after the review window, refund `Enacted` — of settlement 2, taken from the escrow's held balance, while settlement 1 of the same call is still `Held` for the provider (`settlementOf(1, 1)` = Held, `settlementOf(1, 2)` = Refunded, `heldOf(1)` = 0.001 ETH).
- The delivery-quality claim (call 2) ran as before through a `CONSUMER_FILED` issue with the live ERC-8436 registry: two jurors blocked, the Final result was imported as `FALSE` with its provenance (issue `0x71f29705…`, source round 1 of 1), the claim decided `Sustained` through its own direction, and the refund took the call's held charge — case `0xc7b6796b…`. Nothing had been credited to the provider at settlement (`balanceOf(provider) = 0`), so the value a ruling could touch was there when the ruling came, as Section 5.1 now requires of a source that attests an adoption deadline.

One detail of the run itself: the ERC-8436 fast-track policy the script registers is content-addressed and identical to the one the revision-3 run registered (same family, same derived jurors, same windows), so the live policy registry refused to register it twice; the script now finds it registered and reuses it (`0x328b3d82…`), which is why this run has 45 transactions where the first had 46. The largest creations landed where the pre-flight had estimated them: the revised escrow at 14.56 million gas (87% of the 16,777,216-gas cap), the filing module at 13.79 million (82%); the nine units whose bytecode did not change cost exactly what they cost in revision 3.

The record — addresses, identifiers, every transaction with block, gas and status, the state read back from the chain, the identifiers recomputed and matched — is `docs/sepolia-evidence-rev4.md` in the repository, with `deployments/sepolia-rev4.json`, `deployments/sepolia-rev4.transactions.json` and the read-back script (`scripts/sepolia-readback.sh`, which now also prints each settlement's state). All thirteen contracts are verified on Sourcify (runtime and creation bytecode `match`).

Repository: https://github.com/garyyang-finchip/ai-dispute-resolution · PR: https://github.com/ethereum/ERCs/pull/2123
