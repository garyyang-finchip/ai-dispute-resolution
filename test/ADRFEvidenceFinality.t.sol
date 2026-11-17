// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";
import {AttestorQuorumRule} from "adrf/examples/AttestorQuorumRule.sol";
import {ADRFServiceEscrow} from "adrf/examples/ADRFServiceEscrow.sol";

/// Revision 5: a method's "not yet" is never recorded as its "never", and its "yes" or "no" is final. Anyone may
/// resolve and a finding is recorded once, so an UNDETERMINED is recorded only after the round's evidence window has
/// closed (the registry rule and its boundaries are covered in ADRFPendingEvidence.t.sol), while TRUE and FALSE are
/// recorded at once; the reference rule therefore returns them only when they are final for the round, and a
/// verifier's early UNDETERMINED is pending like a rule's. The recorded finding does not depend on who calls or when.
contract ADRFEvidenceFinalityTest is ADRFBase {
    function attestAs(uint256 i, bytes32 caseId, uint32 sq, T.Value v) internal {
        vm.prank(attestors[i]);
        rule.attest(panelId, caseId, sq, v);
    }

    /// The window closes without a quorum: from then on UNDETERMINED is final, a late attestation is refused, and the
    /// binding's burden rule applies (NO_DECISION for evidenced questions in the test policy).
    function test_windowClosedWithoutQuorum_isUndetermined_andFinal() public {
        bytes32 caseId = fileAs(client, performanceClaim());
        attestAs(0, caseId, 0, T.Value.FALSE);
        uint64 close = reg.getClock(caseId).evidenceCloseAt;
        vm.warp(close); // the last instant of the window: still pending, still open to attestations
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "evidence"));
        reg.resolveEvidenced(caseId, 0, "");
        attestAs(1, caseId, 0, T.Value.TRUE); // 1 FALSE, 1 TRUE: no quorum
        vm.warp(close + 1);
        vm.prank(attestors[2]);
        vm.expectRevert(abi.encodeWithSelector(AttestorQuorumRule.Rule_WindowClosed.selector, caseId, close));
        rule.attest(panelId, caseId, 0, T.Value.FALSE);
        vm.prank(rando);
        reg.resolveEvidenced(caseId, 0, "");
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertTrue(f.resolved);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.METHOD_UNDETERMINED);
        assertGt(f.at, close, "recorded after the window");
        reg.decide(caseId);
        assertEq(uint8(reg.getRound(caseId, 1).result), uint8(T.SubstantiveResult.NoDecision));
    }

    /// A quorum inside the window is final: the round takes no further attestation, so the answer is the same
    /// whoever asks for it and whenever, before or after the window closes.
    function test_quorumInsideTheWindow_isFinal_whoeverResolvesWhenever() public {
        bytes32 caseId = fileAs(client, performanceClaim());
        attestAs(0, caseId, 0, T.Value.TRUE);
        attestAs(1, caseId, 0, T.Value.TRUE);
        vm.prank(attestors[1]);
        vm.expectRevert(abi.encodeWithSelector(AttestorQuorumRule.Rule_QuorumReached.selector, caseId, uint32(0), uint32(1)));
        rule.attest(panelId, caseId, 0, T.Value.FALSE); // a member of the quorum cannot turn it
        vm.prank(attestors[2]);
        vm.expectRevert(abi.encodeWithSelector(AttestorQuorumRule.Rule_QuorumReached.selector, caseId, uint32(0), uint32(1)));
        rule.attest(panelId, caseId, 0, T.Value.FALSE);
        (uint32 yes, uint32 no) = rule.tallyOf(panelId, caseId, 0, 1);
        assertEq(yes, 2);
        assertEq(no, 0);
        vm.warp(reg.getClock(caseId).evidenceCloseAt + 1); // nobody resolved inside the window: the answer has not moved
        reg.resolveEvidenced(caseId, 0, "");
        assertValue(reg.getFinding(caseId, 0).value, T.Value.TRUE);
        reg.decide(caseId);
        // the claim is sustained when "performed" is FALSE; the panel found it TRUE
        assertEq(uint8(reg.getRound(caseId, 1).result), uint8(T.SubstantiveResult.NotSustained));
    }

    /// Before a quorum forms an attestor may revise its attestation; the first quorum is what counts.
    function test_attestorsMayReviseUntilAQuorumForms() public {
        bytes32 caseId = fileAs(client, performanceClaim());
        attestAs(0, caseId, 0, T.Value.TRUE);
        attestAs(0, caseId, 0, T.Value.FALSE); // revised
        assertEq(uint8(rule.attestationOf(caseId, 0, 1, attestors[0])), uint8(T.Value.FALSE));
        attestAs(1, caseId, 0, T.Value.TRUE);
        attestAs(2, caseId, 0, T.Value.FALSE); // two FALSE: the quorum
        reg.resolveEvidenced(caseId, 0, "");
        assertValue(reg.getFinding(caseId, 0).value, T.Value.FALSE);
    }

    /// A panel must be a strict majority of distinct, non-zero attestors: a quorum for one value then excludes a
    /// quorum for the other, and nobody counts twice.
    function test_panelMustBeAStrictMajorityOfDistinctAttestors() public {
        address[] memory four = new address[](4);
        for (uint256 i = 0; i < 4; i++) four[i] = address(uint160(0xA000 + i));
        vm.expectRevert(AttestorQuorumRule.Rule_BadPanel.selector);
        rule.registerPanel(four, 2); // 2 of 4: both values could reach it
        rule.registerPanel(four, 3);
        address[] memory twice = new address[](3);
        twice[0] = address(0xA001);
        twice[1] = address(0xA001);
        twice[2] = address(0xA002);
        vm.expectRevert(AttestorQuorumRule.Rule_BadPanel.selector);
        rule.registerPanel(twice, 2); // one attestor listed twice would count twice
        address[] memory two = new address[](2);
        two[0] = address(0xA001);
        two[1] = address(0xA002);
        vm.expectRevert(AttestorQuorumRule.Rule_BadPanel.selector);
        rule.registerPanel(two, 1); // 1 of 2: a tie
        address[] memory zero = new address[](1);
        vm.expectRevert(AttestorQuorumRule.Rule_BadPanel.selector);
        rule.registerPanel(zero, 1);
    }

    /// Attestations are accepted only for an evidenced sub-question bound to this rule and this panel, of an
    /// admitted case, inside its evidence window; UNDETERMINED is not an attestation.
    function test_attestationsOnlyForBoundSubQuestionsOfAdmittedCases() public {
        bytes32 formal = fileAs(client, duplicateClaim());
        vm.prank(attestors[0]);
        vm.expectRevert(abi.encodeWithSelector(AttestorQuorumRule.Rule_NotBound.selector, formal, uint32(0)));
        rule.attest(panelId, formal, 0, T.Value.TRUE);

        address[] memory same = new address[](3);
        for (uint256 i = 0; i < 3; i++) same[i] = attestors[i];
        bytes32 otherPanel = rule.registerPanel(same, 3);
        bytes32 evidenced = fileAs(client, performanceClaim());
        vm.prank(attestors[0]);
        vm.expectRevert(abi.encodeWithSelector(AttestorQuorumRule.Rule_NotBound.selector, evidenced, uint32(0)));
        rule.attest(otherPanel, evidenced, 0, T.Value.TRUE);
        vm.prank(attestors[0]);
        vm.expectRevert(AttestorQuorumRule.Rule_BadValue.selector);
        rule.attest(panelId, evidenced, 0, T.Value.UNDETERMINED);

        // a POST_DISPUTE case the respondent has not accepted has no evidence window yet
        ADRFServiceEscrow e2 = new ADRFServiceEscrow(reg);
        bytes32 offer = e2.bindTo(bindingInput(policyId, T.AcceptanceMode.POST_DISPUTE));
        vm.prank(client);
        uint256 c2 = e2.openCall(provider, 1 ether, TERMS, V2, 30 * DAY);
        vm.prank(provider);
        e2.deliver(c2, V2);
        T.ClaimInput memory c = performanceClaim();
        c.object = e2.objectOf(c2);
        vm.prank(client);
        bytes32 filed = reg.file(offer, c);
        assertState(filed, T.ProcedureState.Filed);
        vm.prank(attestors[0]);
        vm.expectRevert(abi.encodeWithSelector(AttestorQuorumRule.Rule_WindowClosed.selector, filed, uint64(0)));
        rule.attest(panelId, filed, 0, T.Value.FALSE);
    }

    /// A verifier's early UNDETERMINED is pending in the same way: here a premise the verifier was not built to
    /// decide (a proposition other than its canonical one) is recorded only once the window has closed, while the
    /// determinate decisive question is recorded at once.
    function test_verifierUndetermined_isPendingUntilTheWindowCloses() public {
        T.ClaimInput memory c = duplicateClaim();
        c.subQuestions = new T.SubQuestionInput[](2);
        c.subQuestions[0] = sub(keccak256("a proposition the verifier does not decide"), T.QuestionType.FORMAL, KIND_LIMIT, dupInputsHash(callId, 2));
        c.subQuestions[1] = sub(dupProposition(callId, 2), T.QuestionType.FORMAL, KIND_LIMIT, dupInputsHash(callId, 2));
        c.decisive = 1;
        bytes32 caseId = fileAs(client, c);
        uint64 close = reg.getClock(caseId).evidenceCloseAt;
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "evidence"));
        reg.resolveFormal(caseId, 0, dupInputs(callId, 2));
        reg.resolveFormal(caseId, 1, dupInputs(callId, 2));
        assertValue(reg.getFinding(caseId, 1).value, T.Value.TRUE);
        vm.warp(close + 1);
        reg.resolveFormal(caseId, 0, dupInputs(callId, 2));
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.METHOD_UNDETERMINED);
    }

    /// A review opens a round with a fresh tally and its own evidence window: what the panel said in round 1 is not
    /// counted again, and the review round's question is pending until a quorum forms or its own window closes.
    function test_reviewRound_hasItsOwnTallyAndWindow() public {
        bytes32 caseId = fileAs(client, performanceClaim());
        attestAs(0, caseId, 0, T.Value.FALSE);
        attestAs(1, caseId, 0, T.Value.FALSE);
        reg.resolveEvidenced(caseId, 0, "");
        reg.decide(caseId);
        uint32[] memory targets = new uint32[](1);
        vm.prank(provider);
        reg.requestReview(caseId, T.REVIEW_EVIDENCE, targets);
        T.CaseClock memory k = reg.getClock(caseId);
        assertEq(k.roundCount, 2);
        (uint32 yes, uint32 no) = rule.tallyOf(panelId, caseId, 0, 2);
        assertEq(yes + no, 0, "round 2 starts empty");
        (yes, no) = rule.tallyOf(panelId, caseId, 0, 1);
        assertEq(no, 2, "round 1 stays as it was");
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "evidence"));
        reg.resolveEvidenced(caseId, 0, "");
        attestAs(1, caseId, 0, T.Value.TRUE);
        attestAs(2, caseId, 0, T.Value.TRUE);
        reg.resolveEvidenced(caseId, 0, "");
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertValue(f.value, T.Value.TRUE);
        assertEq(f.round, 2);
    }
}
