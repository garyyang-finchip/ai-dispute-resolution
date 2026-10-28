#!/usr/bin/env node
'use strict';
// Builds the worked examples under assets/erc-adrf/examples deterministically: the service-call policy
// document, the escrow's binding document, the two case documents (duplicate charge, delivery quality),
// their findings, rulings and an enactment report, plus manifest.json with the content hashes.
//
//   node tools/build-examples.js

const fs = require('fs');
const path = require('path');
const L = require('./lib/adrf');
const C = require('./lib/canonical');

const ROOT = path.join(__dirname, '..');
const EX = path.join(ROOT, 'assets', 'erc-adrf', 'examples');
fs.mkdirSync(EX, { recursive: true });

const CHAIN = 11155111;
const verifier = '0x0000000000000000000000000000000000000f01';
const bridge = '0x0000000000000000000000000000000000000f02';
const rule = '0x0000000000000000000000000000000000000f03';
const escrow = '0x00000000000000000000000000000000000e5c20';
const registry = '0x00000000000000000000000000000000000ad2f0';
const acdf = '0x00000000000000000000000000000000000acdf0';
const authority = '0x0000000000000000000000000000000000000a07';
const client = '0x000000000000000000000000000000000000c11e';
const provider = '0x00000000000000000000000000000000000009a0';
const ZERO32 = '0x' + '00'.repeat(32);

const EFFECT_REFUND = L.id('adrf:effect/refund');
const EFFECT_FEE_SPLIT = L.id('adrf:effect/fee-split');
const STATUS_QUO = L.id('adrf:disposition/status-quo');
const EVENT_SETTLEMENT = L.id('settlement');
const EVENT_DELIVERY = L.id('delivery');
const TERMS = L.id('service terms v1');
const ACDF_POLICY = L.id('acdf.vectors.policy');
const PANEL = L.id('panel');

// ------------------------------------------------------------------------------------ policy
const spec = {
  family: L.id('adrf.vectors.service'), version: 1, previous: ZERO32, updateAuthority: authority,
  objectKind: L.id('service-call'),
  methods: [
    { obligationKind: 3, qType: 0, method: verifier, params: '0x' + escrow.slice(2).padStart(64, '0'), onUndetermined: 0 },
    { obligationKind: 1, qType: 2, method: bridge, params: ACDF_POLICY, onUndetermined: 1 },
    { obligationKind: 0, qType: 1, method: rule, params: PANEL, onUndetermined: 1 },
  ],
  effects: [{ id: EFFECT_REFUND, category: 0 }, { id: EFFECT_FEE_SPLIT, category: 1 }],
  track: {
    filingWindow: 7 * 86400, acceptanceWindow: 2 * 86400, evidenceWindow: 3 * 86400, decisionWindow: 5 * 86400,
    reviewWindow: 2 * 86400, maxReviews: 1, reviewTypes: 7, reviewMode: 0, maxTotalDuration: 12 * 86400,
    enactmentMargin: 86400, optimistic: false, answerWindow: 0, silenceRule: 0,
  },
  standing: 1, resultProfile: L.CONSTANTS.RESULT_PROFILE_V1,
  economicDeclaration: ZERO32, descriptorHash: ZERO32,
};

const economicDeclaration = {
  arrangements: [
    {
      name: 'fee split on closure',
      instrument: 'the escrow fee balance of the call',
      executor: 'ADRFServiceEscrow (the source)',
      purposes: ['cost bearing'],
      flows: {
        Sustained: 'the procedure fee is borne by the provider',
        NotSustained: 'the procedure fee is borne by the client',
        NoDecision: 'the procedure fee is split equally',
        Expired: 'the procedure fee is returned',
      },
      onFailure: 'reported Failed; no other balance is touched',
      effectId: EFFECT_FEE_SPLIT,
    },
  ],
  assumptions: [
    'bonds are not required under this policy; the escrow balances are the only funds involved',
    'receiving or bearing the fee proves no fact and is not a finding of wrongdoing',
  ],
  note: 'Illustrative; adopters declare their own arrangements.',
};
spec.economicDeclaration = C.canonicalHash(economicDeclaration);

const policyDoc = {
  kind: 'adrf-policy', adrf: '0.1',
  name: 'service-call disputes v1',
  description: 'Disputes about service calls of a service escrow: payment (limit) obligations decided by a settlement verifier, result obligations decided by an ERC-8436 roster, external facts decided by an attestor panel.',
  family: 'adrf.vectors.service', version: 1, previous: ZERO32, updateAuthority: authority,
  objectKind: 'service-call',
  obligationKinds: [
    { code: 1, label: 'result', description: 'the deliverable reaches the agreed output' },
    { code: 2, label: 'process', description: 'the agreed steps were performed' },
    { code: 3, label: 'limit', description: 'the provider acts within the agreed limits (at most one charge per call)' },
    { code: 4, label: 'statistical-quality', description: 'quality over an agreed sample' },
  ],
  methods: [
    { obligationKind: 3, qType: 'FORMAL', method: verifier, params: spec.methods[0].params, paramsMeaning: 'the settlement ledger (the escrow)', onUndetermined: 'NOT_SUSTAINED', supports: ['computed'], trustAssumptions: ['the ledger records every settlement'], onFailure: 'UNDETERMINED for a proposition the verifier was not built to decide' },
    { obligationKind: 1, qType: 'JUDGED', method: bridge, params: ACDF_POLICY, paramsMeaning: 'the ERC-8436 policy of the 2-of-3 roster', onUndetermined: 'NO_DECISION', supports: ['judged'], trustAssumptions: ['the roster is independent of the parties as declared in the judgment section'], onFailure: 'UNDETERMINED when the issue ends in NoDecision; TIMEOUT when nobody imports in time' },
    { obligationKind: 0, qType: 'EVIDENCED', method: rule, params: PANEL, paramsMeaning: 'the attestor panel (2 of 3)', onUndetermined: 'NO_DECISION', supports: ['signed', 'evidenced'], trustAssumptions: ['the panel attests honestly what it observed'], onFailure: 'UNDETERMINED below quorum' },
  ],
  effects: [
    { id: EFFECT_REFUND, label: 'refund', category: 'SUBSTANTIVE', description: 'one charge of the call (payment claims) or the call amount (delivery claims) moves from the provider balance to the client balance' },
    { id: EFFECT_FEE_SPLIT, label: 'fee-split', category: 'PROCEDURAL_ECONOMIC', description: 'the procedure fee is allocated per the economic declaration' },
  ],
  track: { ...spec.track, reviewTypes: ['fact', 'evidence', 'rule-application'], reviewMode: 'PRESERVE_UNLESS_OVERTURNED', silenceRule: 'NONE' },
  standing: 'BENEFICIARIES',
  resultProfile: 'adrf:result/v1',
  evidenceRules: [
    { appliesTo: 'EVIDENCED sub-questions', provisionDuty: 'the party relying on a fact provides the material to the panel within the evidence window', access: 'content-addressed URI readable by the panel and the counterparty', verificationPeriod: 'until the evidence window closes', closeOfEvidence: 'admittedAt + evidenceWindow', onFailureToProvide: 'the panel attests what it can; failure to provide is not proof of the allegation' },
  ],
  burden: [
    { claimKind: 'payment (limit)', whoProves: 'the claimant, by running the verifier over the pinned call', threshold: 'the verifier returns TRUE', onShortfall: 'NOT_SUSTAINED' },
    { claimKind: 'delivery (result)', whoProves: 'the roster forms a judgment', threshold: '2 of 3', onShortfall: 'NO_DECISION' },
  ],
  economicDeclaration,
  judgment: { acdfRegistry: acdf, acdfPolicyId: ACDF_POLICY, independence: 'no roster member is the client, the provider or an operator of either', selection: 'fixed roster declared in the ERC-8436 policy', appealStanding: 'ANYONE (ERC-8436 policy); third parties may appeal at the source' },
};
spec.descriptorHash = C.canonicalHash(policyDoc);
const POLICY_ID = L.policyId(spec);

// ----------------------------------------------------------------------------------- binding
const bindingDoc = {
  kind: 'adrf-binding', adrf: '0.1',
  source: escrow, sourceDescription: 'ADRFServiceEscrow: obligation source and executor for its service calls',
  policyId: POLICY_ID,
  scope: { kind: 'any-object-of-source' },
  mode: 'PRE_COMMIT',
  authorizedEffects: [
    { id: EFFECT_REFUND, label: 'refund', authorityBasis: 'the escrow holds the balances it moves' },
    { id: EFFECT_FEE_SPLIT, label: 'fee-split', authorityBasis: 'the escrow holds the fee balance' },
  ],
  executors: [{ account: escrow, role: 'source and executor' }],
  beneficiaries: [],
  openChallenge: false,
  downgradeOnClock: false,
  validUntil: 0,
  fundAuthorizations: [{ instrument: 'escrow balances', limit: 'the amount of the call', executor: escrow }],
  clockRules: {
    clock: 'mode=timestamp (the registry clock)',
    triggerEvents: [
      { eventRef: EVENT_SETTLEMENT, label: 'settlement of the call (obligation: payment, kind limit)', obligationKind: 3 },
      { eventRef: EVENT_DELIVERY, label: 'delivery of the call (obligation: delivery, kind result)', obligationKind: 1 },
    ],
    adoptionDeadlineRule: 'eventAt + the call dispute period; a case is admitted only if that deadline is at least maxTotalDuration + enactmentMargin away',
  },
  noDecisionDisposition: { ref: STATUS_QUO, description: 'balances stay where the call left them' },
};
const TERMS_HASH = C.canonicalHash(bindingDoc);

// -------------------------------------------------------------------------------------- cases
const callId = 17;
const object = { chainId: CHAIN, target: escrow, id: callId, versionHash: L.keccak256(L.coder.encode(['uint256', 'bytes32'], [callId, TERMS])) };
const PROP_DUP = L.id('claim: the call was charged twice');
const SQ_DUP = L.keccak256(L.coder.encode(['bytes32', 'address', 'uint256'], [L.id('adrf:prop/duplicate-settlement/v1'), escrow, callId]));
const dupCase = {
  kind: 'adrf-case', adrf: '0.1',
  object: { ref: object, description: 'service call 17 of the escrow, terms v1' },
  event: { eventRef: EVENT_SETTLEMENT, description: 'the second settlement of call 17', eventAt: 1770007200 },
  claim: { statement: 'Call 17 was charged twice.', proposition: PROP_DUP, decisive: 0, supportsWhen: 'TRUE' },
  rules: { normRef: TERMS, normDescription: 'service terms v1', clause: L.id('terms: at most one charge per call'), clauseText: 'at most one charge per call', obligationKind: { code: 3, label: 'limit' }, policyId: POLICY_ID },
  subjects: { claimant: client, respondent: provider, roles: [{ account: client, role: 'client' }, { account: provider, role: 'provider' }, { account: escrow, role: 'obligation source and executor' }] },
  authorization: { effectClass: 'Binding', acceptanceMode: 'PRE_COMMIT', acceptedBy: 'the escrow, for all its calls, at binding time' },
  evidence: { scope: 'the settlement records of call 17 in the escrow', provision: 'on chain; nothing to provide', access: 'public state', verifiers: 'anyone, through the bound verifier', retention: 'permanent' },
  effects: { requested: [EFFECT_REFUND], onSustained: EFFECT_REFUND, onNotSustained: null, fallbackRef: STATUS_QUO, atMost: 'one charge of call 17, from the provider balance to the client balance' },
  subQuestions: [{ index: 0, proposition: SQ_DUP, statement: 'The settlement count of call 17 in the escrow exceeds one.', qType: 'FORMAL', obligationKind: 3, inputs: 'abi.encode(uint256(17))', inputsHash: L.keccak256(L.coder.encode(['uint256'], [callId])), dependsOn: [] }],
};
dupCase.evidence.scopeHash = C.canonicalHash({ scope: dupCase.evidence.scope });

const PROP_QUALITY = L.id('claim: the delivery does not conform');
const SQ_CONFORMS = L.id('the deliverable conforms to the acceptance criteria');
const qualityCase = {
  kind: 'adrf-case', adrf: '0.1',
  object: { ref: object, description: 'service call 17 of the escrow, terms v1' },
  event: { eventRef: EVENT_DELIVERY, description: 'the delivery of call 17', eventAt: 1770003600 },
  claim: { statement: 'The delivery of call 17 does not conform to the acceptance criteria of the terms.', proposition: PROP_QUALITY, decisive: 0, supportsWhen: 'FALSE' },
  rules: { normRef: TERMS, normDescription: 'service terms v1', clause: L.id('terms: the deliverable conforms to the acceptance criteria'), clauseText: 'the deliverable conforms to the acceptance criteria', obligationKind: { code: 1, label: 'result' }, policyId: POLICY_ID },
  subjects: { claimant: client, respondent: provider, roles: [{ account: client, role: 'client' }, { account: provider, role: 'provider' }] },
  authorization: { effectClass: 'Binding', acceptanceMode: 'PRE_COMMIT', acceptedBy: 'the escrow, for all its calls, at binding time' },
  evidence: { scope: 'the deliverable and the acceptance criteria', provision: 'both parties provide material to the roster within the evidence window', access: 'content-addressed URIs', verifiers: 'the ERC-8436 roster', retention: 'until the hard deadline' },
  effects: { requested: [EFFECT_REFUND], onSustained: EFFECT_REFUND, onNotSustained: null, fallbackRef: STATUS_QUO, atMost: 'the amount of call 17' },
  subQuestions: [{ index: 0, proposition: SQ_CONFORMS, statement: 'The deliverable conforms to the acceptance criteria.', qType: 'JUDGED', obligationKind: 1, dependsOn: [] }],
};
qualityCase.evidence.scopeHash = C.canonicalHash({ scope: qualityCase.evidence.scope });

const CASE_DUP = L.registryId(CHAIN, registry, 2);
const CASE_QUALITY = L.registryId(CHAIN, registry, 3);
const ISSUE = L.registryId(CHAIN, acdf, 1);

// --------------------------------------------------------------------------------- findings
const findingDup = {
  kind: 'adrf-finding', adrf: '0.1', caseId: CASE_DUP, subQuestion: 0, round: 1,
  proposition: SQ_DUP, statement: dupCase.subQuestions[0].statement, value: 'TRUE',
  method: { address: verifier, qType: 'FORMAL', version: 'DuplicateSettlementVerifier v0.1', params: spec.methods[0].params },
  inputs: { description: 'abi.encode(uint256(17))', inputsHash: dupCase.subQuestions[0].inputsHash, resultHash: L.keccak256(L.coder.encode(['address', 'uint256', 'uint32'], [escrow, callId, 2])) },
  dependsOn: [], externalPremises: ['the ledger records every settlement of call 17'],
  acceptedBy: verifier, supportKinds: ['computed'], reason: 'NONE', at: 1770010800,
};
const findingQuality = {
  kind: 'adrf-finding', adrf: '0.1', caseId: CASE_QUALITY, subQuestion: 0, round: 1,
  proposition: SQ_CONFORMS, statement: qualityCase.subQuestions[0].statement, value: 'FALSE',
  method: { address: bridge, qType: 'JUDGED', version: 'ADRFACDFBridge v0.1', params: ACDF_POLICY },
  inputs: { description: 'the ERC-8436 issue of this sub-question', resultHash: L.id('keccak256(abi.encode(result)) of the imported ERC-8436 result') },
  dependsOn: [], externalPremises: ['the roster saw the deliverable and the criteria', 'the roster is independent as declared'],
  acceptedBy: bridge, supportKinds: ['judged'], reason: 'NONE',
  source: { registry: acdf, issueId: ISSUE, policyId: ACDF_POLICY, sourceRound: 1, roundCount: 1, adoptedFromEarlierRound: false, reason: 'NONE' },
  at: 1770100000,
};

// ---------------------------------------------------------------------------------- rulings
const rulingDup = {
  kind: 'adrf-ruling', adrf: '0.1', registry, chainId: CHAIN, caseId: CASE_DUP,
  state: 'Final', result: 'Sustained', effectClass: 'Binding', reason: 'NONE', closure: 'REVIEW_LAPSED',
  decidedAt: 1770010800, finalAt: 1770183600, roundCount: 1, sourceRound: 1, adoptedFromEarlierRound: false, bySilence: false,
  supportKinds: ['computed'], allowedEffect: EFFECT_REFUND, fallbackRef: null,
  policyId: POLICY_ID, bindingId: L.registryId(CHAIN, registry, 1), source: escrow, proposition: PROP_DUP,
  basis: 'Sub-question 0 (computed, by the settlement verifier over call 17): the settlement count exceeds one. Nothing about the quality of the service is decided.',
};
const rulingQuality = {
  kind: 'adrf-ruling', adrf: '0.1', registry, chainId: CHAIN, caseId: CASE_QUALITY,
  state: 'Final', result: 'Sustained', effectClass: 'Binding', reason: 'NONE', closure: 'REVIEW_LAPSED',
  decidedAt: 1770100000, finalAt: 1770272800, roundCount: 1, sourceRound: 1, adoptedFromEarlierRound: false, bySilence: false,
  supportKinds: ['judged'], allowedEffect: EFFECT_REFUND, fallbackRef: null,
  policyId: POLICY_ID, bindingId: L.registryId(CHAIN, registry, 1), source: escrow, proposition: PROP_QUALITY,
  judgment: findingQuality.source,
  basis: 'Sub-question 0 (judged, ERC-8436 issue of the 2-of-3 roster, round 1 of 1, not adopted from an earlier round): the proposition "the deliverable conforms" was blocked under the rule. A blocked proposition is FALSE for the sub-question; the claim named FALSE as its supporting value.',
};

// -------------------------------------------------------------------------------- enactment
const enactment = {
  kind: 'adrf-enactment', adrf: '0.1', caseId: CASE_DUP, effectId: EFFECT_REFUND, effectLabel: 'refund', category: 'SUBSTANTIVE',
  executor: escrow, status: 'Enacted', ref: L.keccak256(L.coder.encode(['uint256', 'uint256'], [callId, 10n ** 18n])),
  clause: 'binding: refund is authorized for a sustained payment claim; escrow: one charge moves back to the client',
  nature: 'substantive-remedy',
  amounts: { adjudged: '1 charge of call 17 (1 ETH)', enforceable: '1 ETH (provider balance sufficient)', enacted: '1 ETH' },
  changesSubstantiveResult: false, at: 1770190000,
};

// ------------------------------------------------------------------------------------ write
const files = {
  'policy-service-call.json': policyDoc,
  'binding-service-escrow.json': bindingDoc,
  'case-duplicate-charge.json': dupCase,
  'case-delivery-quality.json': qualityCase,
  'finding-duplicate-charge.json': findingDup,
  'finding-delivery-quality.json': findingQuality,
  'ruling-duplicate-charge.json': rulingDup,
  'ruling-delivery-quality.json': rulingQuality,
  'enactment-refund.json': enactment,
};
const manifest = { adrf: '0.1', note: 'contentHash = keccak256(UTF-8(JCS(document))). The policy spec hashes the policy document as descriptorHash and the economic declaration as economicDeclaration; the binding hashes its document as termsHash; a case hashes its document as documentHash.', policyId: POLICY_ID, policySpec: spec, termsHash: TERMS_HASH, files: {} };
for (const [name, doc] of Object.entries(files)) {
  fs.writeFileSync(path.join(EX, name), JSON.stringify(doc, null, 2) + '\n');
  manifest.files[name] = { kind: doc.kind, contentHash: C.canonicalHash(doc) };
  console.log(`wrote examples/${name}`);
}
manifest.caseDocumentHashes = { 'case-duplicate-charge.json': manifest.files['case-duplicate-charge.json'].contentHash, 'case-delivery-quality.json': manifest.files['case-delivery-quality.json'].contentHash };
fs.writeFileSync(path.join(EX, 'manifest.json'), JSON.stringify(manifest, (k, v) => (typeof v === 'bigint' ? v.toString() : v), 2) + '\n');
console.log('wrote examples/manifest.json');
