// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";
import {IADRFEvidenceRule} from "adrf/interfaces/IADRFEvidenceRule.sol";
import {ExpiryProbeRule} from "./mocks/ExpiryProbeRule.sol";

/// Revision 6: a decisive question nobody resolved by the decision deadline is recorded at expiry as a resolution
/// at that instant would have recorded it, where the registry can establish that without a party's input. An
/// evidence rule is read once, with an empty bundle and a fixed gas allowance; a rule that cannot answer gives
/// TIMEOUT; a call that cannot forward the whole allowance is refused, so no caller can starve the rule into
/// TIMEOUT. Report: https://ethereum-magicians.org/t/30121/18
contract ADRFExpiryTest is ADRFBase {
    uint256 constant ALLOWANCE = 1_000_000;
    uint256 constant REQUIRED = ALLOWANCE + ALLOWANCE / 63 + 20_000;

    ExpiryProbeRule probe;

    function setUp() public override {
        super.setUp();
        probe = new ExpiryProbeRule();
        probe.setRegistry(reg);
    }

    // ------------------------------------------------------------------ helpers

    function _attest(bytes32 id, uint32 sq, T.Value v, uint256 n) private {
        for (uint256 i = 0; i < n; i++) {
            vm.prank(attestors[i]);
            rule.attest(panelId, id, sq, v);
        }
    }

    /// Registers `p` and binds the escrow to it (PRE_COMMIT).
    function _bind(T.PolicySpec memory p) private {
        policyId = pol.registerPolicy(p);
        bindingId = escrow.bindTo(bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT));
    }

    /// A performance claim about a call delivered under the current binding (a PRE_COMMIT binding governs only the
    /// events of its own period).
    function _fileOnNewCall() private returns (bytes32) {
        vm.prank(client);
        callId = escrow.openCall(provider, 1 ether, TERMS, V2, 30 * DAY);
        vm.prank(provider);
        escrow.deliver(callId, V2);
        vm.prank(provider);
        escrow.settle(callId);
        return fileAs(client, performanceClaim());
    }

    /// A policy whose evidenced method is the probe rule.
    function _probePolicy(bytes32 family) private view returns (T.PolicySpec memory p) {
        p = _probePolicy(family, false);
    }

    function _probePolicy(bytes32 family, bool optimistic) private view returns (T.PolicySpec memory p) {
        p = servicePolicy(family, 1, bytes32(0), optimistic);
        p.methods[2].method = address(probe);
    }

    /// A case decided by the probe, past its decision deadline, with the probe set to `mode`.
    function _probeCase(ExpiryProbeRule.Mode mode, T.Value answer) private returns (bytes32 id) {
        _bind(_probePolicy(keccak256(abi.encode("expiry probe", uint8(mode)))));
        id = _fileOnNewCall();
        probe.set(mode, answer);
        vm.warp(reg.getClock(id).decisionDeadline + 1);
    }

    function _assertSameFinding(T.Finding memory got, T.Finding memory want) private pure {
        assertTrue(got.resolved && want.resolved, "both resolved");
        assertValue(got.value, want.value);
        assertReason(got.reason, want.reason);
        assertEq(got.supportKinds, want.supportKinds, "support kinds");
        assertEq(got.resultHash, want.resultHash, "result hash");
        assertEq(got.acceptedBy, want.acceptedBy, "accepted by");
        assertEq(got.round, want.round, "round");
    }

    function _assertTimeoutAtExpiry(ExpiryProbeRule.Mode mode) private {
        bytes32 id = _probeCase(mode, T.Value.TRUE);
        reg.expireDecision(id);
        T.Finding memory f = reg.getFinding(id, 0);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.TIMEOUT);
        assertEq(f.acceptedBy, address(0), "no method accepted it");
        assertEq(f.supportKinds, 0);
        assertEq(f.resultHash, bytes32(0));
        T.RoundRecord memory r = reg.getRound(id, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(r.reason, T.Reason.TIMEOUT);
    }

    /// Memory expansion cost of `size` bytes from zero (yellow paper: 3 per word plus words squared over 512).
    function _memoryCost(uint256 size) private pure returns (uint256) {
        uint256 words = (size + 31) / 32;
        return 3 * words + (words * words) / 512;
    }

    // ------------------------------------------------------------------ the rule's answer at expiry

    /// The panel formed its quorum inside the window and nobody resolved: the expiry records the panel's answer,
    /// exactly what a resolution in the last second of the decision window would have recorded.
    function test_quorumNobodyResolved_expiryRecordsThePanelsAnswer() public {
        bytes32 id = fileAs(client, performanceClaim());
        _attest(id, 0, T.Value.FALSE, 2);
        T.CaseClock memory k = reg.getClock(id);

        uint256 snap = vm.snapshotState();
        vm.warp(k.decisionDeadline);
        reg.resolveEvidenced(id, 0, "");
        T.Finding memory resolved = reg.getFinding(id, 0);
        vm.revertToState(snap);

        vm.warp(k.decisionDeadline + 1);
        vm.expectCall(address(rule), 0, uint64(ALLOWANCE),
            abi.encodeCall(IADRFEvidenceRule.evaluate, (id, uint32(0), PROP_PERFORMED, panelId, bytes(""))));
        vm.prank(rando);
        reg.expireDecision(id);
        T.Finding memory expired = reg.getFinding(id, 0);
        _assertSameFinding(expired, resolved);
        assertValue(expired.value, T.Value.FALSE);
        assertReason(expired.reason, T.Reason.NONE);
        assertEq(expired.acceptedBy, address(rule));
        assertEq(expired.supportKinds, T.SUPPORT_SIGNED | T.SUPPORT_EVIDENCED);
        assertEq(uint8(reg.getRound(id, 1).result), uint8(T.SubstantiveResult.Sustained));
        assertState(id, T.ProcedureState.Provisional);
        vm.warp(reg.getClock(id).reviewOpenUntil + 1);
        reg.finalize(id);
        assertState(id, T.ProcedureState.Final);
        assertResult(id, T.SubstantiveResult.Sustained);
    }

    /// No quorum by the close of the window: the expiry records METHOD_UNDETERMINED, as a resolution between the
    /// close of the window and the deadline would have, not TIMEOUT.
    function test_noQuorum_expiryRecordsMethodUndetermined_asALateResolutionWould() public {
        bytes32 id = fileAs(client, performanceClaim());
        _attest(id, 0, T.Value.FALSE, 1);
        T.CaseClock memory k = reg.getClock(id);

        uint256 snap = vm.snapshotState();
        vm.warp(k.evidenceCloseAt + 1);
        reg.resolveEvidenced(id, 0, "");
        T.Finding memory resolved = reg.getFinding(id, 0);
        vm.revertToState(snap);

        vm.warp(k.decisionDeadline + 1);
        reg.expireDecision(id);
        T.Finding memory expired = reg.getFinding(id, 0);
        _assertSameFinding(expired, resolved);
        assertReason(expired.reason, T.Reason.METHOD_UNDETERMINED);
        T.RoundRecord memory r = reg.getRound(id, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(r.reason, T.Reason.METHOD_UNDETERMINED);
    }

    function test_noQuorum_underTheBurdenRule_isNotSustained() public {
        T.PolicySpec memory p = servicePolicy(keccak256("expiry burden"), 1, bytes32(0), false);
        p.methods[2].onUndetermined = T.OnUndetermined.NOT_SUSTAINED;
        _bind(p);
        bytes32 id = _fileOnNewCall();
        _attest(id, 0, T.Value.FALSE, 1);
        vm.warp(reg.getClock(id).decisionDeadline + 1);
        reg.expireDecision(id);
        assertReason(reg.getFinding(id, 0).reason, T.Reason.METHOD_UNDETERMINED);
        T.RoundRecord memory r = reg.getRound(id, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NotSustained));
        assertReason(r.reason, T.Reason.BURDEN_NOT_MET);
    }

    /// The rule is read once; its finding is recorded with the rule as the accepting method, and a JUDGED support
    /// kind it claims is masked, as on resolution.
    function test_ruleAnswerAtExpiry_isReadOnceAndRecordedAsTheRulesFinding() public {
        bytes32 id = _probeCase(ExpiryProbeRule.Mode.Answer, T.Value.TRUE);
        reg.expireDecision(id);
        assertEq(probe.evaluations(), 1, "read once");
        T.Finding memory f = reg.getFinding(id, 0);
        assertValue(f.value, T.Value.TRUE);
        assertReason(f.reason, T.Reason.NONE);
        assertEq(f.acceptedBy, address(probe));
        assertEq(f.resultHash, keccak256("probe answer"));
        assertEq(f.supportKinds, T.SUPPORT_EVIDENCED, "an evidence rule does not form a judgment");
        assertEq(uint8(reg.getRound(id, 1).result), uint8(T.SubstantiveResult.NotSustained)); // performed: TRUE
    }

    function test_ruleRevertsAtExpiry_givesTimeout() public {
        _assertTimeoutAtExpiry(ExpiryProbeRule.Mode.Revert);
    }

    function test_ruleReturnsShortDataAtExpiry_givesTimeout() public {
        _assertTimeoutAtExpiry(ExpiryProbeRule.Mode.Short);
    }

    function test_ruleReturnsOutOfRangeValueAtExpiry_givesTimeout() public {
        _assertTimeoutAtExpiry(ExpiryProbeRule.Mode.OutOfRange);
    }

    function test_ruleExhaustsItsAllowanceAtExpiry_givesTimeout() public {
        _assertTimeoutAtExpiry(ExpiryProbeRule.Mode.Burn);
    }

    /// Only the first three words of the answer are copied: the registry pays nothing for the size of the return
    /// data; the difference between a 96-byte and a 300,000-byte answer is the rule's own memory, paid from its
    /// allowance.
    function test_largeAnswerAtExpiry_onlyTheFirstThreeWordsAreRead() public {
        _bind(_probePolicy(keccak256("expiry probe: large answer")));
        bytes32 small = _fileOnNewCall();
        bytes32 large = _fileOnNewCall();
        probe.set(ExpiryProbeRule.Mode.Huge, T.Value.UNDETERMINED);
        vm.warp(reg.getClock(large).decisionDeadline + 1);

        probe.setReturnSize(96);
        uint256 g = gasleft();
        reg.expireDecision(small);
        uint256 usedSmall = g - gasleft();

        probe.setReturnSize(300_000);
        g = gasleft();
        reg.expireDecision(large);
        uint256 usedLarge = g - gasleft();

        T.Finding memory f = reg.getFinding(large, 0);
        assertValue(f.value, T.Value.FALSE);
        assertReason(f.reason, T.Reason.NONE);
        assertEq(f.resultHash, bytes32(uint256(0xabc)));
        assertEq(f.supportKinds, T.SUPPORT_EVIDENCED);
        _assertSameFinding(reg.getFinding(small, 0), f);
        assertLt(usedLarge, usedSmall + _memoryCost(300_000) + 25_000, "no copy of the return data");
    }

    // ------------------------------------------------------------------ the gas allowance

    /// A call that cannot forward the whole allowance is refused and records nothing, on both entry points.
    function test_expiryThatCannotForwardTheAllowance_isRefused() public {
        bytes32 id = fileAs(client, performanceClaim());
        _attest(id, 0, T.Value.FALSE, 2);
        T.CaseClock memory k = reg.getClock(id);

        vm.warp(k.decisionDeadline + 1);
        vm.prank(rando);
        (bool ok, bytes memory err) = address(reg).call{gas: ALLOWANCE}(abi.encodeCall(reg.expireDecision, (id)));
        assertFalse(ok, "expireDecision refused");
        assertEq(err, abi.encodeWithSelector(E.ADRF_InsufficientGas.selector, REQUIRED));

        vm.warp(k.hardDeadline + 1);
        vm.prank(rando);
        (ok, err) = address(reg).call{gas: ALLOWANCE}(abi.encodeCall(reg.enforceDeadline, (id)));
        assertFalse(ok, "enforceDeadline refused");
        assertEq(err, abi.encodeWithSelector(E.ADRF_InsufficientGas.selector, REQUIRED));

        assertFalse(reg.getFinding(id, 0).resolved, "nothing recorded");
        assertState(id, T.ProcedureState.Admitted);
        vm.prank(rando);
        reg.expireDecision(id);
        assertValue(reg.getFinding(id, 0).value, T.Value.FALSE);
    }

    /// Whatever gas the caller supplies, the expiry either reverts and records nothing or records the rule's
    /// answer: a caller cannot turn the answer into TIMEOUT by starving the rule. The probe needs 900,000 gas for
    /// its answer and fails with less.
    function test_callerCannotStarveTheRuleIntoTimeout() public {
        bytes32 id = _probeCase(ExpiryProbeRule.Mode.Heavy, T.Value.TRUE);
        uint256 refused;
        uint256 recorded;
        for (uint256 gas = ALLOWANCE; gas <= ALLOWANCE + 600_000; gas += 10_000) {
            uint256 snap = vm.snapshotState();
            vm.prank(rando);
            (bool ok,) = address(reg).call{gas: gas}(abi.encodeCall(reg.expireDecision, (id)));
            T.Finding memory f = reg.getFinding(id, 0);
            if (ok) {
                recorded++;
                assertValue(f.value, T.Value.TRUE);
                assertReason(f.reason, T.Reason.NONE);
                assertEq(f.acceptedBy, address(probe));
            } else {
                refused++;
                assertFalse(f.resolved, "a refused expiry records nothing");
            }
            vm.revertToState(snap);
        }
        assertGt(refused, 0, "some calls were refused");
        assertGt(recorded, 0, "some calls recorded the answer");
    }

    // ------------------------------------------------------------------ a rule that calls back into the registry

    /// Under the optimistic track the silence rule is open to anyone once the decision deadline has passed; a
    /// rule that applies it during the expiry read has the expiry refused, and nothing it did survives.
    function test_ruleThatAppliesSilenceDuringTheExpiryRead_isRefused() public {
        _bind(_probePolicy(keccak256("expiry probe: silence at expiry"), true));
        bytes32 id = _fileOnNewCall();
        probe.set(ExpiryProbeRule.Mode.ReenterSilence, T.Value.TRUE);
        vm.warp(reg.getClock(id).decisionDeadline + 1);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_ReentrantChange.selector, id));
        reg.expireDecision(id);
        assertState(id, T.ProcedureState.Admitted);
        assertFalse(reg.getFinding(id, 0).resolved);
        assertEq(uint8(reg.getRound(id, 1).result), uint8(T.SubstantiveResult.None));
        assertEq(probe.evaluations(), 0, "undone");
        reg.applySilence(id); // the same step, taken directly, is the optimistic track's own
        assertTrue(reg.getRound(id, 1).bySilence);
    }

    function test_ruleThatAppliesSilenceDuringAResolution_isRefused() public {
        _bind(_probePolicy(keccak256("expiry probe: silence at resolution"), true));
        bytes32 id = _fileOnNewCall();
        probe.set(ExpiryProbeRule.Mode.ReenterSilence, T.Value.TRUE);
        vm.warp(reg.getClock(id).answerDeadline + 1);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_ReentrantChange.selector, id));
        reg.resolveEvidenced(id, 0, "");
        assertState(id, T.ProcedureState.Admitted);
        assertFalse(reg.getFinding(id, 0).resolved);
    }

    /// A finding is recorded once: a rule that resolves its own sub-question from inside the evaluation has the
    /// outer resolution refused, and the inner one undone with it.
    function test_ruleThatRecordsItsOwnFindingDuringAResolution_isRefused() public {
        _bind(_probePolicy(keccak256("expiry probe: resolution inside resolution")));
        bytes32 id = _fileOnNewCall();
        probe.set(ExpiryProbeRule.Mode.ReenterResolve, T.Value.TRUE);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_ReentrantChange.selector, id));
        reg.resolveEvidenced(id, 0, "");
        assertFalse(reg.getFinding(id, 0).resolved, "the inner finding is undone");
        assertEq(probe.evaluations(), 0, "undone");
        probe.set(ExpiryProbeRule.Mode.Answer, T.Value.TRUE);
        reg.resolveEvidenced(id, 0, "");
        assertValue(reg.getFinding(id, 0).value, T.Value.TRUE);
        assertEq(probe.evaluations(), 1);
    }

    // ------------------------------------------------------------------ premises and other question types

    /// sq0: the call was charged twice (FORMAL); sq1, decisive: the service was performed (EVIDENCED), premised on
    /// sq0 having `required`.
    function _dependentClaim(T.Value required) private view returns (T.ClaimInput memory c) {
        c = performanceClaim();
        c.subQuestions = new T.SubQuestionInput[](2);
        c.subQuestions[0] = sub(dupProposition(callId, 2), T.QuestionType.FORMAL, KIND_LIMIT, dupInputsHash(callId, 2));
        c.subQuestions[1] = sub(PROP_PERFORMED, T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
        c.subQuestions[1].dependsOn = new uint32[](1);
        c.subQuestions[1].dependsOn[0] = 0;
        c.subQuestions[1].requiredValues = new T.Value[](1);
        c.subQuestions[1].requiredValues[0] = required;
        c.decisive = 1;
    }

    function test_premiseWithAnotherValue_expiryRecordsPremiseNotEstablished() public {
        bytes32 id = fileAs(client, _dependentClaim(T.Value.FALSE));
        reg.resolveFormal(id, 0, dupInputs(callId, 2)); // TRUE: the call was charged twice
        _attest(id, 1, T.Value.FALSE, 2); // a quorum the expiry must not read: the premise failed
        vm.warp(reg.getClock(id).decisionDeadline + 1);
        vm.expectCall(address(rule), abi.encodeWithSelector(IADRFEvidenceRule.evaluate.selector), 0);
        reg.expireDecision(id);
        T.Finding memory f = reg.getFinding(id, 1);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.PREMISE_NOT_ESTABLISHED);
        assertEq(f.acceptedBy, address(0));
        T.RoundRecord memory r = reg.getRound(id, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(r.reason, T.Reason.PREMISE_NOT_ESTABLISHED);
    }

    function test_unresolvedPremise_expiryRecordsTimeout() public {
        bytes32 id = fileAs(client, _dependentClaim(T.Value.FALSE));
        _attest(id, 1, T.Value.FALSE, 2); // the order rule was never met, so no resolution could have read it
        vm.warp(reg.getClock(id).decisionDeadline + 1);
        vm.expectCall(address(rule), abi.encodeWithSelector(IADRFEvidenceRule.evaluate.selector), 0);
        reg.expireDecision(id);
        assertFalse(reg.getFinding(id, 0).resolved, "the premise stays unresolved");
        T.Finding memory f = reg.getFinding(id, 1);
        assertValue(f.value, T.Value.UNDETERMINED);
        assertReason(f.reason, T.Reason.TIMEOUT);
        T.RoundRecord memory r = reg.getRound(id, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(r.reason, T.Reason.TIMEOUT);
    }

    /// A FORMAL verifier needs inputs a party supplies and a JUDGED method pushes its source's result: neither is
    /// read at expiry, and both stay TIMEOUT.
    function test_formalAndJudgedQuestions_expiryRecordsTimeout() public {
        bytes32 formal = fileAs(client, duplicateClaim());
        bytes32 judged = fileAs(client, qualityClaim());
        vm.warp(reg.getClock(formal).decisionDeadline + 1);
        reg.expireDecision(formal);
        reg.expireDecision(judged);
        assertReason(reg.getFinding(formal, 0).reason, T.Reason.TIMEOUT);
        T.RoundRecord memory r = reg.getRound(formal, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NotSustained)); // the verifier's burden rule
        assertReason(r.reason, T.Reason.BURDEN_NOT_MET);
        assertReason(reg.getFinding(judged, 0).reason, T.Reason.TIMEOUT);
        r = reg.getRound(judged, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(r.reason, T.Reason.TIMEOUT);
    }

    /// A finding already recorded is not read again.
    function test_recordedFinding_isNotReadAgainAtExpiry() public {
        bytes32 id = fileAs(client, performanceClaim());
        _attest(id, 0, T.Value.FALSE, 1);
        vm.warp(reg.getClock(id).evidenceCloseAt + 1);
        reg.resolveEvidenced(id, 0, "");
        T.Finding memory before = reg.getFinding(id, 0);
        vm.warp(reg.getClock(id).decisionDeadline + 1);
        vm.expectCall(address(rule), abi.encodeWithSelector(IADRFEvidenceRule.evaluate.selector), 0);
        reg.expireDecision(id);
        T.Finding memory f = reg.getFinding(id, 0);
        _assertSameFinding(f, before);
        assertEq(f.at, before.at, "unchanged");
    }

    // ------------------------------------------------------------------ the hard deadline

    function test_enforceDeadline_readsTheRuleForAMissingFinding() public {
        bytes32 id = fileAs(client, performanceClaim());
        _attest(id, 0, T.Value.FALSE, 2);
        vm.warp(reg.getClock(id).hardDeadline + 1);
        reg.enforceDeadline(id);
        T.Finding memory f = reg.getFinding(id, 0);
        assertValue(f.value, T.Value.FALSE);
        assertEq(f.acceptedBy, address(rule));
        assertState(id, T.ProcedureState.Final);
        T.Ruling memory u = reg.getRuling(id);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertReason(u.closure, T.Reason.TIMEOUT);
    }

    /// A review round truncated by the hard deadline can still have its evidence window close at its decision
    /// deadline (both capped), leaving no instant for a resolution after the window: the expiry reads the rule, so
    /// a quorum formed in the round decides it, and no quorum is METHOD_UNDETERMINED.
    function test_reviewRoundCutByTheHardDeadline_expiryReadsTheRule() public {
        bytes32 id = fileAs(client, performanceClaim());
        _attest(id, 0, T.Value.FALSE, 2);
        T.CaseClock memory k = reg.getClock(id);
        uint64 hard = k.hardDeadline;
        vm.warp(hard - 4 * DAY); // round 1 decided late, at expiry: Sustained, review open for two days
        reg.expireDecision(id);
        assertEq(uint8(reg.getRound(id, 1).result), uint8(T.SubstantiveResult.Sustained));
        uint64 reviewAt = hard - 2 * DAY - 12 hours;
        vm.warp(reviewAt);
        vm.prank(provider);
        reg.requestReview(id, T.REVIEW_EVIDENCE, new uint32[](1));
        k = reg.getClock(id);
        assertEq(k.decisionDeadline, hard);
        assertEq(k.evidenceCloseAt, k.decisionDeadline, "both capped by the hard deadline");

        uint256 snap = vm.snapshotState();
        _attest(id, 0, T.Value.TRUE, 2); // a quorum in round 2: performed
        vm.warp(hard + 1);
        reg.expireDecision(id);
        assertValue(reg.getFinding(id, 0).value, T.Value.TRUE);
        assertState(id, T.ProcedureState.Final);
        T.Ruling memory u = reg.getRuling(id);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.NotSustained));
        assertEq(u.sourceRound, 2);
        assertFalse(u.adoptedFromEarlierRound);
        vm.revertToState(snap);

        vm.warp(reviewAt);
        _attest(id, 0, T.Value.TRUE, 1); // no quorum in round 2
        vm.warp(hard + 1);
        reg.expireDecision(id);
        assertReason(reg.getFinding(id, 0).reason, T.Reason.METHOD_UNDETERMINED);
        T.RoundRecord memory r2 = reg.getRound(id, 2);
        assertEq(uint8(r2.result), uint8(T.SubstantiveResult.NoDecision));
        assertReason(r2.reason, T.Reason.METHOD_UNDETERMINED);
        u = reg.getRuling(id);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.Sustained));
        assertEq(u.sourceRound, 1);
        assertTrue(u.adoptedFromEarlierRound);
    }
}
