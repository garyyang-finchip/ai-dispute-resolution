// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";

/// Complete flow 1: a deterministic question (the call was charged twice) verified on chain, a Final ruling
/// that allows one substantive effect, enacted once by the bound escrow within its own authority.
contract ADRFFormalFlowTest is ADRFBase {
    function test_duplicateCharge_endToEnd() public {
        bytes32 caseId = fileAs(client, duplicateClaim());
        assertState(caseId, T.ProcedureState.Admitted);
        T.CaseHeader memory h = reg.getCase(caseId);
        assertEq(uint8(h.effectClass), uint8(T.EffectClass.Binding));
        assertEq(h.source, address(escrow));
        assertEq(h.bindingId, bindingId);
        assertEq(reg.activeCaseOf(h.exclusivityKey), caseId, "active case registered");

        T.CaseClock memory k = reg.getClock(caseId);
        assertEq(k.admittedAt, uint64(block.timestamp));
        assertEq(k.decisionDeadline, k.admittedAt + 5 * DAY);
        assertEq(k.hardDeadline, k.admittedAt + 12 * DAY);
        assertEq(k.roundCount, 1);

        // the sub-question is pinned to the verifier bound by the policy
        T.SubQuestion memory q = reg.getSubQuestion(caseId, 0);
        assertEq(q.method, address(verifier));
        assertEq(uint8(q.qType), uint8(T.QuestionType.FORMAL));

        // anyone may run the verifier over the pinned inputs
        vm.prank(rando);
        reg.resolveFormal(caseId, 0, abi.encode(callId));
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertTrue(f.resolved);
        assertValue(f.value, T.Value.TRUE);
        assertEq(f.supportKinds, T.SUPPORT_COMPUTED);
        assertEq(f.acceptedBy, address(verifier));
        assertEq(f.resultHash, keccak256(abi.encode(address(escrow), callId, uint32(2))));

        // decision: the claim named TRUE as the supporting value
        reg.decide(caseId);
        assertState(caseId, T.ProcedureState.Provisional);
        T.RoundRecord memory r = reg.getRound(caseId, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.Sustained));
        assertEq(r.supportKinds, T.SUPPORT_COMPUTED);

        // nobody asks for a review; the provisional decision is adopted when the window lapses
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "review"));
        reg.finalize(caseId);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        assertState(caseId, T.ProcedureState.Final);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertEq(uint8(u.closure), uint8(T.Reason.REVIEW_LAPSED));
        assertEq(u.allowedEffect, REFUND);
        assertEq(u.sourceRound, 1);
        assertEq(u.roundCount, 1);
        assertFalse(u.adoptedFromEarlierRound);
        assertFalse(u.bySilence);
        assertEq(reg.activeCaseOf(h.exclusivityKey), bytes32(0), "active slot released");
        assertEq(reg.finalCaseOf(h.exclusivityKey), caseId, "final case recorded");

        // enactment by the executor, within its own authority, idempotent
        uint256 clientBefore = escrow.balanceOf(client);
        uint256 providerBefore = escrow.balanceOf(provider);
        escrow.enact(caseId, REFUND);
        assertEq(escrow.balanceOf(client), clientBefore + 1 ether);
        assertEq(escrow.balanceOf(provider), providerBefore - 1 ether);
        T.Enactment memory en = reg.getEnactment(caseId, REFUND);
        assertEq(uint8(en.status), uint8(T.EnactmentStatus.Enacted));
        assertEq(en.reporter, address(escrow));

        // duplicate enactment rejected by the executor and by the registry
        vm.expectRevert(abi.encodeWithSelector(ADRFServiceEscrowErrors.Escrow_NotEnactable.selector, caseId));
        escrow.enact(caseId, REFUND);
        vm.prank(address(escrow));
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_EnactmentLocked.selector, REFUND));
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.Enacted, bytes32(0));
    }

    function test_enactmentLog_authorityAndEffects() public {
        bytes32 caseId = fileAs(client, duplicateClaim());
        reg.resolveFormal(caseId, 0, abi.encode(callId));
        reg.decide(caseId);
        // not Final yet
        vm.prank(address(escrow));
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WrongState.selector, caseId, uint8(T.ProcedureState.Provisional)));
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.Pending, bytes32(0));
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);

        // only the source or a named executor
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotExecutor.selector, provider));
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.Enacted, bytes32(0));

        // only the allowed substantive effect or an authorized procedural/economic effect
        bytes32 other = keccak256("adrf:effect/unknown");
        vm.prank(address(escrow));
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_EffectNotAllowed.selector, other));
        reg.reportEnactment(caseId, other, T.EnactmentStatus.Enacted, bytes32(0));
        vm.prank(address(escrow));
        vm.expectRevert(E.ADRF_BadStatus.selector);
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.NotRequested, bytes32(0));

        // Unknown is a state of its own, replaceable by Enacted or Failed; Failed replaceable by Enacted; Enacted locked
        vm.startPrank(address(escrow));
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.Unknown, keccak256("receipt pending"));
        assertEq(uint8(reg.getEnactment(caseId, REFUND).status), uint8(T.EnactmentStatus.Unknown));
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.Failed, keccak256("insufficient"));
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.Enacted, keccak256("done"));
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_EnactmentLocked.selector, REFUND));
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.Failed, keccak256("late"));
        // the procedural/economic effect is reportable independently of the substantive result
        reg.reportEnactment(caseId, EFFECT_FEE_SPLIT, T.EnactmentStatus.Enacted, keccak256("fees split"));
        vm.stopPrank();
        assertEq(uint8(reg.getEnactment(caseId, EFFECT_FEE_SPLIT).status), uint8(T.EnactmentStatus.Enacted));
    }

    function test_formal_inputsMustMatchPinnedHash() public {
        bytes32 caseId = fileAs(client, duplicateClaim());
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InputsMismatch.selector, uint32(0)));
        reg.resolveFormal(caseId, 0, abi.encode(callId + 1));
    }

    function test_formal_notSustainedWhenVerifierSaysFalse() public {
        // a call charged once: the verifier answers FALSE, the claim is not sustained, no effect is allowed
        vm.prank(client);
        uint256 c2 = escrow.openCall(provider, 1 ether, TERMS, V2, 30 * DAY);
        vm.warp(block.timestamp + 1);
        vm.prank(provider);
        escrow.settle(c2);
        T.ClaimInput memory claim = duplicateClaim();
        claim.object = escrow.objectOf(c2);
        claim.subQuestions[0].proposition = verifier.propositionFor(address(escrow), c2);
        claim.subQuestions[0].inputsHash = keccak256(abi.encode(c2));
        bytes32 caseId = fileAs(client, claim);
        reg.resolveFormal(caseId, 0, abi.encode(c2));
        assertValue(reg.getFinding(caseId, 0).value, T.Value.FALSE);
        reg.decide(caseId);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.NotSustained));
        assertReason(u.reason, T.Reason.NONE);
        assertEq(u.allowedEffect, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(ADRFServiceEscrowErrors.Escrow_NotEnactable.selector, caseId));
        escrow.enact(caseId, REFUND);
    }

    function test_formal_burdenRuleOnTimeout() public {
        // nobody runs the verifier; the decision window lapses; the FORMAL binding's burden rule says NotSustained
        bytes32 caseId = fileAs(client, duplicateClaim());
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "decision"));
        reg.expireDecision(caseId);
        vm.warp(block.timestamp + 5 * DAY + 1);
        reg.expireDecision(caseId);
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertTrue(f.resolved);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.TIMEOUT);
        T.RoundRecord memory r = reg.getRound(caseId, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NotSustained));
        assertReason(r.reason, T.Reason.BURDEN_NOT_MET);
        // the verifier can no longer be run after the decision window
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WrongState.selector, caseId, uint8(T.ProcedureState.Provisional)));
        reg.resolveFormal(caseId, 0, abi.encode(callId));
    }

    function test_evidenceWindow() public {
        bytes32 caseId = fileAs(client, duplicateClaim());
        reg.submitEvidence(caseId, 0, keccak256("ledger excerpt"), "ipfs://evidence-1");
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_BadSubQuestions.selector, "index"));
        reg.submitEvidence(caseId, 1, keccak256("x"), "ipfs://x");
        vm.warp(block.timestamp + 3 * DAY + 1);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowClosed.selector, "evidence"));
        reg.submitEvidence(caseId, 0, keccak256("late"), "ipfs://late");
    }

    function test_leadReportOpensNothing() public {
        vm.prank(rando);
        reg.reportLead(escrow.objectOf(callId), keccak256("something looks wrong"), "ipfs://lead");
        bytes32 key = reg.exclusivityKeyOf(address(escrow), keccak256(abi.encode(callId, "payment")), PROP_DUPLICATE_CLAIM);
        assertEq(reg.activeCaseOf(key), bytes32(0));
    }
}

/// Error selectors of the worked example (declared here so the tests can expect them).
interface ADRFServiceEscrowErrors {
    error Escrow_NotEnactable(bytes32 caseId);
}
