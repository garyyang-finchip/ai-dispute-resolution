# Sepolia evidence runbook

The run was executed on Sepolia on 2026-10-29 with the revision-3 contracts exactly as described here (Foundry 1.7.1 on the operator's machine; 46 transactions, all successful); its record is `docs/sepolia-evidence.md` with `deployments/sepolia.json`. The revision-4 contracts are run the same way; `RECORD` (default `sepolia-rev4`) names the record files of that run so that the revision-3 record stays as it is, and the record step takes the newest seven run files of the broadcast directory, so the files of the earlier run may stay there.

The evidence run deploys the ADRF kernel (the policy registry, the six modules and the dispute registry), the three methods, the bridge over the live ERC-8436 reference registry on Sepolia, the worked-example escrow bound to a fast-track policy, and walks the two complete flows with real transactions. It is the same script that was rehearsed on Anvil (`docs/test-record.md`): `script/SepoliaEvidence.s.sol`, run phase by phase.

## Sepolia since Glamsterdam

Two properties of Sepolia's current gas schedule decide how the run is executed; both were measured on the earlier runs of this standards family (ERC-8436 on 2026-10-09 and 2026-10-15, ERC-8468 on 2026-10-26 and 2026-10-27):

- A transaction may use at most 16,777,216 gas (EIP-7825); `eth_estimateGas` and `eth_call` enforce the cap as well. Deployment cost grows by roughly 1,570 to 1,800 gas per byte of deployed code (as the revision-3 run measured), so a contract above about 10,500 bytes of runtime code cannot be deployed at all. This is why revision 3 splits the dispute registry into a 2 KB router and six modules of at most 8,784 bytes; the largest units (`ADRFServiceEscrow` 9,209 bytes in revision 4, `ADRFFilingModule` 8,784, `ADRFPolicyRegistry` 8,540, `ADRFDecisionModule` 8,535) extrapolate to 13.4 to 14.5 million gas, 80 to 87% of the cap; the pre-flight below reads the live figure before anything is sent.
- The schedule prices state and code several times higher than the model of a local Foundry simulation (a plain transfer to an empty account costs 204,600 gas; the earlier runs saw five to seven times the local figure). A transaction sized by the local simulation runs out of gas on chain while the simulation passes. Every broadcast therefore takes its gas limits from the node: `--skip-simulation --gas-estimate-multiplier 150`. Unused gas is refunded, so the margin costs nothing.

Base fees on Sepolia have been between a few wei and about 1.2 gwei in October. The whole run uses on the order of 100 million gas on this schedule: at tens of wei that is well under 0.001 ETH in fees; at 1 gwei it is about 0.1 ETH. The deployer also forwards 0.022 ETH to the derived actors, and the client deposits 0.006 ETH into the escrow (the refunds flow back to it). Fund the deployer with 0.05 ETH when the base fee is in the wei range and with 0.15 ETH when it is around 1 gwei.

## One-command run

`scripts/sepolia-run.sh` drives everything below with the two environment variables as its only inputs: `preflight` runs the checks of the next two sections, `all` runs the seven phases in order and waits eleven minutes where a window must lapse, and `record` writes the two record files; a single phase name runs that phase alone. It needs Foundry (`forge`, `cast`) and `python3` on the machine that holds the key, and nothing else.

```
export SEPOLIA_RPC_URL=https://...
export PRIVATE_KEY=0x...
bash scripts/sepolia-run.sh preflight
bash scripts/sepolia-run.sh all          # about 40 minutes, most of it waiting
bash scripts/sepolia-run.sh record       # deployments/sepolia-rev4.json, deployments/sepolia-rev4.transactions.json
```

`RECORD` names the record (default `sepolia-rev4`); `scripts/sepolia-readback.sh` and `scripts/sepolia-verify.sh` read the same name, so the whole revision-4 sequence is `preflight`, `all` (or the phases one by one), `record`, then `readback` and `verify` with no argument, and `RECORD=sepolia bash scripts/sepolia-readback.sh` reads the revision-3 record.

The rest of this document is what the script does, for running it by hand or for reading the result.

## Inputs

- `PRIVATE_KEY`: the deployer. It funds the derived actors (client 0.012 ETH, provider 0.004 ETH, three jurors 0.002 ETH each) in the deploy phase and pays the deployment gas. The client, the provider and the three jurors are derived from it inside the script and need no key of their own.
- `ACDF_REGISTRY`: the live ERC-8436 issue registry whose interfaces match the ones vendored under `assets/erc-adrf/contracts/interfaces/acdf` — the revision-3 deployment of the acd-framework repository, `ACDFRegistry` at `0x3bE57E74f2E7c280073b6B16A1Db3F562758dB01` (its policy registry `0x7eAfCC452EC0A60a358a26B6e73f28413C4abeF0` is read through `policies()`). The script registers a fast-track 2-of-3 roster policy there (15-minute window, one 10-minute appeal, 40-minute hard cap) and the bridge files one issue under it. The revision-2 registry at `0xbA03B451B421b5041d7bE7b5Fd7DbcF3B6Aa1354` predates the body-role rules and is not the one to use.
- `SEPOLIA_RPC_URL`: the RPC endpoint (`foundry.toml` maps it to the `sepolia` alias).

```
export SEPOLIA_RPC_URL=...
export PRIVATE_KEY=0x...
export ACDF_REGISTRY=0x3bE57E74f2E7c280073b6B16A1Db3F562758dB01
cast chain-id --rpc-url $SEPOLIA_RPC_URL                               # 11155111
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $SEPOLIA_RPC_URL --ether
cast call $ACDF_REGISTRY "policies()(address)" --rpc-url $SEPOLIA_RPC_URL   # 0x7eAfCC45...
```

## Pre-flight: the largest creations against the cap

The runtime sizes are in `forge build --sizes`; the live cost of the three largest creations is read from the node before anything is sent (the module takes the policy registry's address as its one constructor argument; any address serves for the estimate):

```
forge build
ARG=$(cast abi-encode "f(address)" 0x0000000000000000000000000000000000000001 | cut -c3-)
cast estimate --rpc-url $SEPOLIA_RPC_URL --create $(forge inspect ADRFPolicyRegistry bytecode)
cast estimate --rpc-url $SEPOLIA_RPC_URL --create $(forge inspect ADRFDecisionModule bytecode)$ARG
cast estimate --rpc-url $SEPOLIA_RPC_URL --create $(forge inspect ADRFFilingModule bytecode)$ARG
```

Each figure must be below 16,777,216; expect 13.4 to 14.5 million (the script's pre-flight estimates the six largest creations, the escrow among them). If the node answers with an error instead of a number, the schedule has moved and the sizes have to be checked again before the run.

## Phases

Every phase is one `forge script` invocation. `--skip-simulation` makes Foundry ask the node for the gas of each transaction; `--slow` makes it wait for each receipt before sending the next, which the phases with several senders (client, provider, jurors) require; `--code-size-limit 65536` lifts the EIP-170 limit of Foundry's local EVM for the script contract itself (34 KB of logic, run locally and never sent to the chain; Foundry 1.7 applies the 32,768-byte limit of `foundry.toml`, set for the ERC-8436 test fixture, to the script contract too, where Foundry 1.5 exempted it). The script deploys every contract from its compiled artifact (`vm.deployCode`) rather than with `new`, so that its own creation code stays under the EIP-3860 initcode limit, which Foundry 1.7 applies to the local deployment of the script contract as well; the artifacts come from the project's own build, and the contracts created on chain are byte for byte the ones `forge build` produced. The run was rehearsed on Anvil with these exact flags under Foundry 1.5.1 and 1.7.1. The state of the run is kept in `deployments/11155111.json` (addresses, identifiers, the two case ids and the issue id) and read back by every later phase.

```
RUN="forge script script/SepoliaEvidence.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --skip-simulation --gas-estimate-multiplier 150 --slow --code-size-limit 65536 -vv"

PHASE=deploy          $RUN   # policy registry, six modules, dispute registry, two verifiers, the evidence rule,
                              # the bridge over ACDF_REGISTRY, the ACDF fast-track policy, the attestor panel,
                              # the escrow, the ADRF policy and the binding; funds the five actors (about 20 tx)
PHASE=formal-file     $RUN   # client deposits and opens a call, provider delivers and settles it twice, client
                              # files, the verifier resolves, the round is decided (Provisional)
# wait 11 minutes (the 10-minute review window)
PHASE=formal-finalize $RUN   # finalizes; the escrow enacts the refund and reports Enacted
PHASE=judged-file     $RUN   # second call; client files the delivery claim; the bridge opens the ERC-8436 issue
PHASE=judged-vote     $RUN   # two jurors block the proposition; the deployer settles round 1 (No)
# wait 11 minutes (the 10-minute ERC-8436 appeal window)
PHASE=judged-finalize $RUN   # finalizes the issue, imports the Final result (FALSE), decides (Provisional)
# wait 11 minutes (the 10-minute review window)
PHASE=judged-close    $RUN   # finalizes; the escrow enacts the refund and reports Enacted
```

The fast-track ADRF policy uses a 1-day filing window, 30-minute acceptance and evidence windows, a 60-minute decision window, one 10-minute review, a 2h10m hard cap and a 10-minute enactment margin; the calls carry a 4-hour dispute period so that the clock check passes. The windows are short, so do not let more than about 50 minutes pass between `judged-file` and `judged-finalize` (the ERC-8436 issue's 40-minute hard cap plus the import must land inside the 60-minute decision window).

If a phase stops before its last transaction, do not simply run it again: the state file is written only at the end of a phase, and the earlier transactions of the phase are already on chain. Read `broadcast/SepoliaEvidence.s.sol/11155111/run-latest.json`, find the transaction that failed and why, and continue by hand or from a fresh deployment (a fresh `deploy` phase costs only gas; the earlier contracts stay as they are).

## Record

After the run, the record consists of:

1. `deployments/11155111.json` copied to `deployments/$RECORD.json` (every address and identifier of the run; `sepolia.json` for the revision-3 run, `sepolia-rev4.json` for the revision-4 run);
2. the transaction list: hash, block, status, gas used and effective gas price of every transaction of every phase, collected from `broadcast/SepoliaEvidence.s.sol/11155111/*.json` by `scripts/collect-sepolia-record.py` into `deployments/$RECORD.transactions.json` (the newest seven run files when the directory also holds an earlier run's; `--since` and `--all` choose otherwise, and the files used are printed);
3. the verification of the contracts on Sourcify from the standard JSON input (`forge verify-contract --verifier sourcify --chain 11155111 <address> <Contract>`, with `--constructor-args $(cast abi-encode "constructor(address)" <policyRegistry>)` for the six modules, the seven addresses for the dispute registry, the registry for the escrow and the registry and the ERC-8436 registry for the bridge);
4. the evidence document (`docs/sepolia-evidence.md` for revision 3, `docs/sepolia-evidence-rev4.md` for revision 4): the phases, the addresses, the policy and binding identifiers, the two case identifiers, the ERC-8436 issue identifier, the rulings and enactment statuses read back from the registry (`scripts/sepolia-readback.sh`, which in revision 4 also prints each settlement's state and the held value of each call), and the gas figures.

The files under 1 and 2, together with the `broadcast` directory of the run, are enough to write 3 and 4 afterwards.

## Rehearsal on Anvil

The same phases run against a local Anvil chain; this is how the run is rehearsed. Anvil must raise its code size limit for the vendored ERC-8436 fixture, which the script deploys when `ACDF_REGISTRY` is unset, and the clock is warped between the phases that wait for a window:

```
anvil --code-size-limit 32768 &
export PRIVATE_KEY=<anvil key 0>
for ph in deploy formal-file; do PHASE=$ph forge script script/SepoliaEvidence.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --code-size-limit 32768; done
cast rpc evm_increaseTime 660 --rpc-url http://127.0.0.1:8545 && cast rpc evm_mine --rpc-url http://127.0.0.1:8545
PHASE=formal-finalize forge script ...    # then judged-file, judged-vote, warp, judged-finalize, warp, judged-close
```

`deployments/31337.json` and the Anvil broadcast files are rehearsal records and are not kept in the repository.
