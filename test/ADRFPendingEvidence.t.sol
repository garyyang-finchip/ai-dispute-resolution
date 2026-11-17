// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";

/// @author Ted (@haot3x)
/// @notice Regression for Revinand's premature-resolution report:
/// https://ethereum-magicians.org/t/30121/13
contract ADRFPendingEvidenceTest is ADRFBase {
    function _file(T.OnUndetermined burden, uint64 evidenceWindow) private returns (bytes32 id) {
        T.PolicySpec memory p = servicePolicy(keccak256("pending evidence"), 1, bytes32(0), false);
        p.track.maxReviews = 0;
        p.track.reviewWindow = 0;
        p.track.reviewTypes = 0;
        p.track.evidenceWindow = evidenceWindow;
        p.methods[2].onUndetermined = burden;
        policyId = pol.registerPolicy(p);
        bindingId = escrow.bindTo(bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT));
        return fileAs(client, performanceClaim());
    }

    function _attest(bytes32 id, uint256 who, T.Value value) private {
        vm.prank(attestors[who]);
        rule.attest(panelId, id, 0, value);
    }

    function _snapshot(bytes32 id) private view returns (bytes32) {
        return keccak256(abi.encode(reg.getCase(id), reg.getClock(id), reg.getFinding(id, 0), reg.getRuling(id)));
    }

    function _assertPending(bytes32 id) private {
        bytes32 beforeState = _snapshot(id);
        vm.recordLogs();
        // Attempt the complete public sequence. On the old implementation both
        // calls succeed and a no-review case becomes Final before evidence closes.
        vm.prank(rando);
        (bool resolved, bytes memory resolutionError) =
            address(reg).call(abi.encodeWithSelector(reg.resolveEvidenced.selector, id, uint32(0), bytes("")));
        vm.prank(rando);
        (bool decided, bytes memory decisionError) = address(reg).call(abi.encodeWithSelector(reg.decide.selector, id));
        assertState(id, T.ProcedureState.Admitted);
        assertFalse(resolved, "pending evidence must not become a finding");
        assertFalse(decided, "a missing finding cannot decide the case");
        assertEq(resolutionError, abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "evidence"));
        assertEq(decisionError, abi.encodeWithSelector(E.ADRF_DecisiveUnresolved.selector, id));
        assertEq(_snapshot(id), beforeState, "no case, clock, finding or ruling mutation");
        assertEq(vm.getRecordedLogs().length, 0, "failed attempts must retain no logs");
    }

    function _pendingThenQuorum(T.OnUndetermined burden) private {
        bytes32 id = _file(burden, 3 * DAY);
        _assertPending(id); // zero attestations
        _attest(id, 0, T.Value.FALSE);
        _assertPending(id); // one of three, still below threshold
        _attest(id, 1, T.Value.FALSE);
        vm.prank(rando);
        reg.resolveEvidenced(id, 0, "");
        assertValue(reg.getFinding(id, 0).value, T.Value.FALSE);
        reg.decide(id);
        assertState(id, T.ProcedureState.Final);
        assertResult(id, T.SubstantiveResult.Sustained);
        assertLt(block.timestamp, reg.getClock(id).evidenceCloseAt);
    }

    function test_pendingCannotFinalizeNoDecisionBeforeQuorum() public {
        _pendingThenQuorum(T.OnUndetermined.NO_DECISION);
    }

    function test_pendingCannotFinalizeNotSustainedBeforeQuorum() public {
        _pendingThenQuorum(T.OnUndetermined.NOT_SUSTAINED);
    }

    function test_evidenceCloseIsInclusiveAndUndeterminedResolvesAfterIt() public {
        bytes32 id = _file(T.OnUndetermined.NO_DECISION, 3 * DAY);
        uint64 close = reg.getClock(id).evidenceCloseAt;
        vm.warp(close - 1);
        _assertPending(id);
        vm.warp(close);
        _assertPending(id);
        vm.warp(close + 1);
        reg.resolveEvidenced(id, 0, "");
        assertReason(reg.getFinding(id, 0).reason, T.Reason.METHOD_UNDETERMINED);
        reg.decide(id);
        assertResult(id, T.SubstantiveResult.NoDecision);
        assertState(id, T.ProcedureState.Final);
    }

    function test_quorumAtExactEvidenceCloseCanStillResolve() public {
        bytes32 id = _file(T.OnUndetermined.NOT_SUSTAINED, 3 * DAY);
        vm.warp(reg.getClock(id).evidenceCloseAt);
        _attest(id, 0, T.Value.TRUE);
        _attest(id, 1, T.Value.TRUE);
        reg.resolveEvidenced(id, 0, "");
        reg.decide(id);
        assertResult(id, T.SubstantiveResult.NotSustained);
    }

    function test_reviewUsesItsFreshEvidenceWindowBeforeAdoptingEarlierRound() public {
        bytes32 id = fileAs(client, performanceClaim());
        _attest(id, 0, T.Value.FALSE);
        _attest(id, 1, T.Value.FALSE);
        reg.resolveEvidenced(id, 0, "");
        reg.decide(id);
        uint64 firstClose = reg.getClock(id).evidenceCloseAt;
        vm.warp(block.timestamp + DAY);
        vm.prank(provider);
        reg.requestReview(id, T.REVIEW_EVIDENCE, new uint32[](1));
        uint64 reviewClose = reg.getClock(id).evidenceCloseAt;
        assertGt(reviewClose, firstClose);
        _attest(id, 1, T.Value.TRUE); // no longer a quorum
        vm.warp(firstClose + 1);
        _assertPending(id);
        vm.warp(reviewClose);
        _assertPending(id);
        vm.warp(reviewClose + 1);
        reg.resolveEvidenced(id, 0, "");
        reg.decide(id);
        assertResult(id, T.SubstantiveResult.Sustained);
        assertTrue(reg.getRuling(id).adoptedFromEarlierRound);
        assertEq(reg.getRuling(id).sourceRound, 1);
    }

    function test_equalEvidenceAndDecisionWindowsStillAllowTimeout() public {
        bytes32 id = _file(T.OnUndetermined.NO_DECISION, 5 * DAY);
        T.CaseClock memory k = reg.getClock(id);
        assertEq(k.evidenceCloseAt, k.decisionDeadline);
        vm.warp(k.decisionDeadline);
        _assertPending(id);
        vm.warp(k.decisionDeadline + 1);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WindowClosed.selector, "decision"));
        reg.resolveEvidenced(id, 0, "");
        reg.expireDecision(id);
        assertReason(reg.getFinding(id, 0).reason, T.Reason.TIMEOUT);
        assertResult(id, T.SubstantiveResult.NoDecision);
    }

    function test_zeroEvidenceWindowStillClosesAfterAdmissionTimestamp() public {
        bytes32 id = _file(T.OnUndetermined.NOT_SUSTAINED, 0);
        assertEq(reg.getClock(id).evidenceCloseAt, block.timestamp);
        _assertPending(id);
        vm.warp(block.timestamp + 1);
        reg.resolveEvidenced(id, 0, "");
        reg.decide(id);
        assertResult(id, T.SubstantiveResult.NotSustained);
        assertReason(reg.getRuling(id).reason, T.Reason.BURDEN_NOT_MET);
    }
}
