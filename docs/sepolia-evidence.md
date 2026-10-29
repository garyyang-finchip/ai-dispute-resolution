# Sepolia evidence (ERC-8471, revision 3)

The evidence run of `script/SepoliaEvidence.s.sol` was executed on Sepolia (chain id 11155111) on 2026-10-29 between 06:27:48 and 07:09:48 UTC, blocks 12017706 to 12017916: the ADRF kernel (the policy registry, the six modules and the dispute registry), the three methods, the bridge over the live ERC-8436 registry, the worked-example escrow bound to a fast-track policy, and the two complete flows — a double charge verified on chain and a delivery-quality claim judged by an ERC-8436 roster — with real transactions. 46 transactions, all successful, 131,281,303 gas, 0.007737 ETH in fees. The files of the record are `deployments/sepolia.json` (addresses and identifiers), `deployments/sepolia.transactions.json` (every transaction with hash, block, status, gas used and effective gas price) and this document; `scripts/sepolia-readback.sh` reads the state below back from the chain and `scripts/sepolia-verify.sh` submits the contracts to Sourcify.

## Execution

Foundry 1.7.1 (forge, cast), solc 0.8.30, via-IR, optimizer runs 200, EVM cancun — the settings of `foundry.toml`, so the contracts on chain are the ones `forge build` produces from this repository. The run was driven by `scripts/sepolia-run.sh all`: a pre-flight (chain id, balance, the live ERC-8436 registry, the six largest creations estimated by the node against the 16,777,216-gas per-transaction cap), then the seven phases with `forge script --broadcast --skip-simulation --gas-estimate-multiplier 150 --slow --code-size-limit 65536`, waiting eleven minutes where a window had to lapse, then the record. Every gas limit came from the node's `eth_estimateGas` (`--skip-simulation`); each transaction was confirmed before the next was sent (`--slow`); the script contract itself deploys from the compiled artifacts (`vm.deployCode`) so that its own creation code stays under the EIP-3860 limit that Foundry 1.7 applies to it locally, and `--code-size-limit 65536` lifts the EIP-170 limit of the local EVM for that same script contract (34 KB of logic, never sent to the chain).

Sepolia's current gas schedule, as measured by this run: creation cost between 1,571 and 1,804 gas per byte of deployed code (the three largest units at 80% of the cap, as the pre-flight had estimated to within 1%), a plain transfer to an empty account 204,600 gas, `file` about 3.55 million gas, `openJudgment` (which files the ERC-8436 issue) 2.41 million, `importResult` 1.41 million, `finalize` of the dispute registry 0.87 to 1.30 million. The base fee was 15 to 16 wei throughout; the effective gas prices (0.04 gwei for most of the run, 1 gwei for the three transactions of judged-finalize) are the priority fees the node suggested to Foundry at the time, not congestion, and they make up nearly all of the 0.007737 ETH in fees.

Keys: the deployer `0x2cF07458835437ce44C06f92BbfD30CCd3794dCF` (the same key as the ERC-8436 Sepolia runs; it also acts as the update authority of both policies and as the one who finalizes); the client `0xE04D884490Ac5848A49Bd7140e5983254bB84177`, the provider `0xABa669deB8d4e225A3ff3ead53dB601aaaf77Aae` and the three jurors `0xe60Cb8479D42821Eea4774585DEE1b2faaD92d2C`, `0xDf2Ec6C9540cE362D6f19cA62362aa6A3ED8AC05`, `0xdf7f3b20669D4B3E495A43b0c85225a04DcffCe9`, derived from it inside the script and funded by it in the deploy phase (0.012, 0.004 and three times 0.002 ETH).

## Contracts

| contract | address | runtime bytes | creation gas | gas per byte | creation tx |
|---|---|---|---|---|---|
| `ADRFPolicyRegistry` | `0x071093a38289b5f9578D0162727b05A52E07eed5` | 8,540 | 13,412,984 | 1,571 | `0x8b68d0a6f8c2d25fb6451d645f59cdea12abccd57d4fcede7430642e58591a33` |
| `ADRFBindingModule` | `0x1D2CCC2eE1f8203d5f66aAA0f3a9b889253f32c2` | 5,801 | 9,177,233 | 1,582 | `0x7d5c4102f97045db7ca9fbeaaab10b84cf3680f7d3ac951ca7353f2694b54ab7` |
| `ADRFFilingModule` | `0x64C86Cd5992DF93818479f4EEaA601FFf7C5f209` | 8,483 | 13,326,515 | 1,571 | `0x0463975602d97fba40d5440fb88221596efdb18f1a8bc2a06979a4127c266a90` |
| `ADRFResolutionModule` | `0x75a104902744A5793306A25ea2bbDc85a0E77ce4` | 7,062 | 11,128,008 | 1,576 | `0xa9f4812a7fec95372446dc07cf0db04dde9c228fe76a5071863e10ebd083d5d5` |
| `ADRFDecisionModule` | `0x87EDf76351Cbfc210Ae78a1487Ed4b0BB80c5d52` | 8,535 | 13,404,970 | 1,571 | `0xf5aa9e7fe33a0c47541817bbfb76f6c3d7fcdc62f9c918d9869bad5d5f24c99a` |
| `ADRFRecordModule` | `0x7F620C43eB7Bf43c19b20eAa49aBB37f93f1Be69` | 3,895 | 6,231,090 | 1,600 | `0xc19415bcfb2ed4b8e23789b985dc43a891105a0a113b23d2f6917e28bff1b1ab` |
| `ADRFOutcomeModule` | `0x999BEf843E8ADba949e688C321D7b5bF37efea55` | 5,830 | 9,224,177 | 1,582 | `0xa56627b18697a2bd5e3bf982812886d4206d8a696b4dbc34ab664807360fdd9d` |
| `ADRFDisputeRegistry` | `0x4e27C4728B22c3306f2378b8B421774dc35fE0a9` | 2,043 | 3,398,278 | 1,663 | `0xd0450f5ff7242bc6df155e871e0d759e243f07d6faf8ec8c45ab560f2744a252` |
| `DuplicateSettlementVerifier` | `0x2c5a24596E08379fF9CF9DfF3AaaD4861ba5c4Ae` | 806 | 1,454,202 | 1,804 | `0xb88f427925d7e55d2a1582a78c271e5f8791c5a0fb6768f6a08af5b4d170fa28` |
| `DeclaredVersionVerifier` | `0x612fe0B072492FbaF9754032f2Ceb3bce2aBB6DC` | 900 | 1,599,581 | 1,777 | `0xfd4fbf0720df67a8abe3428de4e35bda6e1e6eb77d7edbc108a7c058bc13820d` |
| `AttestorQuorumRule` | `0xDe666e792730efE4E633D8E185a10Df4291dE597` | 2,048 | 3,374,960 | 1,648 | `0x1a30dbdc7d280e4fd1bb8e4ebe370c9f44bee01bcdaea0feb0a961318cd09623` |
| `ADRFACDFBridge` | `0xeC31cb06CEFCd871Bc36cD5267bC3fe9A21c60EB` | 4,782 | 7,608,126 | 1,591 | `0xac1c843898c7e42493f18d5deaf9e8e9d101c3ae585047d9b2661a06e620d2e4` |
| `ADRFServiceEscrow` | `0xD85e5E73D385e6575342bd86263F34b17b287128` | 7,175 | 11,414,043 | 1,591 | `0x725ebc3a74a3e1c395dcbb0abe7514dac77e44248e2455472b9e90d739f00c34` |

The dispute registry was constructed over the six modules and the policy registry; `moduleOf` routes every function of `IADRFDisputeRegistry` to them, `supportsInterface(0xedc59c17)` answers true, `policies()` is the policy registry above and `CLOCK_MODE()` is `mode=timestamp`. The live ERC-8436 registry is the revision-3 deployment of the acd-framework repository, `ACDFRegistry` `0x3bE57E74f2E7c280073b6B16A1Db3F562758dB01` with `ACDFPolicyRegistry` `0x7eAfCC452EC0A60a358a26B6e73f28413C4abeF0`. All thirteen contracts are verified on Sourcify from the standard JSON input with their constructor arguments (`scripts/sepolia-verify.sh`, 2026-10-29): runtime and creation bytecode both `match` for every address (`https://sourcify.dev/server/v2/contract/11155111/<address>`); the build sets `bytecode_hash = "none"`, so the deployed code carries no metadata hash and Sourcify reports `match` rather than `exact_match`, as it does for the earlier runs of this standards family.

## Identifiers

| | |
|---|---|
| ERC-8436 fast-track policy (`acdfPolicyId`; 2-of-3 roster, 15-minute window, one 10-minute appeal, 40-minute cap) | `0x328b3d82efbd959e49752c0b658e8284a93d6b6ba92c49ae8df8613d61be570a` |
| attestor panel (`panelId`; 2 of 3) | `0x98be549800d80376d79dd075fe0debaaf7f8511d6a592db178ca44292cdc67ee` |
| ADRF fast-track policy (`policyId`) | `0x9f32ee8ce20bf6c70360e6f6d9565ea9a162055976c98ebe0b1cec8eb3244afb` |
| binding of the escrow (`bindingId`; PRE_COMMIT; effects `refund`, `fee-split`) | `0x4fe9f35788f6f53142542c2fd83c32ab447961985228a97f3ce60522d3f593f2` |
| formal case (double charge, call 1) | `0x1bc24c2ea078c1819f1b0914aadcb54570f8d87de3f28041e947f0c4590b88ee` |
| judged case (delivery quality, call 2) | `0xee91e70309a170992baa2d537538745b55595891095442255c31392928e08c19` |
| ERC-8436 issue of the judged case | `0xbe51f9c5657413332cab60ef0296e4fc7f8f5fc2814294a16890fade03d6a9c6` |
| `EFFECT_REFUND` = keccak256("adrf:effect/refund") | `0xe074020771795b0306209d2eb94e35a28bef8f823d7e65825aa3c0757e4626a9` |

The ADRF policy binds four methods: the duplicate-settlement verifier for FORMAL questions of kind `KIND_LIMIT`, the declared-version verifier for FORMAL questions of kind `KIND_RESULT`, the bridge (with the ERC-8436 policy as parameters) for JUDGED questions of kind `KIND_RESULT` with the burden rule `NO_DECISION`, and the attestor-quorum rule for EVIDENCED questions of any kind; its track is a 1-day filing window, 30-minute acceptance and evidence windows, a 60-minute decision window, one 10-minute review under `PRESERVE_UNLESS_OVERTURNED`, a 2h10m hard cap and a 10-minute enactment margin; standing `BENEFICIARIES`. The calls carry a 4-hour dispute period, so the clock check (`adoptionDeadline >= now + maxTotalDuration + enactmentMargin`) passed on both filings.

## The run, phase by phase

Timestamps are block times (UTC, 2026-10-29); every transaction is in `deployments/sepolia.transactions.json`.

**deploy** (blocks 12017706–12017727, 06:27:48–06:32:00; 22 transactions, 112,543,765 gas). The thirteen creations above, in that order; `registerPolicy` of the fast-track policy on the live ERC-8436 policy registry (`0xc52af560…`, 1,931,470 gas); `registerPanel` on the attestor rule (`0x99684129…`); `registerPolicy` of the ADRF policy (`0xfe3a0ed8…`, 3,291,443 gas); `bindTo` by the escrow (`0x28b9796c…`); the five funding transfers (204,600 gas each).

**formal-file** (blocks 12017728–12017735, 06:32:12–06:33:36; 8 transactions). The client deposits 0.004 ETH and opens call 1 to the provider for 0.001 ETH with the terms hash and the committed version `keccak256("model v2")` and a 4-hour dispute period; the provider delivers (declaring the same version) and settles the call twice (`0xae483c40…` at 06:32:48, `0x050d6ec1…` at 06:33:00 — the double charge, the event of the claim). The client files the claim "the call was charged twice" against the provider with one FORMAL sub-question bound to the duplicate-settlement verifier (`0xcc3bc7ac…`, 3,549,740 gas); admission passed the five criteria and the case was admitted at 06:33:12 under PRE_COMMIT; `resolveFormal` with the pinned inputs ran the verifier, which answered `TRUE` with support `computed` (`0xf55be15c…`, 06:33:24); `decide` mapped the finding to `Sustained` through the claim's direction (`0x20603d59…`, 06:33:36) and opened the 10-minute review window (Provisional).

**formal-finalize** (blocks 12017791–12017792, 06:44:48–06:45:00). The review window lapsed without a review; `finalize` adopted the round (`0x33d105d5…`, closure `REVIEW_LAPSED`, state Final) and the escrow, as the executor named by the binding, enacted the refund of the duplicate settlement and reported `Enacted` (`0x1c9b8c18…`).

**judged-file** (blocks 12017793–12017798, 06:45:12–06:46:12). Call 2 is opened, delivered and settled once; the client files "the delivery does not conform" with one JUDGED sub-question (`0x8851e1af…`, admitted at 06:46:00) and `openJudgment` makes the bridge file one `CONSUMER_FILED` issue with the live ERC-8436 registry under the fast-track policy (`0xc8e469d8…`, 2,414,287 gas; issue filed and admitted at 06:46:12, `consumerDeadline` 07:46:00 = the case's decision deadline, hard deadline 07:26:12).

**judged-vote** (blocks 12017799–12017801, 06:46:24–06:46:36). Two of the three jurors cast `block` ballots (`0x1c7f83d5…`, `0xcf1dfa45…`); the deployer settles round 1 (`0x09e4aa5b…`): outcome Decided, `outcomeYes = false`, decided at 06:46:36, appeal window open until 06:56:36.

**judged-finalize** (blocks 12017857–12017859, 06:58:00–06:58:24). No appeal; `finalize` of the issue (`0x981065f4…`, Final at 06:58:00); `importResult` by the bridge records the finding `FALSE` with support `judged` and the provenance (registry, issue, policy, source round 1 of 1, not adopted from an earlier round) (`0xe2891d82…`, 1,407,604 gas); `decide` maps `FALSE` to the claim's direction (`supportsWhen = FALSE`) and the round is `Sustained` (`0xda3884fd…`, 06:58:24, Provisional).

**judged-close** (blocks 12017915–12017916, 07:09:36–07:09:48). The review window lapsed; `finalize` (`0x9a8b7292…`, closure `REVIEW_LAPSED`, Final) and the escrow enacts the refund of call 2 and reports `Enacted` (`0x7fb1ec97…`).

## The state read back from the chain

Read on 2026-10-29 after the run (head block 12017973) with `scripts/sepolia-readback.sh`; the raw tuples are in the script's output, the decoded values are these.

**Formal case** `0x1bc24c2e…`: `getCase` — policy and binding as above, source the escrow, effect class `Binding`, state `Final`, claimant the client, respondent the provider, `actorRef` 0, object `(11155111, escrow, 1, 0xf28aab73…)`, obligation kind 3 (`KIND_LIMIT`), one sub-question, decisive 0, `supportsWhen = TRUE`. `getClock` — event 06:33:00, filed and admitted 06:33:12, evidence close 07:03:12, decision deadline 07:33:12, hard deadline 08:43:12, round count 1, no review used. `getFinding(0)` — resolved, `TRUE`, support kinds 2 (`computed`), accepted by the duplicate-settlement verifier, reason `NONE`, round 1, at 06:33:24. `getRound(1)` — `Sustained`, reason `NONE`, at 06:33:36, not by silence, support kinds 2, decisive value `TRUE`. `getRuling` — state `Final`, result `Sustained`, effect class `Binding`, reason `NONE`, closure `REVIEW_LAPSED`, decided 06:33:36, final 06:44:48, round count 1, source round 1, not adopted from an earlier round, not by silence, support kinds 2, allowed effect `EFFECT_REFUND`, no fallback. `getEnactment(case, EFFECT_REFUND)` — `Enacted`, reporter the escrow, ref `0x28a47c10…`, at 06:45:00; `escrow.refunded(case) = true`; `settlementCount(1) = 2`.

**Judged case** `0xee91e703…`: `getCase` — same policy, binding and parties, object `(11155111, escrow, 2, 0x02071ec5…)`, obligation kind 1 (`KIND_RESULT`), `supportsWhen = FALSE`. `getClock` — event 06:45:36, filed and admitted 06:46:00, decision deadline 07:46:00, hard deadline 08:56:00. `getFinding(0)` — resolved, `FALSE`, support kinds 8 (`judged`), accepted by the bridge, round 1, at 06:58:12, source `(0x3bE57E74…, issue 0xbe51f9c5…, policy 0x328b3d82…, source round 1, round count 1, adoptedFromEarlierRound false, reason 0)`. `getRound(1)` — `Sustained`, at 06:58:24, support kinds 8, decisive value `FALSE`, the same judgment provenance. `getRuling` — `Final`, `Sustained`, `Binding`, reason `NONE`, closure `REVIEW_LAPSED`, decided 06:58:24, final 07:09:36, round 1 of 1, support kinds 8, allowed effect `EFFECT_REFUND`, judgment provenance as above. `getEnactment` — `Enacted`, reporter the escrow, ref `0x75308342…`, at 07:09:48; `escrow.refunded(case) = true`; `settlementCount(2) = 1`; `versionsOf(2)` committed = declared = `keccak256("model v2")`.

**ERC-8436 issue** `0xbe51f9c5…` on `0x3bE57E74…`: `getIssue` — policy `0x328b3d82…`, mode 0 (`CONSUMER_FILED`), effect class Binding, state Final, filer and consumer the bridge, subject `(11155111, 0x4e27C472…, uint256(caseId), proposition 0x39a1be8a…)`, question `0xcd6728e2…` = keccak256(abi.encode(keccak256("adrf:judgment/v1"), subQuestion)), `effectYes` `0xb22ccd97…` (`adrf:finding/TRUE`), `effectNo` `0x046e2284…` (`adrf:finding/FALSE`), disposition `0xbeb05e22…` (`adrf:finding/UNDETERMINED`), filed and admitted 06:46:12, consumer deadline 07:46:00, hard deadline 07:26:12, final 06:58:00, round count 1, outcome type Decided, `outcomeYes = false`, source round 1, decided 06:46:36. `getResult` — Final, Decided, no, decided 06:46:36, final 06:58:00, round 1 of 1, not adopted from an earlier round. `bridge.issueOf(keccak256(abi.encode(caseId, 0)))` is the issue.

**Balances** after the run: deployer 0.001885 ETH, client 0.005461, provider 0.003965, jurors 0.001987, 0.001992 and 0.002000 (the third juror did not vote), the escrow holds 0.006 ETH on its internal ledger (two deposits; the refunds moved the client's share back inside the ledger).

## Gas by phase

| phase | transactions | gas | fees (ETH) |
|---|---|---|---|
| deploy | 22 | 112,543,765 | 0.004502 |
| formal-file | 8 | 5,577,967 | 0.000223 |
| formal-finalize | 2 | 1,465,474 | 0.000101 |
| judged-file | 6 | 7,015,576 | 0.000351 |
| judged-vote | 3 | 667,227 | 0.000032 |
| judged-finalize | 3 | 2,114,140 | 0.002114 |
| judged-close | 2 | 1,897,154 | 0.000415 |
| total | 46 | 131,281,303 | 0.007737 |

## Reproducing the checks

```
export SEPOLIA_RPC_URL=...
bash scripts/sepolia-readback.sh                       # everything under "The state read back from the chain"
cast call 0x4e27C4728B22c3306f2378b8B421774dc35fE0a9 "supportsInterface(bytes4)(bool)" 0xedc59c17 --rpc-url $SEPOLIA_RPC_URL
cast call 0x4e27C4728B22c3306f2378b8B421774dc35fE0a9 "moduleOf(bytes4)(address)" 0x$(cast sig "file(bytes32,((uint256,address,uint256,bytes32),bytes32,bytes32,bytes32,bytes32,uint8,address,bytes32,bytes32[],bytes32,bytes32,bytes32,bytes32,bytes32,uint32,uint8,(bytes32,uint8,uint8,bytes32,uint32[],uint8[])[]))" | cut -c3-) --rpc-url $SEPOLIA_RPC_URL
cast call 0xD85e5E73D385e6575342bd86263F34b17b287128 "refunded(bytes32)(bool)" 0x1bc24c2ea078c1819f1b0914aadcb54570f8d87de3f28041e947f0c4590b88ee --rpc-url $SEPOLIA_RPC_URL
cast receipt 0xcc3bc7ac784d107e6f2449709cb735ca7fd6e5f0cad7b9271be2bdae2e8088ab --rpc-url $SEPOLIA_RPC_URL   # the formal filing: CaseFiled and CaseAdmitted under the registry's address
```

The second call answers the filing module's address, `0x64C86Cd5…`: the function was served at the registry's address by the module, and the logs of the filing receipt are under the registry's address, as the module tests assert.
