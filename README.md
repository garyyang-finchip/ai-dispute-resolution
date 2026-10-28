# AI Dispute Resolution Framework (ADRF)

Reference repository of the draft ERC **AI Dispute Resolution Framework (ADRF)**, for disputes about AI systems, resources and services and about the conduct, deliveries and declarations around them, between participants that may be people, organizations, agents or contracts: a dispute is a specific claim about a specific object — that an identified record, delivery, settlement, declaration or action does or does not conform to an obligation declared before the event — admitted under a pre-committed binding, resolved by typed methods and closed by a ruling whose effects are limited to what the binding authorized. What a dispute is about (which model, service, output, dataset, evaluation or promise) and how it is resolved (verifier, evidence, human or AI-assisted judgment, or a composition) are kept apart; nothing requires that AI be judged by AI, and nothing requires that a participant be an agent.

Status: Draft, not yet filed. The ERC text carries the placeholder number 9999 and a placeholder `discussions-to`; both are replaced when the Ethereum Magicians thread is posted and the ethereum/ERCs pull request is opened (see `scripts/make-filing-package.py`). This repository holds revision 2 (v0.2, the generalization from agent disputes to AI disputes): reference implementation, schemas, vectors, worked examples, a 64-test Foundry suite that runs the two complete flows against the vendored ERC-8436 reference registry, and an evidence script rehearsed end to end on Anvil.

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
ERCS/erc-adrf.md                     ERC text (source; the filing package renames it erc-<number>.md)
assets/erc-adrf/
  contracts/                         ADRFPolicyRegistry, ADRFDisputeRegistry, ADRFTypes, ADRFErrors,
                                     interfaces/ (incl. the vendored ERC-8436 interfaces under interfaces/acdf),
                                     libraries/ (ADRFStore; ADRFAdmission and ADRFLifecycle: the registry's
                                     admission and lifecycle as externally linked libraries),
                                     bridges/ADRFACDFBridge (the J-profile method),
                                     examples/ (DuplicateSettlementVerifier, DeclaredVersionVerifier, AttestorQuorumRule,
                                     ADRFServiceEscrow: a model API service escrow between plain accounts)
  schemas/                           JSON Schemas (policy, binding, case, finding, ruling, enactment, common)
  vectors/                           interface ids, identifiers and enumerations, policy id, keys
  examples/                          the model-API-service policy and binding, three cases (double charge, delivery
                                     quality, version commitment), four findings, three rulings, one enactment
                                     report, manifest.json with the content hashes
test/                                Foundry suite (64 tests): the two complete flows, admission, reviews and
                                     timeouts, the optimistic track, the policy registry, the generalization
                                     scenarios (plain accounts, committed / declared / actual version),
                                     ethers <-> solc vectors;
                                     test/vendor/acdf holds the vendored ERC-8436 reference as a fixture
tools/                               build-examples.js, vectors.js, validate.js, lint-erc.js, lib/
script/SepoliaEvidence.s.sol         evidence run (deploy, formal flow, judged flow) in phases
scripts/make-filing-package.py       builds ercs-pr-package/ for the ethereum/ERCs pull request
docs/                                design memo, Magicians post draft, test record, evidence runbook
deployments/                         evidence records (none yet; the Anvil rehearsal writes 31337.json, ignored)
```

## Build and test

```
npm install
forge build
forge test
npm run check          # rebuild the examples, regenerate the vectors, validate the examples against the schemas
npm run lint:erc       # eipw lint of the ERC text (spelling findings are listed, not gating)
python3 scripts/make-filing-package.py                 # --number and --discussions-to override the placeholders
```

`forge build --sizes` reports every ADRF contract under the EIP-170 limit; the only contract above it is the vendored ERC-8436 reference registry used as a test fixture, which this repository compiles with optimizer runs 200 (its own repository compiles it with runs 1). `foundry.toml` raises the test EVM's code size limit for that fixture only.

## Evidence run

`script/SepoliaEvidence.s.sol` deploys the registries, the methods, the bridge over a live ERC-8436 registry (`ACDF_REGISTRY`; on Anvil it deploys the vendored reference), the worked-example escrow bound to a fast-track policy, and walks the two complete flows with real transactions in phases (`PHASE=deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close`). The rehearsal on Anvil ran all seven phases successfully; the Sepolia run follows the runbook in `docs/sepolia-runbook.md`.

## Objects in scope

The first draft covers five open categories of objects: AI resources (a model version, a dataset, a toolkit, a resource declaration), AI systems and services (an endpoint, a deployed version, a service agreement, a billing period), AI execution and delivery (a request, an output, a training job, a report, a tool call), AI evaluation and declarations (an evaluation report, a metric statement, a capability or safety assertion) and AI governance and intervention (a suspension, a permission change, an eligibility or organizational decision). The relation to AI names the domain; the object, the obligation, the rule and the authorized effects decide admission, and a ruling's scope is fixed by its object. The standards of the agent economy are integration examples, never prerequisites.

## Design memo and discussion

`docs/design-memo.md` carries the consolidated design: the five admission criteria, the claim direction, support kinds as a set, the dependency table, the four dimensions, the adoption rule, effects in three layers, the J-profile's exact use of ERC-8436, the nine-standard coverage map, the walkthrough of the five scenarios and the reserved extensions. `docs/magicians-post.md` is the draft of the discussion thread.

## License

CC0-1.0 (see `LICENSE.md`).
