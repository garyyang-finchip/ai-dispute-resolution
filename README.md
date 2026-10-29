# ERC-8471: AI Dispute Resolution Framework (ADRF)

Reference repository of **ERC-8471, AI Dispute Resolution Framework (ADRF)** (Draft), for disputes about AI systems, resources and services and about the conduct, deliveries and declarations around them, between participants that may be people, organizations, agents or contracts: a dispute is a specific claim about a specific object — that an identified record, delivery, settlement, declaration or action does or does not conform to an obligation declared before the event — admitted under a pre-committed binding, resolved by typed methods and closed by a ruling whose effects are limited to what the binding authorized. What a dispute is about (which model, service, output, dataset, evaluation or promise) and how it is resolved (verifier, evidence, human or AI-assisted judgment, or a composition) are kept apart; nothing requires that AI be judged by AI, and nothing requires that a participant be an agent.

Status: Draft. ERC-8471 was assigned on 2026-10-29 in [ethereum/ERCs#2123](https://github.com/ethereum/ERCs/pull/2123) (filed on 2026-10-28 under the placeholder number 9999); discussion thread: [ERC-8471: AI Dispute Resolution Framework (ADRF)](https://ethereum-magicians.org/t/erc-8471-ai-dispute-resolution-framework-adrf/30121) on Ethereum Magicians. This repository holds revision 3 (v0.3: the dispute registry as one address over six modules, so that every deployable unit stays within the per-transaction gas limit of Sepolia and of the networks that follow it; revision 2 was the generalization from agent disputes to AI disputes): reference implementation, schemas, vectors, worked examples, a 70-test Foundry suite that runs the two complete flows against the vendored ERC-8436 reference registry, and the evidence run executed on Sepolia on 2026-10-29 against the live ERC-8436 registry (46 transactions, all successful; addresses below, record in `docs/sepolia-evidence.md`).

## What it is

The framework standardizes four objects, two registries and one closed loop, and consumes everything else from the standards that already provide it.

1. **Dispute Policy.** An immutable, content-addressed procedure template (`policyId = keccak256(abi.encode(PolicySpec))`): which method decides each (obligation kind, question type) pair — a deterministic **verifier** for formal questions, an **evidence rule** for questions of external fact, a **judgment method** for questions of judgment — with that binding's burden rule (`NOT_SUSTAINED` or `NO_DECISION` when the decisive finding is undetermined); the effect vocabulary (`SUBSTANTIVE` remedies and `PROCEDURAL_ECONOMIC` consequences); the track (filing, acceptance, evidence, decision and review windows, review types and count, the hard cap, the enactment margin, an optional optimistic default with its silence rule); the widest standing. Policies are versioned through families.
2. **Dispute Binding.** The obligation source's attributable adoption of one policy version for its objects: the acceptance mode (`PRE_COMMIT` or `POST_DISPUTE`), the effects a ruling may authorize (only what the source can enact), the executors, optional beneficiaries or open challenge, the clock downgrade rule. A ruling's authority comes from the binding and from nowhere else.
3. **Case.** One contested point, filed by a party with standing: the eight elements (object, event, claim, rules, subjects, authorization, evidence, effects), the roles kept apart — the object, the actor that performed the conduct (`actorRef`: an agent, a model service process, a human operator, a tool, a contract), the obligor (`respondent`), the judgment participants and the executors — with agent identities as optional references only, a table of typed sub-questions with declared premises, the findings each method produced with their **support kinds** (`signed`, `computed`, `evidenced`, `judged` — a set, never a hierarchy), the round decisions, and four dimensions read separately: procedure state, substantive result, reason, enactment status per effect. Admission is an algorithmic check of five criteria against what the source attests — identifiable object and event, accountable respondent, norm declared before the event, a bound method for every sub-question, open window — plus standing, authorized effects, clock compatibility (the business window must hold the whole procedure plus the margin) and exclusivity (one active Binding case per source, obligation and proposition).
4. **Ruling.** `Sustained` (the claim was supported, in the direction the claim itself fixed), `NotSustained` (not the opposite finding) or `NoDecision` (routed to the disposition the business committed in advance), with provenance, the one substantive effect it authorizes, the adoption flags of the round it came from and how the procedure closed.

The **J-profile** consumes [ERC-8436](https://eips.ethereum.org/ERCS/erc-8436) through its real interface: one `CONSUMER_FILED` issue per judged sub-question, one binary question, a fixed effect pair, and only a Final result is imported, with its issue, policy, source round, round count and adoption flag. The registries never move funds and never execute an effect: executors named by the binding read the ruling, check their own authority, amount, target and anti-duplication record, enact and report (`Enacted` is never overwritten; `Unknown` is not `Failed`).

Economic mechanisms are declared, not designed: the policy document states what every bond or fee arrangement serves, how it flows under every state and result, what it assumes and what happens on failure; receiving a reward proves no fact and forfeiting a bond proves no wrongdoing.

## Repository

```
ERCS/erc-adrf.md                     ERC text (source; the filing package names it erc-8471.md)
assets/erc-adrf/
  contracts/                         ADRFPolicyRegistry, ADRFDisputeRegistry, ADRFTypes, ADRFErrors,
                                     interfaces/ (incl. the vendored ERC-8436 interfaces under interfaces/acdf),
                                     libraries/ADRFStore (the storage record),
                                     modules/ (ADRFModule base; the six modules the registry runs by delegatecall
                                     on its own storage: Binding, Filing, Resolution, Decision, Record, Outcome),
                                     bridges/ADRFACDFBridge (the J-profile method),
                                     examples/ (DuplicateSettlementVerifier, DeclaredVersionVerifier, AttestorQuorumRule,
                                     ADRFServiceEscrow: a model API service escrow between plain accounts)
  schemas/                           JSON Schemas (policy, binding, case, finding, ruling, enactment, common)
  vectors/                           interface ids, identifiers and enumerations, policy id, keys
  examples/                          the model-API-service policy and binding, three cases (double charge, delivery
                                     quality, version commitment), four findings, three rulings, one enactment
                                     report, manifest.json with the content hashes
test/                                Foundry suite (70 tests): the two complete flows, admission, reviews and
                                     timeouts, the optimistic track, the policy registry, the generalization
                                     scenarios (plain accounts, committed / declared / actual version), the
                                     registry modules (routing, storage, logs, refusals), ethers <-> solc vectors;
                                     test/vendor/acdf holds the vendored ERC-8436 reference as a fixture
tools/                               build-examples.js, vectors.js, validate.js, lint-erc.js, lib/
script/SepoliaEvidence.s.sol         evidence run (deploy, formal flow, judged flow) in phases
scripts/make-filing-package.py       builds ercs-pr-package/ for the ethereum/ERCs pull request
scripts/sepolia-run.sh               drives the Sepolia evidence run (pre-flight, the seven phases, the record);
                                     collect-sepolia-record.py assembles the transaction record from the broadcast files
docs/                                design memo, Magicians post and revision notes, test record, evidence runbook
                                     and the Sepolia evidence record
deployments/                         the Sepolia record (sepolia.json, sepolia.transactions.json); the Anvil
                                     rehearsal writes 31337.json, ignored
```

## Build and test

```
npm install
forge build
forge test
npm run check          # rebuild the examples, regenerate the vectors, validate the examples against the schemas
npm run lint:erc       # eipw lint of the ERC text (spelling findings are listed, not gating)
python3 scripts/make-filing-package.py                 # --number and --discussions-to override the defaults (8471, the thread URL)
bash scripts/sepolia-run.sh preflight | all | record    # the Sepolia evidence run, driven end to end (docs/sepolia-runbook.md)
```

`forge build --sizes` reports every ADRF contract under 8,600 bytes of runtime code: the dispute registry (about 2 KB) routes each function of its interface to one of six modules by delegatecall on its own storage, with the original calldata and sender, so that no deployable unit of the kernel approaches the per-transaction gas limit of 16,777,216 (EIP-7825) under Sepolia's current gas schedule, which prices code at roughly 1,500 gas per deployed byte. The only contract above the EIP-170 size limit is the vendored ERC-8436 reference registry used as a test fixture, which this repository compiles with optimizer runs 200 (its own repository compiles it with runs 1); `foundry.toml` raises the test EVM's code size limit for that fixture only.

Deploying the kernel means deploying the policy registry, the six modules (each takes the policy registry's address) and then the dispute registry with the policy registry and the six module addresses; `script/SepoliaEvidence.s.sol` and `test/ADRFBase.t.sol` show the order. The modules are fixed at construction, refuse to run on their own storage and must have been built for the same policy registry.

## Evidence run

`script/SepoliaEvidence.s.sol` deploys the registries (the dispute registry with its six modules), the methods, the bridge over a live ERC-8436 registry (`ACDF_REGISTRY`; on Anvil it deploys the vendored reference), the worked-example escrow bound to a fast-track policy, and walks the two complete flows with real transactions in phases (`PHASE=deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close`); `scripts/sepolia-run.sh` drives the whole run and `docs/sepolia-runbook.md` explains it. The rehearsal on Anvil ran all seven phases successfully, and the run was executed on Sepolia on 2026-10-29 (blocks 12017706–12017916, 46 transactions, all successful, 131.3 million gas, 0.0077 ETH in fees): a double charge verified on chain and refunded, and a delivery-quality claim judged by a 2-of-3 roster through the live ERC-8436 registry, imported as a Final result and refunded. The record is `docs/sepolia-evidence.md` with `deployments/sepolia.json` and `deployments/sepolia.transactions.json`; `scripts/sepolia-readback.sh` reads the state back from the chain.

## Sepolia

Chain id 11155111; deployed 2026-10-29 by `0x2cF07458835437ce44C06f92BbfD30CCd3794dCF`; the live ERC-8436 registry is the acd-framework revision-3 `ACDFRegistry` `0x3bE57E74f2E7c280073b6B16A1Db3F562758dB01`.

| contract | address |
|---|---|
| `ADRFPolicyRegistry` | `0x071093a38289b5f9578D0162727b05A52E07eed5` |
| `ADRFDisputeRegistry` (one address for the whole interface) | `0x4e27C4728B22c3306f2378b8B421774dc35fE0a9` |
| `ADRFBindingModule` | `0x1D2CCC2eE1f8203d5f66aAA0f3a9b889253f32c2` |
| `ADRFFilingModule` | `0x64C86Cd5992DF93818479f4EEaA601FFf7C5f209` |
| `ADRFResolutionModule` | `0x75a104902744A5793306A25ea2bbDc85a0E77ce4` |
| `ADRFDecisionModule` | `0x87EDf76351Cbfc210Ae78a1487Ed4b0BB80c5d52` |
| `ADRFRecordModule` | `0x7F620C43eB7Bf43c19b20eAa49aBB37f93f1Be69` |
| `ADRFOutcomeModule` | `0x999BEf843E8ADba949e688C321D7b5bF37efea55` |
| `ADRFACDFBridge` (J-profile over ERC-8436) | `0xeC31cb06CEFCd871Bc36cD5267bC3fe9A21c60EB` |
| `DuplicateSettlementVerifier` | `0x2c5a24596E08379fF9CF9DfF3AaaD4861ba5c4Ae` |
| `DeclaredVersionVerifier` | `0x612fe0B072492FbaF9754032f2Ceb3bce2aBB6DC` |
| `AttestorQuorumRule` | `0xDe666e792730efE4E633D8E185a10Df4291dE597` |
| `ADRFServiceEscrow` (worked example) | `0xD85e5E73D385e6575342bd86263F34b17b287128` |

Identifiers of the run: ADRF policy `0x9f32ee8ce20bf6c70360e6f6d9565ea9a162055976c98ebe0b1cec8eb3244afb`, binding `0x4fe9f35788f6f53142542c2fd83c32ab447961985228a97f3ce60522d3f593f2`, formal case `0x1bc24c2ea078c1819f1b0914aadcb54570f8d87de3f28041e947f0c4590b88ee` (Final, Sustained, refund Enacted), judged case `0xee91e70309a170992baa2d537538745b55595891095442255c31392928e08c19` (Final, Sustained from the imported `FALSE`, refund Enacted), ERC-8436 issue `0xbe51f9c5657413332cab60ef0296e4fc7f8f5fc2814294a16890fade03d6a9c6` (Final, Decided, no). All thirteen contracts are verified on Sourcify (runtime and creation bytecode `match`; `scripts/sepolia-verify.sh`).

## Objects in scope

The first draft covers five open categories of objects: AI resources (a model version, a dataset, a toolkit, a resource declaration), AI systems and services (an endpoint, a deployed version, a service agreement, a billing period), AI execution and delivery (a request, an output, a training job, a report, a tool call), AI evaluation and declarations (an evaluation report, a metric statement, a capability or safety assertion) and AI governance and intervention (a suspension, a permission change, an eligibility or organizational decision). The relation to AI names the domain; the object, the obligation, the rule and the authorized effects decide admission, and a ruling's scope is fixed by its object. The standards of the agent economy are integration examples, never prerequisites.

## Design memo and discussion

`docs/design-memo.md` carries the consolidated design: the five admission criteria, the claim direction, support kinds as a set, the dependency table, the four dimensions, the adoption rule, effects in three layers, the J-profile's exact use of ERC-8436, the nine-standard coverage map, the walkthrough of the five scenarios and the reserved extensions. `docs/magicians-post.md` is the text of the discussion thread's first post; `docs/magicians-revision-3.md` is the revision-3 note.

## License

CC0-1.0 (see `LICENSE.md`).
