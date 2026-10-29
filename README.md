# ERC-8471: AI Dispute Resolution Framework (ADRF)

Reference repository of **ERC-8471, AI Dispute Resolution Framework (ADRF)** (Draft), for disputes about AI systems, resources and services and about the conduct, deliveries and declarations around them, between participants that may be people, organizations, agents or contracts: a dispute is a specific claim about a specific object — that an identified record, delivery, settlement, declaration or action does or does not conform to an obligation declared before the event — admitted under a pre-committed binding, resolved by typed methods and closed by a ruling whose effects are limited to what the binding authorized. What a dispute is about (which model, service, output, dataset, evaluation or promise) and how it is resolved (verifier, evidence, human or AI-assisted judgment, or a composition) are kept apart; nothing requires that AI be judged by AI, and nothing requires that a participant be an agent.

Status: Draft. ERC-8471 was assigned on 2026-10-29 in [ethereum/ERCs#2123](https://github.com/ethereum/ERCs/pull/2123) (filed on 2026-10-28 under the placeholder number 9999); discussion thread: [ERC-8471: AI Dispute Resolution Framework (ADRF)](https://ethereum-magicians.org/t/erc-8471-ai-dispute-resolution-framework-adrf/30121) on Ethereum Magicians. This repository holds revision 4 (v0.4: the obligation source attests the breaches — which proposition, taking which value, breaches which obligation under the norm — so that admission checks the decisive question and the claim's direction against the source instead of taking both from the filer; the exclusivity key is the decisive sub-question's proposition, not the claim's headline; the worked-example escrow holds every settlement until its dispute period lapses and attests each settlement beyond the first as a breach of its own, so that a further breach after a ruling is a new case and a sustained refund is always enactable within the deadline the escrow attests. Revision 3 was the dispute registry as one address over six modules, so that every deployable unit stays within the per-transaction gas limit of Sepolia and of the networks that follow it; revision 2 the generalization from agent disputes to AI disputes): reference implementation, schemas, vectors, worked examples, a 79-test Foundry suite that runs the two complete flows against the vendored ERC-8436 reference registry, and two evidence runs executed on Sepolia on 2026-10-29 against the live ERC-8436 registry — the revision-3 contracts (46 transactions; `docs/sepolia-evidence.md`) and the revision-4 contracts (45 transactions; addresses below, record in `docs/sepolia-evidence-rev4.md`), all successful.

## What it is

The framework standardizes four objects, two registries and one closed loop, and consumes everything else from the standards that already provide it.

1. **Dispute Policy.** An immutable, content-addressed procedure template (`policyId = keccak256(abi.encode(PolicySpec))`): which method decides each (obligation kind, question type) pair — a deterministic **verifier** for formal questions, an **evidence rule** for questions of external fact, a **judgment method** for questions of judgment — with that binding's burden rule (`NOT_SUSTAINED` or `NO_DECISION` when the decisive finding is undetermined); the effect vocabulary (`SUBSTANTIVE` remedies and `PROCEDURAL_ECONOMIC` consequences); the track (filing, acceptance, evidence, decision and review windows, review types and count, the hard cap, the enactment margin, an optional optimistic default with its silence rule); the widest standing. Policies are versioned through families.
2. **Dispute Binding.** The obligation source's attributable adoption of one policy version for its objects: the acceptance mode (`PRE_COMMIT` or `POST_DISPUTE`), the effects a ruling may authorize (only what the source can enact), the executors, optional beneficiaries or open challenge, the clock downgrade rule. A ruling's authority comes from the binding and from nowhere else.
3. **Case.** One contested point, filed by a party with standing: the eight elements (object, event, claim, rules, subjects, authorization, evidence, effects), the roles kept apart — the object, the actor that performed the conduct (`actorRef`: an agent, a model service process, a human operator, a tool, a contract), the obligor (`respondent`), the judgment participants and the executors — with agent identities as optional references only, a table of typed sub-questions with declared premises, the findings each method produced with their **support kinds** (`signed`, `computed`, `evidenced`, `judged` — a set, never a hierarchy), the round decisions, and four dimensions read separately: procedure state, substantive result, reason, enactment status per effect. Admission is an algorithmic check of five criteria against what the source attests — identifiable object and event, accountable respondent, a norm declared before the event under which the source recognizes the contested point as a breach (the decisive sub-question, in the direction the claim names: the source, not the filer, says what counts as a breach and in which sense), a bound method for every sub-question, open window — plus standing, authorized effects, clock compatibility (the business window must hold the whole procedure plus the margin) and exclusivity (one active Binding case per source, obligation and decisive proposition).
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
                                     examples/ (DuplicateSettlementVerifier and DeclaredVersionVerifier with the
                                     statement libraries that publish their canonical propositions, AttestorQuorumRule,
                                     ADRFServiceEscrow: a model API service escrow between plain accounts that holds
                                     each settlement until its dispute period lapses and recognizes the breaches its
                                     terms make contestable)
  schemas/                           JSON Schemas (policy, binding, case, finding, ruling, enactment, common)
  vectors/                           interface ids, identifiers and enumerations, policy id, keys
  examples/                          the model-API-service policy and binding, three cases (double charge, delivery
                                     quality, version commitment), four findings, three rulings, one enactment
                                     report, manifest.json with the content hashes
test/                                Foundry suite (79 tests): the two complete flows, admission, reviews and
                                     timeouts, the optimistic track, the policy registry, the generalization
                                     scenarios (plain accounts, committed / declared / actual version), the
                                     registry modules (routing, storage, logs, refusals), recognition by the
                                     source (direction, choice of question, exclusivity on the decisive point,
                                     one case per breach, held settlements, a late executor), ethers <-> solc
                                     vectors; test/vendor/acdf holds the vendored ERC-8436 reference as a fixture
tools/                               build-examples.js, vectors.js, validate.js, lint-erc.js, lib/
script/SepoliaEvidence.s.sol         evidence run (deploy, formal flow, judged flow) in phases
scripts/make-filing-package.py       builds ercs-pr-package/ for the ethereum/ERCs pull request
scripts/sepolia-run.sh               drives the Sepolia evidence run (pre-flight, the seven phases, the record);
                                     collect-sepolia-record.py assembles the transaction record from the broadcast files
docs/                                design memo, Magicians post and revision notes, test record, evidence runbook
                                     and the two Sepolia evidence records
deployments/                         the Sepolia records: sepolia-rev4.json / sepolia-rev4.transactions.json (revision 4)
                                     and sepolia.json / sepolia.transactions.json (revision 3); the Anvil rehearsal
                                     writes 31337.json, ignored
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

`forge build --sizes` reports every ADRF contract under 9,300 bytes of runtime code (the kernel under 8,800; the worked-example escrow, which now keeps a settlement ledger, is the largest at 9,209): the dispute registry (about 2 KB) routes each function of its interface to one of six modules by delegatecall on its own storage, with the original calldata and sender, so that every deployable unit stays within the per-transaction gas limit of 16,777,216 (EIP-7825) under Sepolia's current gas schedule, which prices a creation at roughly 1,570 to 1,800 gas per deployed byte (the escrow at about 88% of the cap, the largest kernel units at about 82%). The only contract above the EIP-170 size limit is the vendored ERC-8436 reference registry used as a test fixture, which this repository compiles with optimizer runs 200 (its own repository compiles it with runs 1); `foundry.toml` raises the test EVM's code size limit for that fixture only.

Deploying the kernel means deploying the policy registry, the six modules (each takes the policy registry's address) and then the dispute registry with the policy registry and the six module addresses; `script/SepoliaEvidence.s.sol` and `test/ADRFBase.t.sol` show the order. The modules are fixed at construction, refuse to run on their own storage and must have been built for the same policy registry.

## Evidence run

`script/SepoliaEvidence.s.sol` deploys the registries (the dispute registry with its six modules), the methods, the bridge over a live ERC-8436 registry (`ACDF_REGISTRY`; on Anvil it deploys the vendored reference), the worked-example escrow bound to a fast-track policy, and walks the two complete flows with real transactions in phases (`PHASE=deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close`); `scripts/sepolia-run.sh` drives the whole run and `docs/sepolia-runbook.md` explains it. The rehearsal on Anvil ran all seven phases successfully, and the run was executed on Sepolia twice on 2026-10-29: with the revision-3 contracts (blocks 12017706–12017916, 46 transactions, 131.3 million gas, 0.0077 ETH in fees) and with the revision-4 contracts (blocks 12021936–12022145, 45 transactions, 132.4 million gas, 0.0021 ETH in fees; the ERC-8436 fast-track policy registered by the first run was reused), all transactions successful. Each run: a double charge verified on chain and refunded — in revision 4 as a claim about the second settlement under the proposition the escrow recognizes for it, refunded from the held settlement while the first charge stays held — and a delivery-quality claim judged by a 2-of-3 roster through the live ERC-8436 registry, imported as a Final result and refunded. The records are `docs/sepolia-evidence-rev4.md` with `deployments/sepolia-rev4.json` and `deployments/sepolia-rev4.transactions.json` (revision 4) and `docs/sepolia-evidence.md` with `deployments/sepolia.json` and `deployments/sepolia.transactions.json` (revision 3); `scripts/sepolia-readback.sh` reads either state back from the chain (`RECORD=sepolia` for revision 3).

## Sepolia

Chain id 11155111; the revision-4 deployment of 2026-10-29 by `0x2cF07458835437ce44C06f92BbfD30CCd3794dCF`; the live ERC-8436 registry is the acd-framework revision-3 `ACDFRegistry` `0x3bE57E74f2E7c280073b6B16A1Db3F562758dB01`.

| contract | address |
|---|---|
| `ADRFPolicyRegistry` | `0x9AA578eBbc6af2a3E0a015a0fFCc6330ba4BeEd5` |
| `ADRFDisputeRegistry` (one address for the whole interface) | `0x48aBDc76a736546CB3C3B122C9964BC294aE2508` |
| `ADRFBindingModule` | `0xb0e25665A4d01e3C79E9311A9131A25A44556aD8` |
| `ADRFFilingModule` | `0x5431Dc074dd8Bebb448C392FA78aDf1c3e9619F1` |
| `ADRFResolutionModule` | `0x35c5F124C61d57C7a05fd9F5E2c7edcFaa30164D` |
| `ADRFDecisionModule` | `0xb774b07eB88c9CE0529eABcDb18E02cd597E4A31` |
| `ADRFRecordModule` | `0xB0A9eCBA656b45e20DA99D5060D2d5aFF72fa8C2` |
| `ADRFOutcomeModule` | `0xa2b81153235199231E6AFe043CF0E422f8fEF239` |
| `ADRFACDFBridge` (J-profile over ERC-8436) | `0x5535588f5eA314B94Fa24567Bb3990Dfd7Ee0fE6` |
| `DuplicateSettlementVerifier` | `0x1ec495d02805BB47852cB3E26370a340d1305812` |
| `DeclaredVersionVerifier` | `0x6AB0a55D7cAeFc481f85750932420c7a06Aa25cf` |
| `AttestorQuorumRule` | `0x1EE8443547eB9940832bcCDB70a90057FCE9056f` |
| `ADRFServiceEscrow` (worked example) | `0x698E06aE8C3bc0aa1E2ec12D9A378341b71776B1` |

Identifiers of the run: ADRF policy `0x12dabe57f36ed3916d9b5ae2e19e0e3c647f8d6293d598603ff3e2e5da036704`, binding `0x38b7674762744f0ecd970057817ae83721483d6a21e89f7ca86446d92b503831`, formal case `0xafb715e37d13695bf0b7aa7526d5ad5c6e17c0a87380b4452a769f1c25010b7f` (settlement 2 of call 1; Final, Sustained, refund of that settlement Enacted, settlement 1 still held), judged case `0xc7b6796b73e9e012144439a302cca7ced120a95c08bb2746f496777a8fcb7011` (Final, Sustained from the imported `FALSE`, refund Enacted), ERC-8436 issue `0x71f297051b9077fb3790afacc83c6481296be9f14d6e38f97931a3a1afe9b012` (Final, Decided, no) under the ERC-8436 fast-track policy `0x328b3d82efbd959e49752c0b658e8284a93d6b6ba92c49ae8df8613d61be570a` registered by the revision-3 run. All thirteen contracts are verified on Sourcify (runtime and creation bytecode `match`; `scripts/sepolia-verify.sh`).

The revision-3 deployment of the same day (dispute registry `0x4e27C4728B22c3306f2378b8B421774dc35fE0a9`, policy registry `0x071093a38289b5f9578D0162727b05A52E07eed5`, escrow `0xD85e5E73D385e6575342bd86263F34b17b287128`; the full table in `docs/sepolia-evidence.md`) stays deployed and verified; nine of its thirteen contracts are byte for byte the revision-4 ones, the other four (`ADRFBindingModule`, `ADRFFilingModule`, `DuplicateSettlementVerifier`, `ADRFServiceEscrow`) are the revision-3 versions.

## Objects in scope

The first draft covers five open categories of objects: AI resources (a model version, a dataset, a toolkit, a resource declaration), AI systems and services (an endpoint, a deployed version, a service agreement, a billing period), AI execution and delivery (a request, an output, a training job, a report, a tool call), AI evaluation and declarations (an evaluation report, a metric statement, a capability or safety assertion) and AI governance and intervention (a suspension, a permission change, an eligibility or organizational decision). The relation to AI names the domain; the object, the obligation, the rule and the authorized effects decide admission, and a ruling's scope is fixed by its object. The standards of the agent economy are integration examples, never prerequisites.

## Design memo and discussion

`docs/design-memo.md` carries the consolidated design: the five admission criteria, the claim direction and the source's recognition of the breach, exclusivity on the decisive point, support kinds as a set, the dependency table, the four dimensions, the adoption rule, effects in three layers, the held value behind an adoption deadline, the J-profile's exact use of ERC-8436, the nine-standard coverage map, the walkthrough of the five scenarios and the reserved extensions. `docs/magicians-post.md` is the text of the discussion thread's first post; `docs/magicians-revision-3.md`, `docs/magicians-sepolia.md`, `docs/magicians-revision-4.md` and `docs/magicians-sepolia-rev4.md` are the revision-3, Sepolia, revision-4 and second-Sepolia notes posted there.

## License

CC0-1.0 (see `LICENSE.md`).
