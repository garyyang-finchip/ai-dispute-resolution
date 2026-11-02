// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";
import {VersionedNormSource} from "./mocks/VersionedNormSource.sol";

/// A business may amend its current terms while an older delivery is still disputable.
/// Exercise the real registry with immutable event snapshots supplied by a test-only adapter.
contract ADRFNormRevisionsTest is ADRFBase {
    VersionedNormSource source;
    bytes32 sourceBinding;
    bytes32 constant OLD_EVENT = keccak256("delivery 1");
    bytes32 constant NEW_EVENT = keccak256("delivery 2");
    bytes32 constant NEW_TERMS = keccak256("service terms v2");

    function setUp() public override {
        super.setUp();
        source = new VersionedNormSource(reg, client, provider, KIND_RESULT);
        source.declareNorm(TERMS);
        sourceBinding = source.bind(bindingInput(policyId, T.AcceptanceMode.PRE_COMMIT));
        vm.warp(block.timestamp + 1 hours);
        source.recordEvent(OLD_EVENT);
    }

    function amend() internal {
        vm.warp(block.timestamp + 1 hours);
        source.declareNorm(NEW_TERMS);
    }

    function claimFor(bytes32 eventRef, bytes32 norm) internal view returns (T.ClaimInput memory c) {
        c = qualityClaim();
        c.object = source.objectOf(eventRef);
        c.eventRef = eventRef;
        c.normRef = norm;
        c.subQuestions[0] = sub(source.propositionFor(eventRef), T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
        // Admission/resolution coverage only; this fixture does not promise or enact refunds.
        c.requestedEffects = new bytes32[](0);
        c.effectOnSustained = bytes32(0);
    }

    function file(T.ClaimInput memory c) internal returns (bytes32) {
        vm.prank(client);
        return reg.file(sourceBinding, c);
    }

    function test_oldEventStillAdmittedUnderOriginalNormAfterAmendment() public {
        T.EventInfo memory beforeInfo = source.eventInfo(source.objectOf(OLD_EVENT), OLD_EVENT);
        amend();
        bytes32 id = file(claimFor(OLD_EVENT, TERMS));
        assertState(id, T.ProcedureState.Admitted);
        T.CaseHeader memory c = reg.getCase(id);
        assertEq(c.normRef, TERMS);
        assertEq(c.object.versionHash, TERMS);
        assertEq(c.obligationRef, beforeInfo.obligationRef);
        T.EventInfo memory afterInfo = source.eventInfo(source.objectOf(OLD_EVENT), OLD_EVENT);
        assertEq(abi.encode(afterInfo), abi.encode(beforeInfo), "amendment cannot extend old clocks or replace terms");
    }

    function test_latestNormCannotBeSubstitutedForOldEvent() public {
        amend();
        T.ClaimInput memory c = claimFor(OLD_EVENT, NEW_TERMS);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "norm not recognised by source"));
        reg.file(sourceBinding, c);
        assertState(file(claimFor(OLD_EVENT, TERMS)), T.ProcedureState.Admitted);
    }

    function test_newEventUsesNewNormAndCannotBorrowOldNorm() public {
        amend();
        vm.warp(block.timestamp + 1);
        source.recordEvent(NEW_EVENT);
        T.ClaimInput memory c = claimFor(NEW_EVENT, TERMS);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "norm not recognised by source"));
        reg.file(sourceBinding, c);
        bytes32 oldId = file(claimFor(OLD_EVENT, TERMS));
        bytes32 newId = file(claimFor(NEW_EVENT, NEW_TERMS));
        assertState(newId, T.ProcedureState.Admitted);
        assertEq(reg.getCase(newId).normRef, NEW_TERMS);
        assertTrue(reg.getCase(oldId).exclusivityKey != reg.getCase(newId).exclusivityKey);
    }

    function test_amendmentDoesNotChangeAnAdmittedCaseOrItsDecision() public {
        bytes32 id = file(claimFor(OLD_EVENT, TERMS));
        bytes32 key = reg.getCase(id).exclusivityKey;
        amend();
        for (uint256 i = 0; i < 2; i++) {
            vm.prank(attestors[i]);
            rule.attest(panelId, id, 0, T.Value.FALSE);
        }
        reg.resolveEvidenced(id, 0, "");
        reg.decide(id);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(id);
        assertResult(id, T.SubstantiveResult.Sustained);
        assertEq(reg.getCase(id).normRef, TERMS);
        assertEq(reg.getCase(id).exclusivityKey, key);
        assertEq(reg.getRuling(id).allowedEffect, bytes32(0));
    }

    function test_amendmentDoesNotCreateAnotherSlotForSameEvent() public {
        bytes32 id = file(claimFor(OLD_EVENT, TERMS));
        amend();
        T.ClaimInput memory c = claimFor(OLD_EVENT, TERMS);
        c.proposition = keccak256("same delivery, reworded claim after amendment");
        bytes32 key = reg.getCase(id).exclusivityKey;
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_Duplicate.selector, key, id));
        reg.file(sourceBinding, c);
    }

    function test_amendmentCannotRefreshOldFilingWindow() public {
        T.EventInfo memory info = source.eventInfo(source.objectOf(OLD_EVENT), OLD_EVENT);
        vm.warp(info.eventAt + 7 * DAY + 1);
        source.declareNorm(NEW_TERMS);
        T.ClaimInput memory c = claimFor(OLD_EVENT, TERMS);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_OutsideWindow.selector, "filing"));
        reg.file(sourceBinding, c);
    }

    function test_objectVersionCannotBeReplacedWhileRetainingOldEvent() public {
        amend();
        T.ClaimInput memory c = claimFor(OLD_EVENT, TERMS);
        c.object.versionHash = NEW_TERMS;
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_NotIdentifiable.selector, "event"));
        reg.file(sourceBinding, c);
    }
}
