// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";
import {ADRFServiceEscrow} from "adrf/examples/ADRFServiceEscrow.sol";

/// Evidenced sub-questions, the dependency table, reviews, the adoption rule on timeouts (PRESERVE vs
/// REQUIRE_FRESH_DECISION), and the four closures: review lapsed, review round undetermined, decision window
/// lapsed, hard deadline.
contract ADRFReviewTest is ADRFBase {
    function attestAll(bytes32 caseId, uint32 sq, T.Value v, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            vm.prank(attestors[i]);
            rule.attest(panelId, caseId, sq, v);
        }
    }

    function sustainedRound1() internal returns (bytes32 caseId) {
        caseId = fileAs(client, performanceClaim());
        attestAll(caseId, 0, T.Value.FALSE, 2);
        reg.resolveEvidenced(caseId, 0, "");
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertValue(f.value, T.Value.FALSE);
        assertEq(f.supportKinds, T.SUPPORT_SIGNED | T.SUPPORT_EVIDENCED);
        assertEq(f.acceptedBy, address(rule));
        reg.decide(caseId);
        assertState(caseId, T.ProcedureState.Provisional);
        assertEq(uint8(reg.getRound(caseId, 1).result), uint8(T.SubstantiveResult.Sustained));
    }

    function test_evidenced_quorumAndAttestorGuards() public {
        bytes32 caseId = fileAs(client, performanceClaim());
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(AttestorQuorumRuleErrors.Rule_NotAttestor.selector, rando));
        rule.attest(panelId, caseId, 0, T.Value.FALSE);
        attestAll(caseId, 0, T.Value.FALSE, 1); // one of three: no quorum
        reg.resolveEvidenced(caseId, 0, "");
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.METHOD_UNDETERMINED);
        assertEq(f.supportKinds, T.SUPPORT_SIGNED | T.SUPPORT_EVIDENCED, "the rule still names what it looked at");
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_AlreadyResolved.selector, uint32(0)));
        reg.resolveEvidenced(caseId, 0, "");
    }

    function test_review_guards() public {
        bytes32 caseId = sustainedRound1();
        uint32[] memory targets = new uint32[](1);
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotParty.selector, rando));
        reg.requestReview(caseId, T.REVIEW_EVIDENCE, targets);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_ReviewNotAllowed.selector, "type"));
        reg.requestReview(caseId, T.REVIEW_CONFLICT, targets); // not allowed by the track
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_ReviewNotAllowed.selector, "type"));
        reg.requestReview(caseId, T.REVIEW_FACT | T.REVIEW_EVIDENCE, targets); // one type per request
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_ReviewNotAllowed.selector, "no target"));
        reg.requestReview(caseId, T.REVIEW_EVIDENCE, new uint32[](0));
        vm.warp(block.timestamp + 2 * DAY + 1);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowClosed.selector, "review"));
        reg.requestReview(caseId, T.REVIEW_EVIDENCE, targets);
    }

    function test_review_undeterminedRound_preservesTheEarlierDecision() public {
        bytes32 caseId = sustainedRound1();
        uint32[] memory targets = new uint32[](1);
        vm.prank(provider);
        reg.requestReview(caseId, T.REVIEW_EVIDENCE, targets);
        assertState(caseId, T.ProcedureState.Admitted);
        T.CaseClock memory k = reg.getClock(caseId);
        assertEq(k.roundCount, 2);
        assertEq(k.reviewsUsed, 1);
        assertFalse(reg.getFinding(caseId, 0).resolved, "finding reset for the review round");
        // one attestor changes its mind: 1 FALSE vs 1 TRUE, no quorum
        vm.prank(attestors[1]);
        rule.attest(panelId, caseId, 0, T.Value.TRUE);
        reg.resolveEvidenced(caseId, 0, "");
        assertValue(reg.getFinding(caseId, 0).value, T.Value.UNDETERMINED);
        reg.decide(caseId);
        // reviews exhausted: the case closes at once; PRESERVE adopts round 1
        assertState(caseId, T.ProcedureState.Final);
        T.RoundRecord memory r2 = reg.getRound(caseId, 2);
        assertEq(uint8(r2.result), uint8(T.SubstantiveResult.NoDecision));
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertEq(u.sourceRound, 1);
        assertEq(u.roundCount, 2);
        assertTrue(u.adoptedFromEarlierRound);
        assertEq(uint8(u.closure), uint8(T.Reason.NONE));
        assertEq(u.allowedEffect, REFUND);
        assertEq(u.supportKinds, T.SUPPORT_SIGNED | T.SUPPORT_EVIDENCED);
    }

    function test_review_decisionWindowLapses_adoptsEarlierDecision() public {
        bytes32 caseId = sustainedRound1();
        uint32[] memory targets = new uint32[](1);
        vm.prank(client);
        reg.requestReview(caseId, T.REVIEW_FACT, targets);
        vm.warp(block.timestamp + 5 * DAY + 1);
        reg.expireDecision(caseId);
        assertState(caseId, T.ProcedureState.Final);
        T.RoundRecord memory r2 = reg.getRound(caseId, 2);
        assertEq(uint8(r2.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(r2.reason, T.Reason.TIMEOUT);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertTrue(u.adoptedFromEarlierRound);
        assertEq(u.sourceRound, 1);
    }

    function test_review_hardDeadline_adoptsEarlierDecision_withTimeoutClosure() public {
        bytes32 caseId = sustainedRound1();
        uint32[] memory targets = new uint32[](1);
        vm.prank(client);
        reg.requestReview(caseId, T.REVIEW_FACT, targets);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "hard deadline"));
        reg.enforceDeadline(caseId);
        vm.warp(reg.getClock(caseId).hardDeadline + 1);
        reg.enforceDeadline(caseId);
        assertState(caseId, T.ProcedureState.Final);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertTrue(u.adoptedFromEarlierRound);
        assertEq(uint8(u.closure), uint8(T.Reason.TIMEOUT), "timeout and an adopted decision coexist");
    }

    function test_review_requireFreshDecision_vacatesTheEarlierDecision() public {
        T.PolicySpec memory s = servicePolicy(keccak256("adrf.test.fresh"), 1, bytes32(0), false);
        s.track.reviewMode = T.ReviewMode.REQUIRE_FRESH_DECISION;
        bytes32 pid = pol.registerPolicy(s);
        ADRFServiceEscrow e2 = new ADRFServiceEscrow(reg);
        bytes32 b2 = e2.bindTo(bindingInput(pid, T.AcceptanceMode.PRE_COMMIT));
        vm.prank(client);
        uint256 c2 = e2.openCall(provider, 1 ether, TERMS, V2, 30 * DAY);
        vm.warp(block.timestamp + 1);
        vm.prank(provider);
        e2.deliver(c2, V2);
        T.ClaimInput memory claim = performanceClaim();
        claim.object = e2.objectOf(c2);
        vm.prank(client);
        bytes32 caseId = reg.file(b2, claim);
        attestAll(caseId, 0, T.Value.FALSE, 2);
        reg.resolveEvidenced(caseId, 0, "");
        reg.decide(caseId);
        uint32[] memory targets = new uint32[](1);
        vm.prank(provider);
        reg.requestReview(caseId, T.REVIEW_EVIDENCE, targets);
        vm.warp(block.timestamp + 5 * DAY + 1);
        reg.expireDecision(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.state), uint8(T.ProcedureState.Final));
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(u.reason, T.Reason.TIMEOUT);
        assertEq(u.sourceRound, 2);
        assertFalse(u.adoptedFromEarlierRound);
        assertEq(u.allowedEffect, bytes32(0));
        assertEq(u.fallbackRef, STATUS_QUO);
    }

    function test_reviewWindowLapse_adoptsProvisionalDecision_closureReviewLapsed() public {
        bytes32 caseId = sustainedRound1();
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.closure), uint8(T.Reason.REVIEW_LAPSED));
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertFalse(u.adoptedFromEarlierRound);
    }

    function test_dependencyTable_gatesResolutionAndPropagatesPremises() public {
        // sq0: the call was charged twice (FORMAL); sq1: the service was performed (EVIDENCED), premised on sq0 == FALSE
        T.ClaimInput memory c = performanceClaim();
        c.subQuestions = new T.SubQuestionInput[](2);
        c.subQuestions[0] = sub(verifier.propositionFor(address(escrow), callId), T.QuestionType.FORMAL, KIND_LIMIT, keccak256(abi.encode(callId)));
        c.subQuestions[1] = sub(PROP_PERFORMED, T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
        c.subQuestions[1].dependsOn = new uint32[](1);
        c.subQuestions[1].dependsOn[0] = 0;
        c.subQuestions[1].requiredValues = new T.Value[](1);
        c.subQuestions[1].requiredValues[0] = T.Value.FALSE;
        c.decisive = 1;
        bytes32 caseId = fileAs(client, c);

        // the dependent sub-question cannot be touched before its premise
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_PremisePending.selector, uint32(1), uint32(0)));
        reg.resolveEvidenced(caseId, 1, "");
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_DecisiveUnresolved.selector, caseId));
        reg.decide(caseId);
        // the premise resolves TRUE, the required value was FALSE: the dependent is UNDETERMINED without running its method
        reg.resolveFormal(caseId, 0, abi.encode(callId));
        attestAll(caseId, 1, T.Value.FALSE, 2);
        reg.resolveEvidenced(caseId, 1, "");
        T.Finding memory f = reg.getFinding(caseId, 1);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.PREMISE_NOT_ESTABLISHED);
        assertEq(f.supportKinds, 0);
        assertEq(f.acceptedBy, address(0));
        reg.decide(caseId);
        T.RoundRecord memory r = reg.getRound(caseId, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(r.reason, T.Reason.PREMISE_NOT_ESTABLISHED);
    }

    function test_dependencyTable_provenanceIsAUnionThatConfersNothing() public {
        T.ClaimInput memory c = performanceClaim();
        c.subQuestions = new T.SubQuestionInput[](2);
        c.subQuestions[0] = sub(verifier.propositionFor(address(escrow), callId), T.QuestionType.FORMAL, KIND_LIMIT, keccak256(abi.encode(callId)));
        c.subQuestions[1] = sub(PROP_PERFORMED, T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
        c.subQuestions[1].dependsOn = new uint32[](1);
        c.subQuestions[1].dependsOn[0] = 0;
        c.subQuestions[1].requiredValues = new T.Value[](1);
        c.subQuestions[1].requiredValues[0] = T.Value.TRUE;
        c.decisive = 1;
        bytes32 caseId = fileAs(client, c);
        reg.resolveFormal(caseId, 0, abi.encode(callId));
        attestAll(caseId, 1, T.Value.FALSE, 2);
        reg.resolveEvidenced(caseId, 1, "");
        // the derived finding keeps its own support kinds; the round cites the union as provenance only
        assertEq(reg.getFinding(caseId, 1).supportKinds, T.SUPPORT_SIGNED | T.SUPPORT_EVIDENCED);
        reg.decide(caseId);
        assertEq(reg.getRound(caseId, 1).supportKinds, T.SUPPORT_COMPUTED | T.SUPPORT_SIGNED | T.SUPPORT_EVIDENCED);
        // a review that targets the premise resets the dependent as well
        uint32[] memory targets = new uint32[](1);
        targets[0] = 0;
        vm.prank(provider);
        reg.requestReview(caseId, T.REVIEW_FACT, targets);
        assertFalse(reg.getFinding(caseId, 0).resolved);
        assertFalse(reg.getFinding(caseId, 1).resolved);
        // a review that targets only a sub-question the decisive one does not depend on is refused
        vm.warp(block.timestamp + 1);
        reg.resolveFormal(caseId, 0, abi.encode(callId));
        reg.resolveEvidenced(caseId, 1, "");
        reg.decide(caseId);
        assertState(caseId, T.ProcedureState.Final); // reviews exhausted
    }

    function test_review_targetMustReachTheDecisive() public {
        T.ClaimInput memory c = performanceClaim();
        c.subQuestions = new T.SubQuestionInput[](2);
        c.subQuestions[0] = sub(PROP_PERFORMED, T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
        c.subQuestions[1] = sub(verifier.propositionFor(address(escrow), callId), T.QuestionType.FORMAL, KIND_LIMIT, keccak256(abi.encode(callId)));
        c.decisive = 0;
        bytes32 caseId = fileAs(client, c);
        attestAll(caseId, 0, T.Value.FALSE, 2);
        reg.resolveEvidenced(caseId, 0, "");
        reg.decide(caseId);
        uint32[] memory targets = new uint32[](1);
        targets[0] = 1; // independent of the decisive sub-question
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_ReviewNotAllowed.selector, "decisive not targeted"));
        reg.requestReview(caseId, T.REVIEW_FACT, targets);
    }
}

interface AttestorQuorumRuleErrors {
    error Rule_NotAttestor(address account);
}
