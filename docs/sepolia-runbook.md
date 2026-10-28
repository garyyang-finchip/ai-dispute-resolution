# Sepolia evidence runbook

The evidence run deploys the ADRF registries, the three methods, the bridge over the live ERC-8436 reference registry on Sepolia, the worked-example escrow bound to a fast-track policy, and walks the two complete flows with real transactions. It is the same script that was rehearsed on Anvil (`docs/test-record.md`).

## Inputs

- `PRIVATE_KEY`: the deployer. It funds the derived actors (client 0.012 ETH, provider 0.004 ETH, three jurors 0.002 ETH each) in the deploy phase; budget about 0.05 Sepolia ETH in total including deployment gas (take gas limits from `eth_estimateGas` on the live network, which prices code deposit several times higher than Anvil).
- `ACDF_REGISTRY`: the live ERC-8436 issue registry (the deployment recorded in the acd-framework repository, `deployments/sepolia.json`). The script reads its policy registry through `policies()` and registers a fast-track 2-of-3 roster policy there (15-minute window, one 10-minute appeal, 40-minute hard cap).
- `SEPOLIA_RPC_URL`: the RPC endpoint (`foundry.toml` maps it to the `sepolia` alias).

## Phases

```
PHASE=deploy          forge script script/SepoliaEvidence.s.sol --rpc-url sepolia --broadcast
PHASE=formal-file     ...   # opens a call, charges it twice, files, verifies, decides (Provisional)
# wait 10 minutes (review window)
PHASE=formal-finalize ...   # finalizes, the escrow enacts the refund
PHASE=judged-file     ...   # opens a call, delivers, files, opens the ERC-8436 issue
PHASE=judged-vote     ...   # two jurors block, the round settles (Provisional at the source)
# wait 10 minutes (ERC-8436 appeal window)
PHASE=judged-finalize ...   # finalizes the issue, imports the result, decides (Provisional)
# wait 10 minutes (review window)
PHASE=judged-close    ...   # finalizes, the escrow enacts the refund
```

State is kept in `deployments/11155111.json`. The fast-track ADRF policy uses a 1-day filing window, 30-minute acceptance and evidence windows, a 60-minute decision window, one 10-minute review, a 2h10m hard cap and a 10-minute enactment margin; the calls carry a 4-hour dispute period so that the clock check passes.

## Record

After the run: copy `deployments/11155111.json` to `deployments/sepolia.json`, add the transaction hashes of each phase (`broadcast/SepoliaEvidence.s.sol/11155111/*.json`), verify the contracts (Sourcify or Etherscan) and write `docs/sepolia-evidence.md` with the addresses, the policy and binding identifiers, the two case identifiers, the ERC-8436 issue identifier and the rulings read back from the registry.
