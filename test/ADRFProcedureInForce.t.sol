// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";

/// Revision 5: a delivery is judged against the norm and the procedure in force when it was made; a later change of
/// terms reaches only later events. The escrow keeps the terms of each call as they were when the call was opened
/// (the norm), and it moves to an amended dispute procedure by revoking its binding and binding again: the earlier
/// binding keeps governing the events that occurred while it was in force, with its own filing window, and the
/// escrow keeps enacting rulings made under it. The norm-level counterpart, with a source whose current terms
/// change between deliveries, is test/ADRFNormRevisions.t.sol.
contract ADRFProcedureInForceTest is ADRFBase {
    bytes32 constant TERMS_V2 = keccak256("service terms v2");
    uint64 constant DELIVERED = uint64(START + 1 hours); // the fixture call: delivered, then settled twice
    uint64 constant AMENDED = uint64(START + 3 hours);
    bytes32 policyV2; // the amended procedure: a 14-day filing window instead of 7
    bytes32 b1;       // the binding in force when the fixture call was delivered and charged
    bytes32 b2;       // the binding of the amended procedure

    function setUp() public override {
        super.setUp();
        T.PolicySpec memory s = servicePolicy(FAMILY, 2, policyId, false);
        s.track.filingWindow = 14 * DAY;
        vm.prank(authority);
        policyV2 = pol.registerPolicy(s);
        b1 = bindingId;
        vm.warp(AMENDED);
        escrow.revokeBinding();
        b2 = escrow.bindTo(bindingInput(policyV2, T.AcceptanceMode.PRE_COMMIT));
    }

    function performanceOf(uint256 id, bytes32 terms) internal view returns (T.ClaimInput memory c) {
        c = performanceClaim();
        c.object = escrow.objectOf(id);
        c.normRef = terms;
    }

    function fileUnder(bytes32 binding, T.ClaimInput memory c) internal returns (bytes32 id) {
        vm.prank(client);
        id = reg.file(binding, c);
    }

    function expectFileRevert(bytes32 binding, T.ClaimInput memory c, bytes memory err) internal {
        vm.prank(client);
        vm.expectRevert(err);
        reg.file(binding, c);
    }

    /// The earlier delivery runs under the binding in force when it was made, revoked since, and not under the
    /// amended one, which was registered after it.
    function test_earlierDelivery_runsUnderTheProcedureInForceAtIt() public {
        T.ClaimInput memory c = performanceOf(callId, TERMS);
        expectFileRevert(b2, c, abi.encodeWithSelector(E.ADRF_BindingNotInForce.selector, b2, DELIVERED));
        bytes32 id = fileUnder(b1, c);
        assertState(id, T.ProcedureState.Admitted);
        assertEq(reg.getCase(id).bindingId, b1);
        assertEq(reg.getCase(id).policyId, policyId);
        assertEq(reg.getCase(id).normRef, TERMS);
    }

    /// The amended, longer filing window does not reach the earlier delivery: once its own window has run out, the
    /// delivery cannot be filed under either binding.
    function test_amendedFilingWindow_doesNotExtendAnEarlierDelivery() public {
        vm.warp(DELIVERED + 7 * DAY + 1); // past the 7 days in force at the delivery, inside the amended 14
        T.ClaimInput memory c = performanceOf(callId, TERMS);
        expectFileRevert(b1, c, abi.encodeWithSelector(E.ADRF_OutsideWindow.selector, "filing"));
        expectFileRevert(b2, c, abi.encodeWithSelector(E.ADRF_BindingNotInForce.selector, b2, DELIVERED));
    }

    /// A delivery made after the amendment runs under the amended procedure and its own call's terms: the revoked
    /// binding does not cover it, and neither call can borrow the other's terms.
    function test_laterDelivery_runsUnderTheAmendedProcedureAndTerms() public {
        uint64 later = AMENDED + 1 hours;
        vm.warp(later);
        vm.prank(client);
        uint256 id = escrow.openCall(provider, 1 ether, TERMS_V2, V2, 30 * DAY);
        vm.prank(provider);
        escrow.deliver(id, V2);
        T.ClaimInput memory c = performanceOf(id, TERMS_V2);
        expectFileRevert(b1, c, abi.encodeWithSelector(E.ADRF_BindingNotInForce.selector, b1, later));
        expectFileRevert(b2, performanceOf(id, TERMS), abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "norm not recognised by source"));
        bytes32 caseId = fileUnder(b2, c);
        assertEq(reg.getCase(caseId).policyId, policyV2);
        assertEq(reg.getCase(caseId).normRef, TERMS_V2);
        expectFileRevert(b1, performanceOf(callId, TERMS_V2), abi.encodeWithSelector(E.ADRF_NormNotApplicable.selector, "norm not recognised by source"));
    }

    /// Revocation does not cut the client off and moving on does not orphan the case: the double charge happened
    /// while b1 was in force, so the client files under it after it was revoked, the held settlement is still there,
    /// and the escrow, now bound under b2, enacts the refund of the ruling made under b1.
    function test_revokedBinding_stillGovernsAndEnactsTheEarlierCharge() public {
        bytes32 id = fileUnder(b1, duplicateClaim());
        reg.resolveFormal(id, 0, dupInputs(callId, 2));
        reg.decide(id);
        vm.warp(AMENDED + 2 * DAY + 1);
        reg.finalize(id);
        assertResult(id, T.SubstantiveResult.Sustained);
        assertEq(escrow.bindingId(), b2);
        uint256 before = escrow.balanceOf(client);
        escrow.enact(id, REFUND);
        assertEq(uint8(reg.getEnactment(id, REFUND).status), uint8(T.EnactmentStatus.Enacted));
        assertEq(escrow.balanceOf(client), before + 1 ether);
    }
}
