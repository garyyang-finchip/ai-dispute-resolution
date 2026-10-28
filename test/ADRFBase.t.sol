// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ADRFTypes as T} from "adrf/ADRFTypes.sol";
import {ADRFErrors as E} from "adrf/ADRFErrors.sol";
import {ADRFPolicyRegistry} from "adrf/ADRFPolicyRegistry.sol";
import {ADRFDisputeRegistry} from "adrf/ADRFDisputeRegistry.sol";
import {IADRFPolicyRegistry} from "adrf/interfaces/IADRFPolicyRegistry.sol";
import {IADRFDisputeRegistry} from "adrf/interfaces/IADRFDisputeRegistry.sol";
import {ADRFACDFBridge} from "adrf/bridges/ADRFACDFBridge.sol";
import {DuplicateSettlementVerifier} from "adrf/examples/DuplicateSettlementVerifier.sol";
import {AttestorQuorumRule} from "adrf/examples/AttestorQuorumRule.sol";
import {ADRFServiceEscrow} from "adrf/examples/ADRFServiceEscrow.sol";
import {IACDFRegistry as IACDFRegistryBridge} from "adrf/interfaces/acdf/IACDFRegistry.sol";

import {ACDFTypes as A} from "acdf/ACDFTypes.sol";
import {ACDFPolicyRegistry} from "acdf/ACDFPolicyRegistry.sol";
import {ACDFRegistry} from "acdf/ACDFRegistry.sol";

/// Shared fixture: the two ADRF registries, an ERC-8436 deployment (vendored reference) with a 2-of-3 roster
/// policy, the bridge, the formal verifier, the attestor-quorum rule, the worked-example escrow bound to a
/// policy that serves all three question types, and one service call that was charged twice.
abstract contract ADRFBase is Test {
    uint256 internal constant START = 1_770_000_000;

    ADRFPolicyRegistry pol;
    ADRFDisputeRegistry reg;
    ACDFPolicyRegistry acdfPol;
    ACDFRegistry acdf;
    ADRFACDFBridge bridge;
    DuplicateSettlementVerifier verifier;
    AttestorQuorumRule rule;
    ADRFServiceEscrow escrow;

    address authority = address(0xA07);
    address client = address(0xC11E);
    address provider = address(0x9A0);
    address rando = address(0xBAD);
    address beneficiary = address(0xBE2E);
    address[] jurors;
    address[] attestors;

    bytes32 acdfPolicyId;
    bytes32 panelId;
    bytes32 policyId;
    bytes32 bindingId;
    uint256 callId;
    bytes32 TERMS = keccak256("service terms v1");

    bytes32 constant FAMILY = keccak256("adrf.test.service");
    bytes32 constant CLAUSE_ONE_CHARGE = keccak256("terms: at most one charge per call");
    bytes32 constant CLAUSE_CONFORMS = keccak256("terms: the deliverable conforms to the acceptance criteria");
    bytes32 constant DOC = keccak256("case document");
    bytes32 constant PROP_DUPLICATE_CLAIM = keccak256("claim: the call was charged twice");
    bytes32 constant PROP_QUALITY_CLAIM = keccak256("claim: the delivery does not conform");
    bytes32 constant PROP_CONFORMS = keccak256("the deliverable conforms to the acceptance criteria");
    bytes32 constant PROP_PERFORMED = keccak256("the service was actually performed");
    bytes32 constant EFFECT_FEE_SPLIT = keccak256("adrf:effect/fee-split");
    bytes32 REFUND;            // REFUND, cached so that expectRevert/prank target the intended call
    bytes32 STATUS_QUO;        // STATUS_QUO
    bytes32 EVENT_SETTLEMENT;
    bytes32 EVENT_DELIVERY;
    uint8 KIND_RESULT;
    uint8 KIND_LIMIT;

    uint64 constant DAY = 1 days;

    function setUp() public virtual {
        vm.warp(START);
        pol = new ADRFPolicyRegistry();
        reg = new ADRFDisputeRegistry(pol);
        acdfPol = new ACDFPolicyRegistry();
        acdf = new ACDFRegistry(acdfPol);
        bridge = new ADRFACDFBridge(reg, IACDFRegistryBridge(address(acdf)));
        verifier = new DuplicateSettlementVerifier();
        rule = new AttestorQuorumRule();
        escrow = new ADRFServiceEscrow(reg);
        REFUND = escrow.EFFECT_REFUND();
        STATUS_QUO = escrow.DISPOSITION_STATUS_QUO();
        EVENT_SETTLEMENT = escrow.EVENT_SETTLEMENT();
        EVENT_DELIVERY = escrow.EVENT_DELIVERY();
        KIND_RESULT = escrow.KIND_RESULT();
        KIND_LIMIT = escrow.KIND_LIMIT();

        for (uint256 i = 0; i < 3; i++) jurors.push(vm.addr(uint256(keccak256(abi.encode("juror", i)))));
        for (uint256 i = 0; i < 3; i++) attestors.push(vm.addr(uint256(keccak256(abi.encode("attestor", i)))));

        acdfPolicyId = registerAcdfPolicy(1, 3); // one appeal, PRESERVE_UNLESS_OVERTURNED, both outcome types appealable
        panelId = rule.registerPanel(attestors, 2);
        policyId = pol.registerPolicy(servicePolicy(FAMILY, 1, bytes32(0), false));
        bindingId = escrow.bindTo(bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT));

        vm.deal(client, 10 ether);
        vm.prank(client);
        escrow.deposit{value: 4 ether}();
        vm.prank(client);
        callId = escrow.openCall(provider, 1 ether, TERMS, 30 * DAY);
        vm.warp(START + 1 hours);
        vm.prank(provider);
        escrow.deliver(callId);
        vm.prank(provider);
        escrow.settle(callId);
        vm.warp(START + 2 hours);
        vm.prank(provider);
        escrow.settle(callId); // the double charge
    }

    // ------------------------------------------------------------------ ERC-8436 fixture

    function registerAcdfPolicy(uint32 maxAppeals, uint8 appealable) internal returns (bytes32 id) {
        A.BodySpec[] memory bodies = new A.BodySpec[](1);
        bodies[0].kind = A.BodyKind.ROSTER_KOFN;
        bodies[0].acceptance = A.Acceptance.ON_CHAIN_TALLY;
        bodies[0].members = jurors;
        bodies[0].k = 2;
        bodies[0].window = DAY;
        A.Node[] memory nodes = new A.Node[](1);
        nodes[0].op = A.Combinator.BODY;
        nodes[0].body = 0;
        nodes[0].children = new uint32[](0);
        A.PolicySpec memory s;
        s.family = keccak256(abi.encode("acdf.test", maxAppeals, appealable));
        s.version = 1;
        s.updateAuthority = authority;
        s.bodies = bodies;
        s.nodes = nodes;
        s.maxAppeals = maxAppeals;
        s.appealWindow = maxAppeals > 0 ? DAY : 0;
        s.appealable = maxAppeals > 0 ? appealable : 0;
        s.appealStanding = A.AppealStanding.ANYONE;
        s.appealMode = A.AppealMode.PRESERVE_UNLESS_OVERTURNED;
        s.maxTotalDuration = 3 * DAY;
        s.descriptorHash = keccak256("acdf descriptor");
        vm.prank(authority);
        id = acdfPol.registerPolicy(s);
    }

    // ------------------------------------------------------------------ ADRF policy and binding builders

    function track(bool optimistic) internal pure returns (T.Track memory t) {
        t.filingWindow = 7 * DAY;
        t.acceptanceWindow = 2 * DAY;
        t.evidenceWindow = 3 * DAY;
        t.decisionWindow = 5 * DAY;
        t.reviewWindow = 2 * DAY;
        t.maxReviews = 1;
        t.reviewTypes = T.REVIEW_FACT | T.REVIEW_EVIDENCE | T.REVIEW_RULE_APPLICATION;
        t.reviewMode = T.ReviewMode.PRESERVE_UNLESS_OVERTURNED;
        t.maxTotalDuration = 12 * DAY;
        t.enactmentMargin = DAY;
        if (optimistic) {
            t.optimistic = true;
            t.answerWindow = DAY;
            t.silenceRule = T.SilenceRule.SUSTAIN;
        }
    }

    function servicePolicy(bytes32 family, uint32 version, bytes32 previous, bool optimistic)
        internal view returns (T.PolicySpec memory s)
    {
        s.family = family;
        s.version = version;
        s.previous = previous;
        s.updateAuthority = authority;
        s.objectKind = keccak256("service-call");
        s.methods = new T.MethodBinding[](3);
        s.methods[0] = T.MethodBinding({
            obligationKind: KIND_LIMIT, qType: T.QuestionType.FORMAL, method: address(verifier),
            params: bytes32(uint256(uint160(address(escrow)))), onUndetermined: T.OnUndetermined.NOT_SUSTAINED
        });
        s.methods[1] = T.MethodBinding({
            obligationKind: KIND_RESULT, qType: T.QuestionType.JUDGED, method: address(bridge),
            params: acdfPolicyId, onUndetermined: T.OnUndetermined.NO_DECISION
        });
        s.methods[2] = T.MethodBinding({
            obligationKind: 0, qType: T.QuestionType.EVIDENCED, method: address(rule),
            params: panelId, onUndetermined: T.OnUndetermined.NO_DECISION
        });
        s.effects = new T.Effect[](2);
        s.effects[0] = T.Effect({id: REFUND, category: T.EffectCategory.SUBSTANTIVE});
        s.effects[1] = T.Effect({id: EFFECT_FEE_SPLIT, category: T.EffectCategory.PROCEDURAL_ECONOMIC});
        s.track = track(optimistic);
        s.standing = T.StandingMode.BENEFICIARIES;
        s.resultProfile = T.RESULT_PROFILE_V1;
        s.economicDeclaration = keccak256("economic declaration");
        s.descriptorHash = keccak256("policy descriptor");
    }

    function bindingInput(bytes32 pid, T.AcceptanceMode mode) internal view returns (T.BindingInput memory b) {
        b.policyId = pid;
        b.scopeKey = bytes32(0);
        b.mode = mode;
        b.authorizedEffects = new bytes32[](2);
        b.authorizedEffects[0] = REFUND;
        b.authorizedEffects[1] = EFFECT_FEE_SPLIT;
        b.executors = new address[](0);
        b.beneficiaries = new address[](0);
        b.openChallenge = false;
        b.downgradeOnClock = false;
        b.validUntil = 0;
        b.termsHash = keccak256("binding terms");
    }

    // ------------------------------------------------------------------ claim builders

    function sub(bytes32 proposition, T.QuestionType qType, uint8 kind, bytes32 inputsHash)
        internal pure returns (T.SubQuestionInput memory q)
    {
        q.proposition = proposition;
        q.qType = qType;
        q.obligationKind = kind;
        q.inputsHash = inputsHash;
        q.dependsOn = new uint32[](0);
        q.requiredValues = new T.Value[](0);
    }

    function baseClaim(bytes32 eventRef, bytes32 proposition, bytes32 clause, uint8 kind, T.Value supportsWhen)
        internal view returns (T.ClaimInput memory c)
    {
        c.object = escrow.objectOf(callId);
        c.eventRef = eventRef;
        c.proposition = proposition;
        c.normRef = TERMS;
        c.clause = clause;
        c.obligationKind = kind;
        c.respondent = provider;
        c.requestedEffects = new bytes32[](1);
        c.requestedEffects[0] = REFUND;
        c.effectOnSustained = REFUND;
        c.effectOnNotSustained = bytes32(0);
        c.fallbackRef = STATUS_QUO;
        c.evidenceScopeHash = keccak256("evidence scope");
        c.documentHash = DOC;
        c.decisive = 0;
        c.supportsWhen = supportsWhen;
    }

    /// Claim: the call was charged twice (formal, LIMIT obligation).
    function duplicateClaim() internal view returns (T.ClaimInput memory c) {
        c = baseClaim(EVENT_SETTLEMENT, PROP_DUPLICATE_CLAIM, CLAUSE_ONE_CHARGE, KIND_LIMIT, T.Value.TRUE);
        c.subQuestions = new T.SubQuestionInput[](1);
        c.subQuestions[0] = sub(verifier.propositionFor(address(escrow), callId), T.QuestionType.FORMAL, KIND_LIMIT, keccak256(abi.encode(callId)));
    }

    /// Claim: the delivery does not conform (judged, RESULT obligation); sustained when conformity is FALSE.
    function qualityClaim() internal view returns (T.ClaimInput memory c) {
        c = baseClaim(EVENT_DELIVERY, PROP_QUALITY_CLAIM, CLAUSE_CONFORMS, KIND_RESULT, T.Value.FALSE);
        c.subQuestions = new T.SubQuestionInput[](1);
        c.subQuestions[0] = sub(PROP_CONFORMS, T.QuestionType.JUDGED, KIND_RESULT, bytes32(0));
    }

    /// Claim: the service was not performed (evidenced, RESULT obligation); sustained when "performed" is FALSE.
    function performanceClaim() internal view returns (T.ClaimInput memory c) {
        c = baseClaim(EVENT_DELIVERY, keccak256("claim: the service was not performed"), CLAUSE_CONFORMS, KIND_RESULT, T.Value.FALSE);
        c.subQuestions = new T.SubQuestionInput[](1);
        c.subQuestions[0] = sub(PROP_PERFORMED, T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
    }

    function fileAs(address who, T.ClaimInput memory c) internal returns (bytes32 id) {
        vm.prank(who);
        id = reg.file(bindingId, c);
    }

    // ------------------------------------------------------------------ ERC-8436 helpers

    function voteBlock(bytes32 issueId, uint32 round, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            vm.prank(jurors[i]);
            acdf.castBallot(issueId, round, 0, false);
        }
    }

    function voteApprove(bytes32 issueId, uint32 round, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            vm.prank(jurors[i]);
            acdf.castBallot(issueId, round, 0, true);
        }
    }

    function issueOf(bytes32 caseId, uint32 sq) internal view returns (bytes32) {
        return bridge.issueOf(keccak256(abi.encode(caseId, sq)));
    }

    // ------------------------------------------------------------------ assertions

    function assertState(bytes32 caseId, T.ProcedureState want) internal view {
        assertEq(uint8(reg.getCase(caseId).state), uint8(want), "procedure state");
    }

    function assertResult(bytes32 caseId, T.SubstantiveResult want) internal view {
        assertEq(uint8(reg.getRuling(caseId).result), uint8(want), "substantive result");
    }

    function assertReason(T.Reason got, T.Reason want) internal pure {
        assertEq(uint8(got), uint8(want), "reason");
    }

    function assertValue(T.Value got, T.Value want) internal pure {
        assertEq(uint8(got), uint8(want), "value");
    }
}
