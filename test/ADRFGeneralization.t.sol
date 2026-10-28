// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T, E} from "./ADRFBase.t.sol";

/// The framework after the generalization to AI disputes: an enterprise account buys a model API service under
/// plain service terms — no agent identity, task token or swarm anywhere — and the three versions of a service
/// call (committed by the terms, declared by the provider, actually used) are kept apart: the first two are on
/// chain and a verifier compares them; the third is a fact an evidence rule establishes. The actor that
/// performed the conduct is recorded separately from the party that bears the obligation.
contract ADRFGeneralizationTest is ADRFBase {
    bytes32 constant SERVICE_ENDPOINT = keccak256("https://api.example-model-provider.test/v2/complete");
    bytes32 constant PROP_VERSION_CLAIM = keccak256("claim: the service did not run the committed model version");
    bytes32 constant PROP_ACTUAL_MATCHES = keccak256("the version actually used for the call matches the committed version");

    /// Claim: the service did not run the committed version. Sub-question 0 (FORMAL): the declared version
    /// differs from the committed one. Sub-question 1 (EVIDENCED): the version actually used matches the committed
    /// one. Decisive: sub-question 1, supporting the claim when FALSE. The actor is the service endpoint.
    function versionClaim(uint256 id) internal view returns (T.ClaimInput memory c) {
        c = baseClaim(EVENT_DELIVERY, PROP_VERSION_CLAIM, keccak256("terms: the service runs the committed model version"), KIND_RESULT, T.Value.FALSE);
        c.object = escrow.objectOf(id);
        c.actorRef = SERVICE_ENDPOINT;
        c.subQuestions = new T.SubQuestionInput[](2);
        c.subQuestions[0] = sub(versionVerifier.propositionFor(address(escrow), id), T.QuestionType.FORMAL, KIND_RESULT, keccak256(abi.encode(id)));
        c.subQuestions[1] = sub(PROP_ACTUAL_MATCHES, T.QuestionType.EVIDENCED, KIND_RESULT, bytes32(0));
        c.decisive = 1;
    }

    function newCall(bytes32 declared) internal returns (uint256 id) {
        vm.prank(client);
        id = escrow.openCall(provider, 1 ether, TERMS, V2, 30 * DAY);
        vm.warp(block.timestamp + 1);
        vm.prank(provider);
        escrow.deliver(id, declared);
        vm.prank(provider);
        escrow.settle(id);
    }

    function attest(bytes32 caseId, uint32 sq, T.Value v, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            vm.prank(attestors[i]);
            rule.attest(panelId, caseId, sq, v);
        }
    }

    function test_plainServiceAccounts_noAgentIdentityRequired() public {
        // the fixture's double-charge flow already runs between two plain accounts; here the claim additionally
        // names the service endpoint as the actor while the provider stays the obligor
        T.ClaimInput memory c = duplicateClaim();
        c.actorRef = SERVICE_ENDPOINT;
        bytes32 caseId = fileAs(client, c);
        T.CaseHeader memory h = reg.getCase(caseId);
        assertEq(h.respondent, provider, "the obligor answers the claim");
        assertEq(h.actorRef, SERVICE_ENDPOINT, "the actor is recorded apart from the obligor");
        assertEq(h.claimant, client);
        reg.resolveFormal(caseId, 0, abi.encode(callId));
        reg.decide(caseId);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        assertResult(caseId, T.SubstantiveResult.Sustained);
        escrow.enact(caseId, REFUND);
        assertEq(uint8(reg.getEnactment(caseId, REFUND).status), uint8(T.EnactmentStatus.Enacted));
    }

    function test_declaredVersionDiffersFromCommitted_isFormal() public {
        uint256 id = newCall(V1); // the provider itself declares a version other than the committed one
        (bytes32 committed, bytes32 declared) = escrow.versionsOf(id);
        assertEq(committed, V2);
        assertEq(declared, V1);
        T.ClaimInput memory c = versionClaim(id);
        c.decisive = 0;                 // the declaration alone decides this claim
        c.supportsWhen = T.Value.TRUE;  // "declared differs from committed" supports it
        bytes32 caseId = fileAs(client, c);
        reg.resolveFormal(caseId, 0, abi.encode(id));
        T.Finding memory f = reg.getFinding(caseId, 0);
        assertValue(f.value, T.Value.TRUE);
        assertEq(f.supportKinds, T.SUPPORT_COMPUTED);
        assertEq(f.acceptedBy, address(versionVerifier));
        reg.decide(caseId);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        assertResult(caseId, T.SubstantiveResult.Sustained);
        assertEq(reg.getRuling(caseId).allowedEffect, REFUND);
    }

    function test_actualVersion_isAFactEstablishedByEvidence_notAFilingPrerequisite() public {
        uint256 id = newCall(V2); // the declaration matches; the client suspects the service actually ran V1
        T.ClaimInput memory c = versionClaim(id);
        // admission does not require the hidden fact to be proven first: the case is admitted on the five criteria
        bytes32 caseId = fileAs(client, c);
        assertState(caseId, T.ProcedureState.Admitted);
        // the formal check cannot settle the matter: the declaration matches the commitment
        reg.resolveFormal(caseId, 0, abi.encode(id));
        assertValue(reg.getFinding(caseId, 0).value, T.Value.FALSE);
        // the actual version is established under the evidence rule: two of three attestors find it did not match
        attest(caseId, 1, T.Value.FALSE, 2);
        reg.resolveEvidenced(caseId, 1, "");
        T.Finding memory f = reg.getFinding(caseId, 1);
        assertValue(f.value, T.Value.FALSE);
        assertEq(f.supportKinds, T.SUPPORT_SIGNED | T.SUPPORT_EVIDENCED);
        reg.decide(caseId);
        T.RoundRecord memory r = reg.getRound(caseId, 1);
        assertEq(uint8(r.result), uint8(T.SubstantiveResult.Sustained));
        // provenance cites the computed declaration check and the evidenced fact, and confers nothing on either
        assertEq(r.supportKinds, T.SUPPORT_SIGNED | T.SUPPORT_EVIDENCED, "only the decisive finding and its premises are cited");
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        assertResult(caseId, T.SubstantiveResult.Sustained);
    }

    function test_actualVersion_noQuorum_isNoDecision_notLiability() public {
        uint256 id = newCall(V2);
        bytes32 caseId = fileAs(client, versionClaim(id));
        reg.resolveFormal(caseId, 0, abi.encode(id));
        attest(caseId, 1, T.Value.FALSE, 1); // one attestor only
        reg.resolveEvidenced(caseId, 1, "");
        reg.decide(caseId);
        assertEq(uint8(reg.getRound(caseId, 1).result), uint8(T.SubstantiveResult.NoDecision));
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseId);
        T.Ruling memory u = reg.getRuling(caseId);
        assertEq(uint8(u.result), uint8(T.SubstantiveResult.NoDecision));
        assertEq(u.allowedEffect, bytes32(0));
        assertEq(u.fallbackRef, STATUS_QUO, "the pre-committed disposition applies; nobody is found liable");
    }

    function test_versionVerifier_undeterminedBeforeDelivery_andForOtherPropositions() public {
        vm.prank(client);
        uint256 id = escrow.openCall(provider, 1 ether, TERMS, V2, 30 * DAY);
        (T.Value v, ) = versionVerifier.verify(versionVerifier.propositionFor(address(escrow), id), bytes32(uint256(uint160(address(escrow)))), abi.encode(id));
        assertValue(v, T.Value.UNDETERMINED);
        (v, ) = versionVerifier.verify(keccak256("some other proposition"), bytes32(uint256(uint160(address(escrow)))), abi.encode(id));
        assertValue(v, T.Value.UNDETERMINED);
    }

    function test_rulingScopeIsTheObject_notTheProvider() public {
        // a sustained version claim on one call takes no slot and decides nothing for another call of the same provider
        uint256 a = newCall(V1);
        uint256 b = newCall(V2);
        T.ClaimInput memory ca = versionClaim(a);
        ca.decisive = 0;
        ca.supportsWhen = T.Value.TRUE;
        bytes32 caseA = fileAs(client, ca);
        reg.resolveFormal(caseA, 0, abi.encode(a));
        reg.decide(caseA);
        vm.warp(block.timestamp + 2 * DAY + 1);
        reg.finalize(caseA);
        assertResult(caseA, T.SubstantiveResult.Sustained);
        T.ClaimInput memory cb = versionClaim(b);
        cb.decisive = 0;
        cb.supportsWhen = T.Value.TRUE;
        bytes32 caseB = fileAs(client, cb);
        assertTrue(reg.getCase(caseB).exclusivityKey != reg.getCase(caseA).exclusivityKey, "different objects, different keys");
        reg.resolveFormal(caseB, 0, abi.encode(b));
        reg.decide(caseB);
        assertEq(uint8(reg.getRound(caseB, 1).result), uint8(T.SubstantiveResult.NotSustained), "call b's declaration matches; the earlier ruling says nothing about it");
    }
}
