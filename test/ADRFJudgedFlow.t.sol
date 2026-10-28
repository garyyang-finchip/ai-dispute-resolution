// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E, A} from "./ADRFBase.t.sol";
import {ADRFACDFBridge} from "adrf/bridges/ADRFACDFBridge.sol";

/// Complete flow 2: a semantic question (the deliverable conforms) decided by an ERC-8436 collective decision
/// through the bridge; the Final result is imported with its provenance and drives the ruling. Plus the
/// NoDecision path, finality by adoption at the ERC-8436 level, and the bridge's own guards.
contract ADRFJudgedFlowTest is ADRFBase {
    function openQuality() internal returns (bytes32 caseId, bytes32 issueId) {
        caseId = fileAs(client, qualityClaim());
        assertState(caseId, T.ProcedureState.Admitted);
        reg.openJudgment(caseId, 0);
        issueId = issueOf(caseId, 0);
        assertTrue(issueId != bytes32(0), "issue filed");
    }

    function test_quality_blockedByPanel_claimSustained() public {
        (bytes32 caseId, bytes32 issueId) = openQuality();

        // the bridge is the ERC-8436 consumer; the issue is Binding, CONSUMER_FILED, bound to this case
        A.Issue memory issue = acdf.getIssue(issueId);
        assertEq(issue.consumer, address(bridge));
        assertEq(uint8(issue.mode), uint8(A.AcceptanceMode.CONSUMER_FILED));
        assertEq(uint8(issue.effectClass), uint8(A.EffectClass.Binding));
        assertEq(issue.subject.target, address(reg));
        assertEq(issue.subject.id, uint256(caseId));
        assertEq(issue.subject.dataHash, PROP_CONFORMS);
        assertEq(issue.obligationId, keccak256(abi.encode(caseId, uint32(0))));
        assertEq(issue.consumerDeadline, reg.getClock(caseId).decisionDeadline);
        assertEq(issue.policyId, acdfPolicyId);

        // a Provisional ERC-8436 result cannot be imported
        voteBlock(issueId, 1, 2);
        acdf.settleRound(issueId);
        A.Result memory r = acdf.getResult(issueId);
        assertEq(uint8(r.state), uint8(A.ProcedureState.Provisional));
        vm.expectRevert(abi.encodeWithSelector(ADRFACDFBridge.Bridge_NotFinal.selector, issueId));
        bridge.importResult(caseId, 0);

        // the decision cannot be taken before the judged finding exists
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_DecisiveUnresolved.selector, caseId));
        reg.decide(caseId);

        vm.warp(block.timestamp + DAY + 1);
        acdf.finalize(issueId);
        r = acdf.getResult(issueId);
        assertEq(uint8(r.state), uint8(A.ProcedureState.Final));
        assertEq(uint8(r.outcomeType), uint8(A.OutcomeType.Decided));
        assertFalse(r.outcomeYes);

        vm.prank(rando);
        bridge.importResult(caseId, 0);
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertTrue(f.resolved);
        assertValue(f.value, T.Value.FALSE);
        assertEq(f.supportKinds, T.SUPPORT_JUDGED);
        assertEq(f.acceptedBy, address(bridge));
        assertEq(f.source.registry, address(acdf));
        assertEq(f.source.issueId, issueId);
        assertEq(f.source.policyId, acdfPolicyId);
        assertEq(f.source.sourceRound, 1);
        assertEq(f.source.roundCount, 1);
        assertFalse(f.source.adoptedFromEarlierRound);
        // the bridge recorded its enactment on the ERC-8436 side
        A.Enactment memory en = acdf.getEnactment(issueId, address(bridge), bridge.EFFECT_FALSE());
        assertEq(uint8(en.status), uint8(A.EnactmentStatus.Enacted));

        // the claim named FALSE as its supporting value: the blocked proposition sustains the claim
        reg.decide(caseId);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertEq(u.allowedEffect, REFUND);
        assertEq(u.supportKinds, T.SUPPORT_JUDGED);
        assertEq(u.judgment.issueId, issueId);
        assertEq(u.judgment.registry, address(acdf));

        uint256 before = escrow.balanceOf(client);
        escrow.enact(caseId, REFUND);
        assertEq(escrow.balanceOf(client), before + 1 ether);
    }

    function test_quality_approvedByPanel_claimNotSustained() public {
        (bytes32 caseId, bytes32 issueId) = openQuality();
        voteApprove(issueId, 1, 2);
        acdf.settleRound(issueId);
        vm.warp(block.timestamp + DAY + 1);
        acdf.finalize(issueId);
        bridge.importResult(caseId, 0);
        assertValue(reg.getFinding(caseId, 0).value, T.Value.TRUE);
        reg.decide(caseId);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.NotSustained));
        assertEq(u.allowedEffect, bytes32(0));
    }

    function test_quality_noDecision_keepsItsMeaning() public {
        (bytes32 caseId, bytes32 issueId) = openQuality();
        // nobody votes: the roster window closes, the round is NoDecision(QUORUM_NOT_MET), appealable, then Final
        vm.warp(block.timestamp + DAY + 1);
        acdf.settleRound(issueId);
        vm.warp(block.timestamp + DAY + 1);
        acdf.finalize(issueId);
        A.Result memory r = acdf.getResult(issueId);
        assertEq(uint8(r.outcomeType), uint8(A.OutcomeType.NoDecision));

        bridge.importResult(caseId, 0);
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.METHOD_UNDETERMINED);
        assertEq(f.source.reason, uint8(A.Reason.QUORUM_NOT_MET));
        // no enactment is recorded on the ERC-8436 side for a NoDecision
        assertEq(uint8(acdf.getEnactment(issueId, address(bridge), bridge.EFFECT_TRUE()).status), uint8(A.EnactmentStatus.NotEnacted));

        // the JUDGED binding's burden rule is NO_DECISION: the claim is neither sustained nor refuted
        reg.decide(caseId);
        T.RoundRecord memory round = reg.getRound(caseId, 1);
        assertEq(uint8(round.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(round.reason, T.Reason.METHOD_UNDETERMINED);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.state), uint8(T.ProcedureState.Final));
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.NoDecision));
        assertEq(u.allowedEffect, bytes32(0), "NoDecision authorizes no substantive effect");
        assertEq(u.fallbackRef, STATUS_QUO, "the pre-committed disposition is referenced");

        // the executor refuses a substantive effect; the registry refuses the REFUND report too
        vm.expectRevert(abi.encodeWithSelector(ADRFServiceEscrowErrors.Escrow_NotEnactable.selector, caseId));
        escrow.enact(caseId, REFUND);
        vm.prank(address(escrow));
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_EffectNotAllowed.selector, REFUND));
        reg.reportEnactment(caseId, REFUND, T.EnactmentStatus.Enacted, bytes32(0));
        // a procedural/economic effect of the policy can still be reported (fee allocation on NoDecision)
        vm.prank(address(escrow));
        reg.reportEnactment(caseId, EFFECT_FEE_SPLIT, T.EnactmentStatus.Enacted, keccak256("fees returned"));
    }

    function test_quality_finalityByAdoption_isImportedAsSuch() public {
        (bytes32 caseId, bytes32 issueId) = openQuality();
        // round 1 blocks the proposition; anyone appeals; round 2 reaches no quorum; PRESERVE adopts round 1
        voteBlock(issueId, 1, 2);
        acdf.settleRound(issueId);
        vm.prank(provider);
        acdf.appeal(issueId);
        vm.warp(block.timestamp + DAY + 1);
        acdf.settleRound(issueId); // round 2: NoDecision(QUORUM_NOT_MET); appeals exhausted => Final
        A.Result memory r = acdf.getResult(issueId);
        assertEq(uint8(r.state), uint8(A.ProcedureState.Final));
        assertEq(uint8(r.outcomeType), uint8(A.OutcomeType.Decided));
        assertFalse(r.outcomeYes);
        assertEq(r.sourceRound, 1);
        assertEq(r.roundCount, 2);
        assertTrue(r.adoptedFromEarlierRound);

        bridge.importResult(caseId, 0);
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertValue(f.value, T.Value.FALSE);
        assertEq(f.source.sourceRound, 1);
        assertEq(f.source.roundCount, 2);
        assertTrue(f.source.adoptedFromEarlierRound, "finality by adoption is carried, not hidden");

        reg.decide(caseId);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertTrue(u.judgment.adoptedFromEarlierRound);
        assertEq(u.judgment.sourceRound, 1);
    }

    function test_bridge_guards() public {
        (bytes32 caseId, bytes32 issueId) = openQuality();
        // only the registry may open or ask for review
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(ADRFACDFBridge.Bridge_NotRegistry.selector, rando));
        bridge.open(caseId, 0, PROP_CONFORMS, acdfPolicyId, uint64(block.timestamp + DAY));
        // a second opening of the same sub-question is refused by the registry
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_JudgmentAlreadyOpened.selector, uint32(0)));
        reg.openJudgment(caseId, 0);
        // only the bound method may push a judged finding
        T.JudgmentSource memory src;
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotMethod.selector, rando));
        reg.recordJudgedFinding(caseId, 0, T.Value.TRUE, bytes32(0), src);
        // import once, never twice
        voteBlock(issueId, 1, 2);
        acdf.settleRound(issueId);
        vm.warp(block.timestamp + DAY + 1);
        acdf.finalize(issueId);
        bridge.importResult(caseId, 0);
        vm.expectRevert(abi.encodeWithSelector(ADRFACDFBridge.Bridge_AlreadyImported.selector, issueId));
        bridge.importResult(caseId, 0);
        // review through the bridge is unavailable: the imported result is already Final at the source
        reg.decide(caseId);
        uint32[] memory targets = new uint32[](1);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(ADRFACDFBridge.Bridge_ReviewUnavailable.selector, issueId));
        reg.requestReview(caseId, T.REVIEW_RULE_APPLICATION, targets);
    }

    function test_judgment_mustFitDecisionWindow() public {
        // a policy whose decision window is shorter than the ERC-8436 hard cap is rejected at registration
        T.PolicySpec memory s = servicePolicy(keccak256("adrf.test.short"), 1, bytes32(0), false);
        s.track.decisionWindow = 2 * DAY; // ERC-8436 policy needs 3 days
        s.track.evidenceWindow = DAY;
        s.track.maxTotalDuration = 2 * DAY + 1 * (2 * DAY + 2 * DAY);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InvalidPolicy.selector, "judgment does not fit decision window"));
        pol.registerPolicy(s);
    }

    function test_judgment_expiredWhenNeverOpened() public {
        // the JUDGED binding's burden rule is NO_DECISION and nobody opens the judgment: the hard deadline
        // closes the case as Expired with NoDecision(TIMEOUT) and the fallback reference
        bytes32 caseId = fileAs(client, qualityClaim());
        vm.warp(block.timestamp + 12 * DAY + 1);
        reg.enforceDeadline(caseId);
        assertState(caseId, T.ProcedureState.Expired);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(u.reason, T.Reason.TIMEOUT);
        assertEq(uint8(u.closure), uint8(T.Reason.TIMEOUT));
        assertEq(u.fallbackRef, STATUS_QUO);
        // Expired takes the exclusivity slot like Final: the same contested point cannot be re-litigated
        T.ClaimInput memory again = qualityClaim();
        bytes32 key = reg.getCase(caseId).exclusivityKey;
        assertEq(reg.finalCaseOf(key), caseId);
        vm.prank(client);
        vm.expectRevert();
        reg.file(bindingId, again);
    }
}

interface ADRFServiceEscrowErrors {
    error Escrow_NotEnactable(bytes32 caseId);
}
