// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";
import {ADRFServiceEscrow} from "adrf/examples/ADRFServiceEscrow.sol";
import {MockSource} from "./mocks/MockSource.sol";

/// Revision 4: the source, not the filer, says what counts as a breach and in which direction (admission
/// criterion 3); the contested point is the decisive sub-question, not the claim's wording (exclusivity); each
/// settlement beyond the first is its own event, so a breach after a ruling is a new case; the escrow holds every
/// settlement until the deadline it attests, so a sustained refund is always enactable within it.
contract ADRFRecognitionTest is ADRFBase {
    bytes32 constant NOT_RECOGNISED = keccak256("claim not recognised by source");

    function expectNotRecognised(T.ClaimInput memory c) internal {
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "claim not recognised by source"));
        reg.file(bindingId, c);
    }

    // ------------------------------------------------------------------ direction and the choice of question

    /// A call charged once: the verifier would correctly answer FALSE to "settlement 2 exceeds the limit"; a filer
    /// who sets supportsWhen = FALSE to turn that into a sustained refund is refused at admission, because the
    /// escrow recognizes the duplicate-settlement proposition as a breach only when TRUE.
    function test_invertedDirection_isRefused() public {
        T.ClaimInput memory c = duplicateClaim();
        c.supportsWhen = T.Value.FALSE;
        expectNotRecognised(c);
    }

    /// A decisive question that is trivially true in the filer's chosen sense: "the declared version differs from
    /// the committed one" is FALSE for a conforming delivery, so a claim sustained when FALSE would always win; the
    /// escrow recognizes that proposition as a breach only when TRUE.
    function test_triviallyTrueDecisiveQuestion_isRefused() public {
        T.ClaimInput memory c = qualityClaim();
        c.subQuestions[0] = sub(versionVerifier.propositionFor(address(escrow), callId), T.QuestionType.FORMAL, KIND_RESULT, keccak256(abi.encode(callId)));
        c.supportsWhen = T.Value.FALSE;
        expectNotRecognised(c);
        // the same question in the recognized direction is admitted
        c.supportsWhen = T.Value.TRUE;
        bytes32 id = fileAs(client, c);
        assertState(id, T.ProcedureState.Admitted);
    }

    /// A proposition the terms do not recognize at all, and a recognized proposition under the wrong obligation
    /// kind, are refused; only the decisive sub-question is checked, premises may ask anything.
    function test_unrecognisedProposition_andWrongKind_areRefused() public {
        T.ClaimInput memory c = qualityClaim();
        c.subQuestions[0].proposition = keccak256("the provider was rude");
        expectNotRecognised(c);

        c = qualityClaim();
        c.subQuestions[0].obligationKind = KIND_LIMIT; // conformity is a result obligation, not a limit
        c.obligationKind = KIND_LIMIT;
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "obligation kind"));
        reg.file(bindingId, c);

        // a premise is not a contested point: an unrecognized premise is fine, the decisive is checked
        c = performanceClaim();
        c.subQuestions = new T.SubQuestionInput[](2);
        c.subQuestions[0] = sub(keccak256("some premise nobody recognizes"), T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
        c.subQuestions[1] = sub(PROP_PERFORMED, T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
        c.subQuestions[1].dependsOn = new uint32[](1);
        c.subQuestions[1].requiredValues = new T.Value[](1);
        c.subQuestions[1].requiredValues[0] = T.Value.TRUE;
        c.decisive = 1;
        bytes32 id = fileAs(client, c);
        assertState(id, T.ProcedureState.Admitted);
    }

    /// The direction is checked against the source that is bound, through the interface: a source that
    /// recognizes exactly one predicate admits that one and refuses every other.
    function test_recognitionIsTheSourcesStatement() public {
        MockSource m = new MockSource(reg);
        T.EventInfo memory i;
        i.known = true; i.eventAt = uint64(block.timestamp) - 1 hours; i.obligationRef = keccak256("obligation");
        i.normRef = TERMS; i.normDeclaredAt = i.eventAt - 1 days; i.obligationKind = KIND_LIMIT;
        m.setInfo(i);
        m.setParty(client, true); m.setParty(provider, true);
        bytes32 b = m.bind(bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT));
        m.recognizeOnly(KIND_LIMIT, dupProposition(callId, 2), T.Value.TRUE);

        T.ClaimInput memory c = duplicateClaim();
        c.object = T.ObjectRef({chainId: block.chainid, target: address(m), id: 1, versionHash: keccak256("v1")});
        vm.prank(client);
        bytes32 id = reg.file(b, c);
        assertState(id, T.ProcedureState.Admitted);

        c.subQuestions[0].proposition = dupProposition(callId, 3);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "claim not recognised by source"));
        reg.file(b, c);
    }

    // ------------------------------------------------------------------ the contested point

    /// The exclusivity key is taken on the decisive sub-question's proposition: the same point under another
    /// headline is a Duplicate, and the key equals exclusivityKeyOf(source, obligationRef, decisive proposition).
    function test_exclusivity_isOnTheDecisiveProposition_notTheWording() public {
        bytes32 first = fileAs(client, duplicateClaim());
        bytes32 key = reg.getCase(first).exclusivityKey;
        assertEq(key, reg.exclusivityKeyOf(address(escrow), keccak256(abi.encode(callId, "payment")), dupProposition(callId, 2)));
        T.ClaimInput memory reworded = duplicateClaim();
        reworded.proposition = keccak256("claim: the provider charged this call a second time");
        reworded.documentHash = keccak256("another case document");
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_Duplicate.selector, key, first));
        reg.file(bindingId, reworded);
    }

    // ------------------------------------------------------------------ one case per breach

    /// Every settlement beyond the first is its own event and its own contested point: a third charge after the
    /// ruling on the second is a new case with its own refund; the first charge is never a breach; a settlement
    /// that does not exist is not an identifiable event.
    function test_eachSettlementBeyondTheFirst_isItsOwnCase() public {
        // settlement 1 is within the limit: not a recognized breach
        T.ClaimInput memory c1 = duplicateClaim();
        c1.eventRef = escrow.settlementEventRef(1);
        c1.subQuestions[0].proposition = dupProposition(callId, 1);
        c1.subQuestions[0].inputsHash = dupInputsHash(callId, 1);
        expectNotRecognised(c1);
        // settlement 3 does not exist yet: not identifiable
        T.ClaimInput memory c3 = duplicateClaim();
        c3.eventRef = escrow.settlementEventRef(3);
        c3.subQuestions[0].proposition = dupProposition(callId, 3);
        c3.subQuestions[0].inputsHash = dupInputsHash(callId, 3);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotIdentifiable.selector, "event"));
        reg.file(bindingId, c3);

        // the second settlement: filed, verified, decided, final, refunded
        bytes32 case2 = fileAs(client, duplicateClaim());
        reg.resolveFormal(case2, 0, dupInputs(callId, 2));
        reg.decide(case2);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(case2);
        escrow.enact(case2, REFUND);
        assertEq(uint8(reg.getEnactment(case2, REFUND).status), uint8(T.EnactmentStatus.Enacted));
        // the same point again: Duplicate (Final cases keep the key)
        T.ClaimInput memory again = duplicateClaim();
        bytes32 key2 = reg.getCase(case2).exclusivityKey;
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_Duplicate.selector, key2, case2));
        reg.file(bindingId, again);

        // a third charge after the ruling: a new event, a new case, a new refund
        vm.prank(provider);
        escrow.settle(callId);
        assertEq(escrow.settlementCount(callId), 3);
        vm.warp(block.timestamp + 1);
        bytes32 case3 = fileAs(client, c3);
        assertTrue(reg.getCase(case3).exclusivityKey != reg.getCase(case2).exclusivityKey, "a different contested point");
        reg.resolveFormal(case3, 0, dupInputs(callId, 3));
        T.Finding memory f = reg.getFinding(case3, 0);
        assertValue(f.value, T.Value.TRUE);
        assertEq(f.resultHash, keccak256(abi.encode(address(escrow), callId, uint32(3), uint32(3))));
        reg.decide(case3);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(case3);
        uint256 before = escrow.balanceOf(client);
        escrow.enact(case3, REFUND);
        assertEq(escrow.balanceOf(client), before + 1 ether, "the third settlement refunded");
        (, ADRFServiceEscrow.SettlementState s3) = escrow.settlementOf(callId, 3);
        assertEq(uint8(s3), uint8(ADRFServiceEscrow.SettlementState.Refunded));
        (, ADRFServiceEscrow.SettlementState s1) = escrow.settlementOf(callId, 1);
        assertEq(uint8(s1), uint8(ADRFServiceEscrow.SettlementState.Held), "the legitimate charge stays held for the provider");
    }

    // ------------------------------------------------------------------ the value stays enactable

    /// A settlement is held until settledAt + disputePeriod: the provider cannot withdraw it before, release is
    /// a no-op before the deadline and credits the provider after it, and a refund takes the held settlement.
    function test_settlementsAreHeld_untilTheAttestedDeadline() public {
        assertEq(escrow.balanceOf(provider), 0, "nothing credited at settlement");
        assertEq(escrow.heldOf(callId), 2 ether);
        vm.prank(provider);
        vm.expectRevert(ADRFServiceEscrow.Escrow_Insufficient.selector);
        escrow.withdrawBalance(1 ether);
        escrow.release(callId);
        assertEq(escrow.balanceOf(provider), 0, "release before the dispute period does nothing");
        // the attested deadline of settlement 2 is its instant plus the dispute period
        T.EventInfo memory info = escrow.eventInfo(escrow.objectOf(callId), escrow.settlementEventRef(2));
        (uint64 at2, ) = escrow.settlementOf(callId, 2);
        assertEq(info.adoptionDeadline, at2 + 30 * DAY);
        // the ruling lands inside it and the refund takes the held settlement
        bytes32 id = fileAs(client, duplicateClaim());
        reg.resolveFormal(id, 0, dupInputs(callId, 2));
        reg.decide(id);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(id);
        escrow.enact(id, REFUND);
        assertEq(escrow.heldOf(callId), 1 ether);
        // after the dispute period the remaining settlement is released and withdrawable
        vm.warp(at2 + 30 * DAY);
        escrow.release(callId);
        assertEq(escrow.balanceOf(provider), 1 ether, "the first charge released to the provider");
        assertEq(escrow.heldOf(callId), 0);
        vm.prank(provider);
        escrow.withdrawBalance(1 ether);
        assertEq(provider.balance, 1 ether);
    }

    /// An executor that let the value go reports Failed with the reason, and the record keeps it: here a release
    /// that happened before enactment because the executor was late against the deadline it attested.
    function test_lateExecutor_reportsFailed() public {
        bytes32 id = fileAs(client, duplicateClaim());
        reg.resolveFormal(id, 0, dupInputs(callId, 2));
        reg.decide(id);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(id);
        (uint64 at2, ) = escrow.settlementOf(callId, 2);
        vm.warp(at2 + 30 * DAY);
        escrow.release(callId);                 // both settlements released: the executor is late
        escrow.enact(id, REFUND);
        T.Enactment memory en = reg.getEnactment(id, REFUND);
        assertEq(uint8(en.status), uint8(T.EnactmentStatus.Failed));
        assertEq(en.ref, keccak256("settlement released before enactment"));
        assertFalse(escrow.refunded(id));
        // the failure is the executor's; the ruling stands
        assertResult(id, T.SubstantiveResult.Sustained);
    }

    /// A sustained delivery claim refunds the earliest held charge of the call.
    function test_deliveryClaim_refundsTheHeldCharge() public {
        bytes32 id = fileAs(client, performanceClaim());
        for (uint256 i = 0; i < 2; i++) {
            vm.prank(attestors[i]);
            rule.attest(panelId, id, 0, T.Value.FALSE);
        }
        reg.resolveEvidenced(id, 0, "");
        reg.decide(id);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(id);
        assertResult(id, T.SubstantiveResult.Sustained);
        uint256 before = escrow.balanceOf(client);
        escrow.enact(id, REFUND);
        assertEq(escrow.balanceOf(client), before + 1 ether);
        (, ADRFServiceEscrow.SettlementState s1) = escrow.settlementOf(callId, 1);
        assertEq(uint8(s1), uint8(ADRFServiceEscrow.SettlementState.Refunded), "the first charge, the call's payment");
    }
}
