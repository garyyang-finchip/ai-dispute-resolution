# ADRF design memo (v0.1)

Working document of the AI Dispute Resolution Framework. The ERC text (`ERCS/erc-adrf.md`) is normative; this memo records why the objects are what they are, how the framework sits next to the standards it is meant to close, and what the first draft deliberately leaves out.

## 1. Position

The standards an AI economy runs on each produce records and each carry a default for the case where nobody objects: an executable asset's package hash and manifest, a task tender's submissions and judgments, an agent's trust assertions and identity facets, a collective decision's result, a discovery registry's descriptors, a swarm's charter actions, an economic unit's valuation statements, a safety binding's suspensions. ADRF is the closing step those records were waiting for: when someone does object, how the question is confirmed, who may raise it, against which rule it is measured, by which kind of support it may be decided, what the answer may change, and when the matter is over.

The definition the framework works from: *a dispute is resolved around an identifiable digital object and its specific rights, obligations and constraints, within an explicit scope of authority, on the basis of rules and evidence fixed in advance, through a verifiable procedure, producing a disposition of limited scope.* Four things carry the weight: the object has a boundary, the judgment has a basis, the procedure can be checked, and the effect is bounded by authorization.

ADRF does not form collective decisions: ERC-8436 does, with explicit authorization, frozen policies, appeals and an adoption rule, and the J-profile consumes it through its real interface. ADRF does not grant interim measures, verify identities, discover resources, value units or enforce safety: the standards that do keep their own semantics, and ADRF reads their records as objects and routes effects to executors that live inside them.

## 2. Principle 0 and the three tests

**Principle 0.** A binding ruling must fall inside the triangle *specific object × specific obligation × pre-authorized effects*. Outside it a procedure may still run and leave a labelled, non-binding record; it moves nothing. The `Binding` / `Advisory` effect classes of ERC-8436 are reused for exactly this distinction; everything else — admission, evidence, burden, effects — ADRF defines itself.

**Reasonableness.** The ruling's power has a checkable source (the binding; a party's credit, stake or reputation may qualify it to judge, never to dispose of another's assets). The judgment refers to a rule that existed before the event, with an obligation kind that is not reinterpreted after the outcome (result, process, limit, statistical quality). Conclusions never claim more than their support: each finding records its method, inputs, premises, unverified external premises, acceptor and support kinds, and the kinds are a set with no order. Responsibility follows specific commitments and conduct — loss is not breach, breach is not unlimited liability. Effects are proportionate and layered: substantive remedies bounded by requests and authorization, procedural and economic consequences bounded by pre-accepted terms, execution bounded by each executor's own checks. Verifiability is said precisely: signature-verifiable, commitment-verifiable, procedure-reviewable, computation-replayable, proposition-decidable; an input hash alone makes nothing replayable.

**Completeness.** Four dimensions with a value in every state: procedure state, substantive result, reason, enactment status per effect. Every situation has an exit: not identifiable (refused, element named), no binding authority (advisory), sustained (which claim, which effect), not sustained (which burden rule, which reason, never the opposite finding), evidence unavailable or procedure stalled (reason and pre-committed follow-up), ruling formed but enactment failed (ruling kept, enactment recorded apart). Three hard edges: total duration, review count, the fee boundary the policy declares.

**Future compatibility.** Stable: object reference, claim, applicable rule, authorization relation, evidence record, result meaning, enactable effect. Variable through extensions: proof systems, evidence sources, evaluation models, judge selection, incentives, privacy, cross-chain carriage. Every extension declares its inputs and results, its trust assumptions, its failure returns and its integration; an unknown result profile is rejected, never coerced to a boolean; policy versions are pinned at binding and never applied retroactively.

## 3. The object of a dispute

A dispute's direct object is a **claim**: an identified object, in a given event or state, does or does not conform to an obligation of a stated kind under a stated clause of a norm declared before the event, and a stated disposition is requested. "Agent A is unreliable" cannot be filed. "Delivery S of task T does not meet the acceptance criteria pinned at tender time; refund the escrow" can.

The five admission criteria are algorithmic checks against the obligation source's attestations: **identifiable** (object and event exist and are not in the future), **accountable** (the party alleged to bear the obligation can be identified as a party or the source — not that it is liable), **norm pre-declared** (the source recognizes the norm, it was declared no later than the event, the kind matches), **decidable** (the policy binds a method for every sub-question — a method and a procedure exist, no conclusion is promised), **in window**. Then standing, authorized effects, the clock check and exclusivity.

Standing is layered: anyone may report a lead (L0); parties, and the beneficiaries or open challengers a binding admits, may start a Binding procedure (L1); remedies are bounded by authorized effects (L2); enactment belongs to the source and its executors (L3). Visibility and bonds confer nothing; the binding's terms do.

Outside the boundary: intent and motive; market prices; the merit of a rule itself (rule-making is governance; ADRF applies rules that were duly accepted); a Final collective decision or a Final ruling on the merits (only their import, authorization and procedure references can be re-verified, as formal questions over the source registry's own state). Off-chain facts are not outside it: they enter as evidence under the chosen evidence rule, and their submission alone grants no binding power.

## 4. Sub-questions, methods, support

Three question types, three method interfaces: `FORMAL` (deterministic verifier over pinned inputs; support `computed`), `EVIDENCED` (evidence rule over material supplied under that rule; support as the rule declares, `judged` excluded), `JUDGED` (judgment method; support `judged`; reference: the ERC-8436 bridge). A case holds up to sixteen sub-questions in a dependency table (a DAG with required premise values). Order follows the table, not the type: which verifier to run can depend on which definition the contract adopted, a time-limit check can depend on an external delivery fact. A sub-question whose premise resolved to a different value than required is recorded `UNDETERMINED(PREMISE_NOT_ESTABLISHED)` without running its method.

Support kinds were, in an earlier draft, ordered and a ruling took the weakest; that was wrong — a signature and a replayed computation answer different questions, a judged conclusion built on a computed premise must not read as computed, and a later judgment must not downgrade a verified premise. The kernel now records support per finding, and the round decision carries the union over the decisive finding and its premises as provenance only.

Evidence integrity (a hash fixes content) and availability (others can obtain and check it) are kept apart; the policy document states provision duties, access, verification periods and what a failure to provide means, which is never a proof of the allegation. Semantic evaluations keep their trail: the standard applied, the material seen, the supporting basis, the open uncertainties and dissents. Agreement of several models is a signal, not a proof. For probabilistic tasks the evaluation target (this delivery or a sample) is fixed before the dispute; re-running a model after the fact to pick a convenient output is excluded by design.

## 5. Decision, review, closure

The claim fixes its own direction (`supportsWhen`): `Sustained` always means the claim was supported. An undetermined decisive finding follows the burden rule of its method binding: `NOT_SUSTAINED` (the claimant did not carry the burden) or `NO_DECISION`. `NoDecision` never reads as liability; it routes to the disposition the business committed before the case (`fallbackRef`).

Reviews are bounded: one type per request, from the track's allowed set, within the window and count, targeting a set closed under dependency that reaches the decisive sub-question, always under the same policy version. Judged sub-questions are reviewed where they were judged — as ERC-8436 appeals before import; the bridge imports only Final results, so a second panel is a new, separately authorized case. The adoption rule is the policy's: `PRESERVE_UNLESS_OVERTURNED` adopts the most recent substantive round (with `adoptedFromEarlierRound` and `sourceRound` recorded), `REQUIRE_FRESH_DECISION` adopts the last round only. Closures: `REVIEW_LAPSED`, `TIMEOUT`, `NONE`; a case that never produced a substantive result and closed by the hard deadline is `Expired`, every other closure is `Final`. A timeout and an adopted decision coexist.

## 6. Bindings, clocks and exclusivity

A binding is the source's own statement: the policy version, the acceptance mode, the effects it can enact, its executors, its third parties, the downgrade rule. Clock rules are fixed by the policy's track and the binding; absolute deadlines are derived when the event is attested; admission checks that the business window (`adoptionDeadline`) holds `maxTotalDuration + enactmentMargin`, refuses otherwise, or admits as Advisory where the binding pre-allowed it; a review never resets the hard deadline.

Exclusivity holds for one active Binding case per `(source, obligationRef, proposition)` within one registry instance and one binding scope, and a Final or Expired case blocks re-filing of the same point. It is not network-wide: another registry, or a differently worded proposition about the same point, is invisible to the key, so executors check what was already disposed of before enacting. Execution state is per effect.

## 7. Effects and economics

Three layers: substantive remedies (one allowed effect, chosen at filing from the requested effects the binding authorized), procedural and economic consequences (declared by the policy, authorized by the binding, reportable whatever the result), execution (per executor, per effect: authority, amount enforceable now, target, anti-duplication). Adjudged, enforceable and enacted amounts are three numbers; the registry holds none.

The kernel holds no funds and fixes no economic model. A policy's economic declaration states, for every arrangement, the instrument and executor, the purposes (an open reference list: anti-abuse, cost bearing, performance guarantee, penalty for a proven procedural violation, third-party funding, reward pool, …), the flows under every state and result, the assumptions and the failure handling. A reward or forfeit is reported with the clause it follows and whether it is an allocation condition or a proven violation; it changes no substantive result. Coherence rewards, loser-pays and escalating bonds are adopters' choices; being in the minority is not, by this document, a violation.

Interim measures are not granted here: they come from the consumer's own safety or permission arrangements with their own authority, scope, duration and restoration; a filed case or a lead is no basis for a freeze, and a sustained challenge to a suspension restores nothing by itself.

## 8. The J-profile and ERC-8436, precisely

- The method's parameter is an ERC-8436 `policyId`; its hard cap must fit the dispute policy's decision window (checked at registration).
- `open` files one `CONSUMER_FILED` Binding issue with the bridge as consumer, the case as subject, one binary question, the fixed effect pair `TRUE` / `FALSE`, the disposition `UNDETERMINED`, `obligationId = keccak256(caseId, subQuestion)` and the decision deadline as the consumer deadline. The dispute registry verified the upstream authority before calling; the bridge does not re-verify it and does not pretend ERC-8436 has an authorization object (it has acceptance modes).
- `importResult` reads the registry, requires `Final`, maps `Decided`/yes → `TRUE`, `Decided`/no → `FALSE` (blocked under the rule, not refuted), `NoDecision` → `UNDETERMINED`, and carries `sourceRound`, `roundCount`, `adoptedFromEarlierRound` and the source reason.
- Review is the ERC-8436 appeal of the same issue under the same policy (bodies are that policy's fixed parameters; rebuilding instances is not reselecting members), open to whoever that policy's appeal standing admits — `ANYONE` lets third parties appeal at the source and ADRF cannot narrow it. The bridge's `review` reverts because it imports only Final results.
- Non-binary outcomes, panel replacement, verifiable selection and independence screening are reserved in both documents.

## 9. Coverage of the neighbouring standards

| Standard | Disputable object | Party alleged to bear the obligation | Norm | Typical question types | Boundary to keep |
|---|---|---|---|---|---|
| Token-bound executable skills | an asset version, its published content, its execution promises | publisher / holder | the skill manifest and declared interface | formal (hash, schema), judged (behaviour) | call rights, metering or refunds need their own bound business terms |
| Token-bound task tenders | a submission, its acceptance criteria, the settlement obligation, a cancellation | acceptance authority / fulfiller / creator | the tender terms (criteria hash) | formal, evidenced, judged | the submission and its window, not the token alone; the clock check must pass |
| Know-your-agent assertions | an assertion or proof, its scheme and instant | issuer | the scheme definition | formal (proved), judged (attested) | one failed assertion does not make every act untrustworthy |
| Agent identity facets | a control relation at an instant, an instance, a profile facet | issuer / controller | facet semantics and timing rules | formal (timing, anchor), judged (content) | transfers, controller changes and past obligations are separate matters |
| Collective decisions | a decision's authorization, procedure, result and adoption | submitter / consumer | the decision policy | formal only (replay) | formation of a decision and adjudication of a dispute have separate semantics; Final is not rewritten |
| Discovery registry records | a descriptor, its referenced object, its claims | registrant / attestor | the schema and value context | formal, evidenced | discoverable or registered confers no adjudication or disposal power |
| Swarm charters | a charter action, a member commitment, a role permission, an organizational duty | swarm account / member | the charter and commitment hash | evidenced, judged | membership is not liability for every loss |
| Economic unit valuations | an economic boundary, a right, an observation, a method, an input | evaluator / definition controller | the method descriptor and receipt fields | formal (recompute), judged | a valuation disagreement is not a violation; distinguish "different method" from "misreported input or breached method" |
| Safety bindings | a constraint, a binding, an intervention, its consequence | adopter / intervener | the safety specification clause | formal, evidenced, judged | intervention and final responsibility are authorized separately; a sustained challenge to a suspension restores nothing by itself |

These are coverage suggestions; none adds an implied power to the standard it names.

## 10. Five scenarios against the registry

1. **Double charge.** The contested point is the payment obligation of one call; a formal sub-question over the escrow's settlement count; the remedy is one refund and the agreed costs; whether the provider's standing elsewhere is affected needs its own basis. Tested in `ADRFFormalFlow.t.sol` and rehearsed on Anvil.
2. **Delivered, quality disputed.** The acceptance criteria and obligation kind are read from the binding; computable metrics go to a verifier, semantic quality to the accepted evaluation procedure (the J-profile). A claim whose norm cannot be identified is refused at admission (`norm`), not decided on the merits; a norm that exists but is vague is a merits question under the burden rule. Tested in `ADRFJudgedFlow.t.sol` and rehearsed on Anvil.
3. **A swarm action causes a loss.** The charter identifies who authorized what, whether the actor exceeded its mandate, which duty a member carried, whether the loss was an accepted risk; a compliant bad outcome is not a violation; a clear excess is handled within the accepted scope of responsibility. Modelled by evidenced and judged sub-questions with a dependency table (`ADRFReview.t.sol`).
4. **A tender inside its judgment window.** The binding fixed the clock rules; admission checks the remaining window against the hard cap plus the margin; too short means refusal or, where pre-allowed, Advisory — never a ruling that arrives after the tender's own default settled (`ADRFAdmission.t.sol`).
5. **An intervener's suspension is challenged by the adopter.** The suspension is a record that must conform to the specification clause; the intervener is the party alleged to bear the obligation; a sustained challenge yields a record-level finding and the pre-authorized effects; whether the suspension is lifted stays with the safety binding and its executors.

## 11. First-draft scope and reserved extensions

In the normative text: the four objects and the two auxiliary records; the two registries and their authority; the claim grammar and obligation kinds; the five criteria and the Advisory path; the eight elements; question types, method bindings and the dependency table; the finding record and the no-claim-beyond-support rule; the four-dimensional state model with time-bound exits; the track and clock rules; the five review types and the finality rules; exclusivity within a registry; effects in three layers and per-effect enactment reports; what an economic declaration must state; the J-profile v1; the verifier and evidence-rule interfaces; the result profile and the rejection of unknown profiles.

Reserved, named only: panel replacement on review; non-binary and multi-option outcomes and typed aggregation; verifiable selection and independence screening; economic modules; private evidence; cross-chain objects and rulings; mirrors into validation or reputation registries; third-party funding and other standing sources.

Described only: interoperation with the trustless-agents registries (a validation mirror is deferred: its request originates with the agent's owner or operator, its response space is a score, and `NoDecision` and `NotSustained` must not be written as a generic failure score; a normative mirror would be a dependency); the difference from oracle councils; the arbitrable/arbitrator pattern kept as the executor pattern.

## 12. Dependencies and filing notes

`requires: 165, 6372, 8436`. The J-profile is normative-optional and still a true dependency on ERC-8436, which is a Draft: a Draft may depend on a Draft, and this proposal's own status can never advance beyond that of ERC-8436. ERC-8004 and ERC-8033 are linked descriptively. Earlier arbitration-interface proposals have no file in the ERCs repository and are therefore described by pattern, not by number. The reference registry is split into a thin contract and two externally linked libraries so that it stays under the code size limit without changing any interface or identifier.
