#!/usr/bin/env node
'use strict';
// Generates the test vectors of the ERC assets (assets/erc-adrf/vectors/*.json). The Foundry suite
// (test/ADRFVectors.t.sol) reads the same files and checks every value against the Solidity side.
//
//   node tools/vectors.js          (requires `forge build` first for the interface ids)

const fs = require('fs');
const path = require('path');
const L = require('./lib/adrf');

const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'assets', 'erc-adrf', 'vectors');
const ART = path.join(ROOT, 'out');

function readArtifact(file, name) {
  const p = path.join(ART, file, `${name}.json`);
  if (!fs.existsSync(p)) throw new Error(`artifact missing: ${p} (run forge build)`);
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}
function write(name, doc) {
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, name), JSON.stringify(doc, null, 2) + '\n');
  console.log(`wrote vectors/${name}`);
}

// ----------------------------------------------------------------------------- interface ids
const ids = {};
for (const n of ['IADRFPolicyRegistry', 'IADRFDisputeRegistry', 'IADRFObligationSource', 'IADRFVerifier', 'IADRFEvidenceRule', 'IADRFJudgmentMethod']) {
  ids[n] = L.interfaceId(readArtifact(`${n}.sol`, n).abi);
}
write('interface-ids.json', {
  ...ids,
  IERC165: '0x01ffc9a7',
  note: 'XOR of the selectors of all functions declared in the interface, supportsInterface included (the value of type(I).interfaceId).',
});

// ------------------------------------------------------------------------------- identifiers
write('identifiers.json', {
  constants: L.CONSTANTS,
  enums: L.ENUMS,
  note: 'constants = keccak256(UTF-8(label)); enumerations and bit sets as in ADRFTypes.sol.',
});

// --------------------------------------------------------------------------------- policy id
const CHAIN = 11155111;
const verifier = '0x0000000000000000000000000000000000000f01';
const bridge = '0x0000000000000000000000000000000000000f02';
const rule = '0x0000000000000000000000000000000000000f03';
const escrow = '0x00000000000000000000000000000000000e5c20';
const authority = '0x0000000000000000000000000000000000000a07';
const spec = {
  family: L.id('adrf.vectors.service'),
  version: 1,
  previous: '0x' + '00'.repeat(32),
  updateAuthority: authority,
  objectKind: L.id('service-call'),
  methods: [
    { obligationKind: 3, qType: 0, method: verifier, params: '0x' + escrow.slice(2).padStart(64, '0'), onUndetermined: 0 },
    { obligationKind: 1, qType: 2, method: bridge, params: L.id('acdf.vectors.policy'), onUndetermined: 1 },
    { obligationKind: 0, qType: 1, method: rule, params: L.id('panel'), onUndetermined: 1 },
  ],
  effects: [
    { id: L.id('adrf:effect/refund'), category: 0 },
    { id: L.id('adrf:effect/fee-split'), category: 1 },
  ],
  track: {
    filingWindow: 7 * 86400, acceptanceWindow: 2 * 86400, evidenceWindow: 3 * 86400, decisionWindow: 5 * 86400,
    reviewWindow: 2 * 86400, maxReviews: 1, reviewTypes: 7, reviewMode: 0, maxTotalDuration: 12 * 86400,
    enactmentMargin: 86400, optimistic: false, answerWindow: 0, silenceRule: 0,
  },
  standing: 1,
  resultProfile: L.CONSTANTS.RESULT_PROFILE_V1,
  economicDeclaration: L.id('economic declaration'),
  descriptorHash: L.id('policy descriptor'),
};
write('policy-id.json', {
  spec,
  abiTuple: L.POLICY_SPEC_TUPLE,
  encoded: L.coder.encode([L.POLICY_SPEC_TUPLE], [spec]),
  policyId: L.policyId(spec),
  note: 'policyId = keccak256(abi.encode(PolicySpec)) over the full struct; every field is part of the identifier.',
});

// -------------------------------------------------------------------------------------- keys
const object = { chainId: CHAIN, target: escrow, id: 17, versionHash: L.id('call 17 terms v1') };
const obligationRef = L.keccak256(L.coder.encode(['uint256', 'string'], [17, 'payment']));
const proposition = L.id('claim: the call was charged twice');
const caseId = L.registryId(CHAIN, '0x00000000000000000000000000000000000ad2f0', 1);
write('keys.json', {
  chainId: CHAIN,
  object,
  objectKey: L.objectKey(object),
  source: escrow,
  obligationRef,
  proposition,
  exclusivityKey: L.exclusivityKey(escrow, obligationRef, proposition),
  registryId: { registry: '0x00000000000000000000000000000000000ad2f0', nonce: 1, id: caseId },
  bridge: {
    caseId,
    subQuestion: 0,
    obligationId: L.bridgeObligationId(caseId, 0),
    question: L.bridgeQuestion(0),
    effectTrue: L.CONSTANTS.EFFECT_TRUE,
    effectFalse: L.CONSTANTS.EFFECT_FALSE,
    disposition: L.CONSTANTS.DISPOSITION_UNDETERMINED,
  },
  note: 'objectKey = keccak256(abi.encode(ObjectRef)); exclusivityKey = keccak256(abi.encode(source, obligationRef, proposition)); registry ids = keccak256(abi.encode(chainId, registry, nonce)); the bridge obligation id = keccak256(abi.encode(caseId, subQuestion)) and question = keccak256(abi.encode(keccak256("adrf:judgment/v1"), subQuestion)).',
});
