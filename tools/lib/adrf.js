'use strict';
// Shared helpers of the ADRF tools: ERC-165 interface ids, the PolicySpec ABI tuple, identifiers and keys.

const { AbiCoder, keccak256, toUtf8Bytes, id, Interface } = require('ethers');

const coder = AbiCoder.defaultAbiCoder();

/** XOR of the selectors of every function declared in the interface, supportsInterface included, which is
 *  what Solidity's type(I).interfaceId computes for an interface that declares supportsInterface itself. */
function interfaceId(abi) {
  const iface = new Interface(abi.filter((f) => f.type === 'function'));
  let acc = 0n;
  iface.forEachFunction((fn) => {
    acc ^= BigInt(fn.selector);
  });
  return '0x' + acc.toString(16).padStart(8, '0');
}

/** ABI tuple of ADRFTypes.PolicySpec (field order is normative: policyId = keccak256(abi.encode(spec))). */
const POLICY_SPEC_TUPLE =
  'tuple(bytes32 family,uint32 version,bytes32 previous,address updateAuthority,bytes32 objectKind,' +
  'tuple(uint8 obligationKind,uint8 qType,address method,bytes32 params,uint8 onUndetermined)[] methods,' +
  'tuple(bytes32 id,uint8 category)[] effects,' +
  'tuple(uint64 filingWindow,uint64 acceptanceWindow,uint64 evidenceWindow,uint64 decisionWindow,uint64 reviewWindow,' +
  'uint32 maxReviews,uint8 reviewTypes,uint8 reviewMode,uint64 maxTotalDuration,uint64 enactmentMargin,' +
  'bool optimistic,uint64 answerWindow,uint8 silenceRule) track,' +
  'uint8 standing,bytes32 resultProfile,bytes32 economicDeclaration,bytes32 descriptorHash)';

const OBJECT_REF_TUPLE = 'tuple(uint256 chainId,address target,uint256 id,bytes32 versionHash)';

function policyId(spec) {
  return keccak256(coder.encode([POLICY_SPEC_TUPLE], [spec]));
}

function objectKey(object) {
  return keccak256(coder.encode([OBJECT_REF_TUPLE], [object]));
}

function exclusivityKey(source, obligationRef, proposition) {
  return keccak256(coder.encode(['address', 'bytes32', 'bytes32'], [source, obligationRef, proposition]));
}

function registryId(chainId, registry, nonce) {
  return keccak256(coder.encode(['uint256', 'address', 'uint256'], [chainId, registry, nonce]));
}

function bridgeObligationId(caseId, subQuestion) {
  return keccak256(coder.encode(['bytes32', 'uint32'], [caseId, subQuestion]));
}

function bridgeQuestion(subQuestion) {
  return keccak256(coder.encode(['bytes32', 'uint32'], [id('adrf:judgment/v1'), subQuestion]));
}

const CONSTANTS = {
  RESULT_PROFILE_V1: id('adrf:result/v1'),
  EFFECT_TRUE: id('adrf:finding/TRUE'),
  EFFECT_FALSE: id('adrf:finding/FALSE'),
  DISPOSITION_UNDETERMINED: id('adrf:finding/UNDETERMINED'),
  QUESTION: id('adrf:judgment/v1'),
};

const ENUMS = {
  questionType: { FORMAL: 0, EVIDENCED: 1, JUDGED: 2 },
  value: { UNDETERMINED: 0, TRUE: 1, FALSE: 2 },
  acceptanceMode: { PRE_COMMIT: 0, POST_DISPUTE: 1 },
  effectClass: { Advisory: 0, Binding: 1 },
  effectCategory: { SUBSTANTIVE: 0, PROCEDURAL_ECONOMIC: 1 },
  onUndetermined: { NOT_SUSTAINED: 0, NO_DECISION: 1 },
  standingMode: { PARTIES: 0, BENEFICIARIES: 1, OPEN: 2 },
  silenceRule: { NONE: 0, SUSTAIN: 1, NOT_SUSTAIN: 2 },
  reviewMode: { PRESERVE_UNLESS_OVERTURNED: 0, REQUIRE_FRESH_DECISION: 1 },
  procedureState: { None: 0, Filed: 1, Admitted: 2, Provisional: 3, Final: 4, NotAdmitted: 5, Withdrawn: 6, Expired: 7 },
  substantiveResult: { None: 0, Sustained: 1, NotSustained: 2, NoDecision: 3 },
  reason: {
    NONE: 0, MISSING_ELEMENT: 1, NO_BINDING_AUTHORITY: 2, CLOCK_INCOMPATIBLE: 3, DUPLICATE: 4,
    PREMISE_NOT_ESTABLISHED: 5, METHOD_UNDETERMINED: 6, BURDEN_NOT_MET: 7, TIMEOUT: 8, REVIEW_LAPSED: 9,
    ACCEPTANCE_LAPSED: 10, SILENCE: 11, PROCEDURE_FAILURE: 12,
  },
  enactmentStatus: { NotRequested: 0, Pending: 1, Enacted: 2, Failed: 3, Unknown: 4 },
  supportKinds: { signed: 1, computed: 2, evidenced: 4, judged: 8 },
  reviewTypes: { fact: 1, evidence: 2, 'rule-application': 4, conflict: 8, procedure: 16 },
};

module.exports = {
  coder, interfaceId, POLICY_SPEC_TUPLE, OBJECT_REF_TUPLE, policyId, objectKey, exclusivityKey, registryId,
  bridgeObligationId, bridgeQuestion, CONSTANTS, ENUMS, keccak256, toUtf8Bytes, id,
};
