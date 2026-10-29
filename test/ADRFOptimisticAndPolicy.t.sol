// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";
import {ADRFServiceEscrow} from "adrf/examples/ADRFServiceEscrow.sol";
import {IADRFPolicyRegistry} from "adrf/interfaces/IADRFPolicyRegistry.sol";

/// The optimistic track option (silence adopts a pre-accepted result and proves nothing) and the policy
/// registry's validation, families and lookups.
contract ADRFOptimisticAndPolicyTest is ADRFBase {
    bytes32 optPolicy;
    ADRFServiceEscrow e2;
    bytes32 b2;
    uint256 c2;

    function setUp() public override {
        super.setUp();
        e2 = new ADRFServiceEscrow(reg);
        T.PolicySpec memory s = servicePolicy(keccak256("adrf.test.optimistic"), 1, bytes32(0), true);
        s.methods[0].params = bytes32(uint256(uint160(address(e2)))); // the verifiers are bound to this escrow
        s.methods[3].params = bytes32(uint256(uint160(address(e2))));
        optPolicy = pol.registerPolicy(s);
        b2 = e2.bindTo(bindingInput(optPolicy, T.AcceptanceMode.PRE_COMMIT));
        vm.prank(client);
        e2.deposit{value: 2 ether}();
        vm.prank(client);
        c2 = e2.openCall(provider, 1 ether, TERMS, V2, 30 * DAY);
        vm.warp(block.timestamp + 1);
        vm.prank(provider);
        e2.settle(c2);
        vm.prank(provider);
        e2.settle(c2);
    }

    function optClaim() internal view returns (T.ClaimInput memory c) {
        c = duplicateClaim();
        c.object = e2.objectOf(c2);
        c.eventRef = e2.settlementEventRef(2);
        c.subQuestions[0].proposition = verifier.propositionFor(address(e2), c2, 2);
        c.subQuestions[0].inputsHash = dupInputsHash(c2, 2);
    }

    function test_optimistic_silenceAdoptsTheSilenceRule() public {
        T.ClaimInput memory claim = optClaim();
        vm.prank(client);
        bytes32 caseId = reg.file(b2, claim);
        T.CaseClock memory k = reg.getClock(caseId);
        assertEq(k.answerDeadline, k.admittedAt + DAY);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "answer"));
        reg.applySilence(caseId);
        vm.warp(block.timestamp + DAY + 1);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowClosed.selector, "answer"));
        reg.answer(caseId);
        reg.applySilence(caseId);
        assertState(caseId, T.ProcedureState.Provisional);
        T.RoundRecord memory r = reg.getRound(caseId, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.Sustained));
        assertReason(r.reason, T.Reason.SILENCE);
        assertTrue(r.bySilence);
        assertEq(r.supportKinds, 0, "silence proves nothing");
        assertFalse(reg.getFinding(caseId, 0).resolved, "no finding was formed");
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertTrue(u.bySilence);
        assertEq(u.supportKinds, 0);
        assertEq(u.allowedEffect, REFUND);
        uint256 before = e2.balanceOf(client);
        e2.enact(caseId, REFUND);
        assertEq(e2.balanceOf(client), before + 1 ether);
    }

    function test_optimistic_answerContinuesTheOrdinaryProcedure() public {
        T.ClaimInput memory claim = optClaim();
        vm.prank(client);
        bytes32 caseId = reg.file(b2, claim);
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotRespondent.selector, rando));
        reg.answer(caseId);
        vm.prank(provider);
        reg.answer(caseId);
        assertTrue(reg.getClock(caseId).answered);
        vm.warp(block.timestamp + DAY + 1);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_AlreadyAnswered.selector, caseId));
        reg.applySilence(caseId);
        reg.resolveFormal(caseId, 0, dupInputs(c2, 2));
        reg.decide(caseId);
        assertEq(uint8(reg.getRound(caseId, 1).result), uint8(T.SubstantiveResult.Sustained));
        assertFalse(reg.getRound(caseId, 1).bySilence);
    }

    function test_optimistic_meritsBeforeSilence() public {
        T.ClaimInput memory claim = optClaim();
        vm.prank(client);
        bytes32 caseId = reg.file(b2, claim);
        reg.resolveFormal(caseId, 0, dupInputs(c2, 2));
        vm.warp(block.timestamp + DAY + 1);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_AlreadyResolved.selector, uint32(0)));
        reg.applySilence(caseId);
        reg.decide(caseId);
        assertFalse(reg.getRound(caseId, 1).bySilence);
    }

    function test_nonOptimisticCase_hasNoAnswerWindow() public {
        bytes32 caseId = fileAs(client, duplicateClaim());
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotOptimistic.selector, caseId));
        reg.answer(caseId);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotOptimistic.selector, caseId));
        reg.applySilence(caseId);
    }

    // ------------------------------------------------------------------ policy registry

    function test_policy_idIsTheHashOfTheSpec() public view {
        T.PolicySpec memory s = servicePolicy(FAMILY, 1, bytes32(0), false);
        assertEq(pol.policyIdOf(s), keccak256(abi.encode(s)));
        assertEq(pol.policyIdOf(s), policyId);
        assertTrue(pol.policyExists(policyId));
        assertFalse(pol.policyExists(keccak256("x")));
    }

    function test_policy_familiesAndVersions() public {
        (bytes32 latest, uint32 version) = pol.familyLatest(FAMILY);
        assertEq(latest, policyId);
        assertEq(version, 1);
        assertEq(pol.familyAuthority(FAMILY), authority);
        T.PolicySpec memory v2 = servicePolicy(FAMILY, 2, policyId, false);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotFamilyAuthority.selector, FAMILY));
        pol.registerPolicy(v2);
        v2.previous = bytes32(0);
        vm.prank(authority);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_BadFamilyLink.selector, "previous != latest"));
        pol.registerPolicy(v2);
        v2.previous = policyId;
        v2.version = 1;
        vm.prank(authority);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_BadFamilyLink.selector, "version not increasing"));
        pol.registerPolicy(v2);
        v2.version = 2;
        vm.prank(authority);
        bytes32 id2 = pol.registerPolicy(v2);
        (latest, version) = pol.familyLatest(FAMILY);
        assertEq(latest, id2);
        assertEq(version, 2);
        // the earlier version is untouched and still bindable
        assertTrue(pol.policyExists(policyId));
        vm.prank(authority);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_PolicyExists.selector, id2));
        pol.registerPolicy(v2);
    }

    function expectInvalid(T.PolicySpec memory s, string memory what) internal {
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InvalidPolicy.selector, what));
        pol.registerPolicy(s);
    }

    function fresh(string memory tag) internal view returns (T.PolicySpec memory s) {
        s = servicePolicy(keccak256(abi.encode("adrf.test.invalid", tag)), 1, bytes32(0), false);
    }

    function test_policy_validation() public {
        T.PolicySpec memory s = fresh("profile");
        s.resultProfile = keccak256("adrf:result/v9");
        expectInvalid(s, "result profile");

        s = fresh("zero method");
        s.methods[0].method = address(0);
        expectInvalid(s, "zero method");

        s = fresh("dup");
        s.methods[2].obligationKind = s.methods[0].obligationKind;
        s.methods[2].qType = T.QuestionType.FORMAL;
        expectInvalid(s, "duplicate method binding");

        s = fresh("iface");
        s.methods[0].method = address(rule); // an evidence rule bound as a verifier
        expectInvalid(s, "method interface");

        s = fresh("effects");
        s.effects[1].id = s.effects[0].id;
        expectInvalid(s, "duplicate effect");

        s = fresh("filing");
        s.track.filingWindow = 0;
        expectInvalid(s, "zero filing window");

        s = fresh("evidence");
        s.track.evidenceWindow = s.track.decisionWindow + 1;
        expectInvalid(s, "evidence window exceeds decision window");

        s = fresh("review window");
        s.track.reviewWindow = 0;
        expectInvalid(s, "zero review window");

        s = fresh("review types");
        s.track.reviewTypes = 0;
        expectInvalid(s, "review types");

        s = fresh("cap");
        s.track.maxTotalDuration = 11 * DAY; // needs 5 + 1 * (2 + 5) = 12 days
        expectInvalid(s, "maxTotalDuration too short");

        s = fresh("optimistic fields");
        s.track.answerWindow = DAY; // optimistic flag not set
        expectInvalid(s, "optimistic fields");

        s = fresh("silence");
        s.track.optimistic = true;
        s.track.answerWindow = DAY;
        s.track.silenceRule = T.SilenceRule.NONE;
        expectInvalid(s, "silence rule");

        s = fresh("answer window");
        s.track.optimistic = true;
        s.track.answerWindow = s.track.decisionWindow + 1;
        s.track.silenceRule = T.SilenceRule.SUSTAIN;
        expectInvalid(s, "answer window");

        s = fresh("family");
        s.family = bytes32(0);
        expectInvalid(s, "zero family");

        s = fresh("authority");
        s.updateAuthority = address(0);
        expectInvalid(s, "zero update authority");
    }

    function test_policy_lookups() public view {
        (bool found, T.MethodBinding memory m) = pol.findMethod(policyId, KIND_LIMIT, T.QuestionType.FORMAL);
        assertTrue(found);
        assertEq(m.method, address(verifier));
        (found, m) = pol.findMethod(policyId, 42, T.QuestionType.EVIDENCED); // the EVIDENCED binding serves any kind
        assertTrue(found);
        assertEq(m.method, address(rule));
        (found, ) = pol.findMethod(policyId, KIND_LIMIT, T.QuestionType.JUDGED);
        assertFalse(found);
        (found, m) = pol.findMethod(policyId, KIND_RESULT, T.QuestionType.FORMAL);
        assertTrue(found);
        assertEq(m.method, address(versionVerifier));
        (bool declared, T.EffectCategory cat) = pol.effectCategory(policyId, EFFECT_FEE_SPLIT);
        assertTrue(declared);
        assertEq(uint8(cat), uint8(T.EffectCategory.PROCEDURAL_ECONOMIC));
        (declared, ) = pol.effectCategory(policyId, keccak256("none"));
        assertFalse(declared);
        assertEq(pol.methodCount(policyId), 4);
        assertEq(pol.effectCount(policyId), 2);
        T.Track memory t = pol.trackOf(policyId);
        assertEq(t.maxTotalDuration, 12 * DAY);
        (, , , , bytes32 objectKind, T.StandingMode standing, bytes32 profile, , ) = pol.policyHeader(policyId);
        assertEq(objectKind, keccak256("service-call"));
        assertEq(uint8(standing), uint8(T.StandingMode.BENEFICIARIES));
        assertEq(profile, T.RESULT_PROFILE_V1);
    }

    function test_interfaceIds() public view {
        assertTrue(pol.supportsInterface(0x01ffc9a7));
        assertTrue(pol.supportsInterface(type(IADRFPolicyRegistry).interfaceId));
        assertTrue(reg.supportsInterface(0x01ffc9a7));
        assertFalse(reg.supportsInterface(0xffffffff));
        assertEq(reg.CLOCK_MODE(), "mode=timestamp");
        assertEq(reg.clock(), uint48(block.timestamp));
    }
}
