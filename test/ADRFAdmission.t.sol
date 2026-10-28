// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";
import {ADRFServiceEscrow} from "adrf/examples/ADRFServiceEscrow.sol";
import {MockSource, NotASource} from "./mocks/MockSource.sol";

/// Admission: the five criteria, standing, authorized effects, clock compatibility, exclusivity, the two
/// acceptance modes, Advisory cases, and the shape rules of a claim.
contract ADRFAdmissionTest is ADRFBase {
    MockSource mock;
    bytes32 mockBinding;
    address respondent = address(0xDEAD);
    address claimant = address(0xC1A1);

    function setUp() public override {
        super.setUp();
        mock = new MockSource(reg);
        T.EventInfo memory i;
        i.known = true;
        i.eventAt = uint64(block.timestamp) - 1 hours;
        i.adoptionDeadline = 0;
        i.obligationRef = keccak256("obligation");
        i.normRef = TERMS;
        i.normDeclaredAt = i.eventAt - 1 days;
        i.obligationKind = KIND_LIMIT;
        mock.setInfo(i);
        mock.setParty(respondent, true);
        mock.setParty(claimant, true);
        T.BindingInput memory b = bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = beneficiary;
        mockBinding = mock.bind(b);
    }

    function mockClaim() internal view returns (T.ClaimInput memory c) {
        c = duplicateClaim();
        c.object = T.ObjectRef({chainId: block.chainid, target: address(mock), id: 1, versionHash: keccak256("v1")});
        c.respondent = respondent;
    }

    function fileMock(address who, T.ClaimInput memory c) internal returns (bytes32 id) {
        vm.prank(who);
        id = reg.file(mockBinding, c);
    }

    function expectFileRevert(address who, T.ClaimInput memory c, bytes memory err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        reg.file(mockBinding, c);
    }

    // ------------------------------------------------------------------ five criteria

    function test_criteria_identifiableEvent() public {
        T.EventInfo memory i = infoOf();
        i.known = false;
        mock.setInfo(i);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_NotIdentifiable.selector, "event"));
        i.known = true;
        i.eventAt = uint64(block.timestamp) + 1; // in the future
        mock.setInfo(i);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_NotIdentifiable.selector, "event"));
    }

    function test_criteria_normMustBeRecognisedAndPreDeclared() public {
        T.EventInfo memory i = infoOf();
        i.normRef = keccak256("other terms");
        mock.setInfo(i);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "norm not recognised by source"));
        i.normRef = TERMS;
        i.normDeclaredAt = i.eventAt + 1;
        mock.setInfo(i);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "norm declared after event"));
        i.normDeclaredAt = 0;
        mock.setInfo(i);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_MissingElement.selector, "norm"));
        i.normDeclaredAt = i.eventAt - 1;
        i.obligationKind = KIND_RESULT; // the source attests a different obligation kind than the claim names
        mock.setInfo(i);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "obligation kind"));
        i.obligationRef = bytes32(0);
        i.obligationKind = KIND_LIMIT;
        mock.setInfo(i);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_MissingElement.selector, "obligation"));
    }

    function test_criteria_accountableRespondent() public {
        T.ClaimInput memory c = mockClaim();
        c.respondent = rando; // not a party
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_NotAccountable.selector, rando));
        c.respondent = claimant; // a party cannot name itself
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_NotAccountable.selector, claimant));
        c.respondent = address(mock); // the source itself is always accountable
        bytes32 id = fileMock(claimant, c);
        assertState(id, T.ProcedureState.Admitted);
    }

    function test_criteria_decidable() public {
        T.ClaimInput memory c = mockClaim();
        c.subQuestions[0].qType = T.QuestionType.JUDGED;
        c.subQuestions[0].obligationKind = KIND_LIMIT; // the policy binds JUDGED only for KIND_RESULT
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_NotDecidable.selector, uint32(0)));
    }

    function test_criteria_filingWindow() public {
        vm.warp(block.timestamp + 7 * DAY); // eventAt was 1 hour before START; window is 7 days
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_OutsideWindow.selector, "filing"));
    }

    // ------------------------------------------------------------------ standing and effects

    function test_standing_partiesAndBeneficiaries() public {
        expectFileRevert(rando, mockClaim(), abi.encodeWithSelector(E.ADRF_NoStanding.selector, rando));
        bytes32 id = fileMock(beneficiary, mockClaim());
        assertEq(reg.getCase(id).claimant, beneficiary);
    }

    function test_standing_openChallengeRequiresPolicyStanding() public {
        T.BindingInput memory b = bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT);
        b.openChallenge = true; // the policy's standing is BENEFICIARIES, not OPEN
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InvalidBinding.selector, "open challenge not allowed by policy"));
        mock.bind(b);
    }

    function test_standing_openChallengeWhenPolicyAllows() public {
        T.PolicySpec memory s = servicePolicy(keccak256("adrf.test.open"), 1, bytes32(0), false);
        s.standing = T.StandingMode.OPEN;
        bytes32 openPolicy = pol.registerPolicy(s);
        T.BindingInput memory b = bindingInput(openPolicy, T.AcceptanceMode.PRE_COMMIT);
        b.openChallenge = true;
        MockSource m2 = new MockSource(reg);
        m2.setInfo(infoOf());
        m2.setParty(respondent, true);
        bytes32 b2 = m2.bind(b);
        T.ClaimInput memory c = mockClaim();
        c.object.target = address(m2);
        vm.prank(rando);
        bytes32 id = reg.file(b2, c);
        assertEq(reg.getCase(id).claimant, rando);
    }

    function test_effects_mustBeAuthorizedAndSubstantive() public {
        T.ClaimInput memory c = mockClaim();
        c.requestedEffects[0] = keccak256("adrf:effect/unknown");
        c.effectOnSustained = c.requestedEffects[0];
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_EffectNotAuthorized.selector, c.requestedEffects[0]));
        c.requestedEffects[0] = EFFECT_FEE_SPLIT; // authorized, but procedural/economic
        c.effectOnSustained = EFFECT_FEE_SPLIT;
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_EffectNotAuthorized.selector, EFFECT_FEE_SPLIT));
    }

    function test_binding_requiresSourceInterfaceAndDeclaredEffects() public {
        NotASource n = new NotASource();
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InvalidBinding.selector, "source interface"));
        n.bind(reg, bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT));
        T.BindingInput memory b = bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT);
        b.authorizedEffects[0] = keccak256("adrf:effect/unknown");
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InvalidBinding.selector, "effect not declared by policy"));
        mock.bind(b);
        b = bindingInput(keccak256("no such policy"), T.AcceptanceMode.PRE_COMMIT);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_UnknownPolicy.selector, keccak256("no such policy")));
        mock.bind(b);
    }

    function test_binding_revokedOrExpiredStopsNewFilings() public {
        mock.revoke();
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_BindingInactive.selector, mockBinding));
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotSource.selector, mockBinding));
        reg.revokeBinding(mockBinding);
    }

    function test_binding_scopeKeyRestrictsTheObject() public {
        T.BindingInput memory b = bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT);
        T.ClaimInput memory c = mockClaim();
        b.scopeKey = reg.objectKeyOf(c.object);
        MockSource m2 = new MockSource(reg);
        m2.setInfo(infoOf());
        m2.setParty(respondent, true);
        m2.setParty(claimant, true);
        bytes32 b2 = m2.bind(b);
        c.object.target = address(m2);
        vm.prank(claimant);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NoStanding.selector, claimant));
        reg.file(b2, c); // object key differs from the scope (target changed)
    }

    // ------------------------------------------------------------------ clock and exclusivity

    function test_clock_incompatibleWindowIsRefused() public {
        T.EventInfo memory i = infoOf();
        i.adoptionDeadline = uint64(block.timestamp) + 5 * DAY; // needs 12 days + 1 day margin
        mock.setInfo(i);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_ClockIncompatible.selector, i.adoptionDeadline, uint64(block.timestamp) + 13 * DAY));
    }

    function test_clock_downgradeToAdvisoryWhenPreAllowed() public {
        T.BindingInput memory b = bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT);
        b.downgradeOnClock = true;
        MockSource m2 = new MockSource(reg);
        T.EventInfo memory i = infoOf();
        i.adoptionDeadline = uint64(block.timestamp) + 5 * DAY;
        m2.setInfo(i);
        m2.setParty(respondent, true);
        m2.setParty(claimant, true);
        bytes32 b2 = m2.bind(b);
        T.ClaimInput memory c = mockClaim();
        c.object.target = address(m2);
        vm.prank(claimant);
        bytes32 id = reg.file(b2, c);
        T.CaseHeader memory h = reg.getCase(id);
        assertEq(uint8(h.effectClass), uint8(T.EffectClass.Advisory));
        assertEq(h.exclusivityKey, bytes32(0), "an advisory case takes no exclusivity slot");
        assertState(id, T.ProcedureState.Admitted);
    }

    function test_exclusivity_oneActiveBindingCasePerContestedPoint() public {
        bytes32 first = fileMock(claimant, mockClaim());
        bytes32 key = reg.getCase(first).exclusivityKey;
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_Duplicate.selector, key, first));
        // a different contested point on the same obligation is a different key
        T.ClaimInput memory other = mockClaim();
        other.proposition = keccak256("claim: a different point");
        bytes32 second = fileMock(claimant, other);
        assertTrue(reg.getCase(second).exclusivityKey != key);
        // after finality the same point cannot be re-filed as Binding
        reg.resolveFormal(first, 0, abi.encode(callId));
        reg.decide(first);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(first);
        expectFileRevert(claimant, mockClaim(), abi.encodeWithSelector(E.ADRF_Duplicate.selector, key, first));
    }

    // ------------------------------------------------------------------ POST_DISPUTE

    function postDisputeSource() internal returns (MockSource m2, bytes32 b2) {
        m2 = new MockSource(reg);
        m2.setInfo(infoOf());
        m2.setParty(respondent, true);
        m2.setParty(claimant, true);
        b2 = m2.bind(bindingInput(policyId, T.AcceptanceMode.POST_DISPUTE));
    }

    function test_postDispute_acceptanceAdmits() public {
        (MockSource m2, bytes32 b2) = postDisputeSource();
        T.ClaimInput memory c = mockClaim();
        c.object.target = address(m2);
        vm.prank(claimant);
        bytes32 id = reg.file(b2, c);
        assertState(id, T.ProcedureState.Filed);
        assertEq(reg.getClock(id).admittedAt, 0);
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotRespondent.selector, rando));
        reg.accept(id);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "acceptance"));
        reg.expireAcceptance(id);
        vm.prank(respondent);
        reg.accept(id);
        assertState(id, T.ProcedureState.Admitted);
        assertEq(reg.getClock(id).roundCount, 1);
    }

    function test_postDispute_withdrawAndLapse() public {
        (MockSource m2, bytes32 b2) = postDisputeSource();
        T.ClaimInput memory c = mockClaim();
        c.object.target = address(m2);
        vm.prank(claimant);
        bytes32 id = reg.file(b2, c);
        bytes32 key = reg.getCase(id).exclusivityKey;
        assertEq(reg.activeCaseOf(key), id);
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotClaimant.selector, rando));
        reg.withdraw(id);
        vm.prank(claimant);
        reg.withdraw(id);
        assertState(id, T.ProcedureState.Withdrawn);
        assertEq(reg.activeCaseOf(key), bytes32(0), "withdrawal releases the slot");
        // re-file, then let the acceptance window lapse
        vm.prank(claimant);
        bytes32 id2 = reg.file(b2, c);
        vm.warp(block.timestamp + 2 * DAY + 1);
        vm.prank(respondent);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowClosed.selector, "acceptance"));
        reg.accept(id2);
        reg.expireAcceptance(id2);
        assertState(id2, T.ProcedureState.NotAdmitted);
        assertEq(reg.activeCaseOf(key), bytes32(0));
        // nothing can be done with a case that was not admitted
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WrongState.selector, id2, uint8(T.ProcedureState.NotAdmitted)));
        reg.resolveFormal(id2, 0, abi.encode(callId));
        // the ruling view reports the procedure state and no result
        T.Ruling memory u = reg.getRuling(id2);
        assertEq(uint8(u.state), uint8(T.ProcedureState.NotAdmitted));
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.None));
    }

    function test_postDispute_bindingNeedsAnAcceptanceWindow() public {
        T.PolicySpec memory s = servicePolicy(keccak256("adrf.test.noaccept"), 1, bytes32(0), false);
        s.track.acceptanceWindow = 0;
        bytes32 pid = pol.registerPolicy(s);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InvalidBinding.selector, "policy has no acceptance window"));
        mock.bind(bindingInput(pid, T.AcceptanceMode.POST_DISPUTE));
    }

    // ------------------------------------------------------------------ Advisory

    function test_advisory_fullProcedureNoDisposal() public {
        T.ClaimInput memory c = duplicateClaim();
        vm.prank(rando); // no standing needed, no binding needed
        bytes32 id = reg.fileAdvisory(policyId, c, uint64(block.timestamp) - 1 hours, uint64(block.timestamp) - 2 days);
        T.CaseHeader memory h = reg.getCase(id);
        assertEq(uint8(h.effectClass), uint8(T.EffectClass.Advisory));
        assertEq(h.source, address(0));
        assertEq(h.bindingId, bytes32(0));
        assertEq(h.exclusivityKey, bytes32(0));
        reg.resolveFormal(id, 0, abi.encode(callId));
        reg.decide(id);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(id);
        T.Ruling memory u = reg.getRuling(id);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertEq(uint8(u.effectClass), uint8(T.EffectClass.Advisory));
        assertEq(u.allowedEffect, bytes32(0), "an advisory ruling authorizes nothing");
        vm.prank(address(escrow));
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_AdvisoryNoEffect.selector, id));
        reg.reportEnactment(id, REFUND, T.EnactmentStatus.Enacted, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(ADRFServiceEscrowErrors.Escrow_NotEnactable.selector, id));
        escrow.enact(id, REFUND);
        // the Binding slot for the same point is still free
        bytes32 binding = fileAs(client, duplicateClaim());
        assertEq(uint8(reg.getCase(binding).effectClass), uint8(T.EffectClass.Binding));
    }

    function test_advisory_stillNeedsIdentifiableElements() public {
        T.ClaimInput memory c = duplicateClaim();
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotIdentifiable.selector, "event"));
        reg.fileAdvisory(policyId, c, uint64(block.timestamp) + 1, uint64(block.timestamp) - 2 days);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "norm declared after event"));
        reg.fileAdvisory(policyId, c, uint64(block.timestamp) - 1 hours, uint64(block.timestamp));
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_MissingElement.selector, "norm"));
        reg.fileAdvisory(policyId, c, uint64(block.timestamp) - 1 hours, 0);
        vm.warp(block.timestamp + 8 * DAY);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_OutsideWindow.selector, "filing"));
        reg.fileAdvisory(policyId, c, uint64(START), uint64(START) - 1);
    }

    // ------------------------------------------------------------------ shape

    function test_shape_rules() public {
        T.ClaimInput memory c = mockClaim();
        c.decisive = 1;
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_BadSubQuestions.selector, "decisive"));
        c = mockClaim();
        c.supportsWhen = T.Value.UNDETERMINED;
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_BadSubQuestions.selector, "supportsWhen"));
        c = mockClaim();
        c.effectOnSustained = EFFECT_FEE_SPLIT; // not among the requested effects
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_BadSubQuestions.selector, "effectOnSustained"));
        c = mockClaim();
        c.documentHash = bytes32(0);
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_MissingElement.selector, "document"));
        c = mockClaim();
        c.proposition = bytes32(0);
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_MissingElement.selector, "claim"));
        c = mockClaim();
        c.subQuestions = new T.SubQuestionInput[](0);
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_BadSubQuestions.selector, "count"));
        // self-dependency and cycles
        c = mockClaim();
        c.subQuestions = new T.SubQuestionInput[](2);
        c.subQuestions[0] = sub(keccak256("a"), T.QuestionType.FORMAL, KIND_LIMIT, keccak256("x"));
        c.subQuestions[1] = sub(keccak256("b"), T.QuestionType.FORMAL, KIND_LIMIT, keccak256("y"));
        c.subQuestions[0].dependsOn = new uint32[](1);
        c.subQuestions[0].dependsOn[0] = 1;
        c.subQuestions[0].requiredValues = new T.Value[](1);
        c.subQuestions[0].requiredValues[0] = T.Value.TRUE;
        c.subQuestions[1].dependsOn = new uint32[](1);
        c.subQuestions[1].dependsOn[0] = 0;
        c.subQuestions[1].requiredValues = new T.Value[](1);
        c.subQuestions[1].requiredValues[0] = T.Value.TRUE;
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_BadSubQuestions.selector, "cycle"));
        c.subQuestions[1].dependsOn[0] = 1;
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_BadSubQuestions.selector, "premise index"));
        c.subQuestions[1].dependsOn[0] = 0;
        c.subQuestions[1].requiredValues[0] = T.Value.UNDETERMINED;
        expectFileRevert(claimant, c, abi.encodeWithSelector(E.ADRF_BadSubQuestions.selector, "premise value"));
    }

    function infoOf() internal view returns (T.EventInfo memory i) {
        (i.known, i.eventAt, i.adoptionDeadline, i.obligationRef, i.normRef, i.normDeclaredAt, i.obligationKind) = mock.info();
    }
}

interface ADRFServiceEscrowErrors {
    error Escrow_NotEnactable(bytes32 caseId);
}
