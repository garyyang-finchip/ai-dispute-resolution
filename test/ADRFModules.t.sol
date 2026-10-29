// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {ADRFBase, T, E} from "./ADRFBase.t.sol";
import {ADRFPolicyRegistry} from "adrf/ADRFPolicyRegistry.sol";
import {ADRFDisputeRegistry} from "adrf/ADRFDisputeRegistry.sol";
import {ADRFModule} from "adrf/modules/ADRFModule.sol";
import {ADRFBindingModule} from "adrf/modules/ADRFBindingModule.sol";
import {ADRFFilingModule} from "adrf/modules/ADRFFilingModule.sol";
import {ADRFResolutionModule} from "adrf/modules/ADRFResolutionModule.sol";
import {ADRFDecisionModule} from "adrf/modules/ADRFDecisionModule.sol";
import {ADRFRecordModule} from "adrf/modules/ADRFRecordModule.sol";
import {ADRFOutcomeModule} from "adrf/modules/ADRFOutcomeModule.sol";
import {IADRFDisputeRegistry as I} from "adrf/interfaces/IADRFDisputeRegistry.sol";

/// The registry's modules: one address, one storage, one log; a module never runs on its own storage; the
/// registry refuses modules built for another policy registry; every function of the interface has a module;
/// nothing else is routed; no ether is accepted.
contract ADRFModulesTest is ADRFBase {
    function selectors() internal pure returns (bytes4[40] memory s) {
        s = [
            I.bind.selector, I.revokeBinding.selector, I.file.selector, I.fileAdvisory.selector, I.accept.selector,
            I.expireAcceptance.selector, I.withdraw.selector, I.submitEvidence.selector, I.answer.selector,
            I.applySilence.selector, I.resolveFormal.selector, I.resolveEvidenced.selector, I.openJudgment.selector,
            I.recordJudgedFinding.selector, I.decide.selector, I.expireDecision.selector, I.requestReview.selector,
            I.finalize.selector, I.enforceDeadline.selector, I.reportEnactment.selector, I.reportLead.selector,
            I.getBinding.selector, I.isAuthorizedEffect.selector, I.isExecutor.selector, I.isBeneficiary.selector,
            I.getCase.selector, I.getClock.selector, I.getSubQuestion.selector, I.getFinding.selector, I.getRound.selector,
            I.getRuling.selector, I.getEnactment.selector, I.activeCaseOf.selector, I.finalCaseOf.selector,
            I.exclusivityKeyOf.selector, I.objectKeyOf.selector, I.supportsInterface.selector, I.policies.selector,
            I.clock.selector, I.CLOCK_MODE.selector
        ];
    }

    /// Every function of the interface is served at the registry's address: the four it implements itself and the
    /// thirty-six it routes, each to a module built for the same policy registry.
    function test_everyInterfaceFunctionIsServed() public view {
        bytes4[40] memory s = selectors();
        bytes4[4] memory own = [I.supportsInterface.selector, I.policies.selector, I.clock.selector, I.CLOCK_MODE.selector];
        uint256 routed = 0;
        for (uint256 i = 0; i < s.length; i++) {
            bool isOwn = false;
            for (uint256 j = 0; j < own.length; j++) if (s[i] == own[j]) isOwn = true;
            if (isOwn) continue;
            address m = registry.moduleOf(s[i]);
            assertTrue(m != address(0), "module");
            assertEq(address(ADRFModule(m).policies()), address(pol), "module policy registry");
            routed++;
        }
        assertEq(routed, 36);
        assertEq(registry.moduleOf(I.bind.selector), registry.bindingModule());
        assertEq(registry.moduleOf(I.file.selector), registry.filingModule());
        assertEq(registry.moduleOf(I.requestReview.selector), registry.resolutionModule());
        assertEq(registry.moduleOf(I.finalize.selector), registry.decisionModule());
        assertEq(registry.moduleOf(I.reportEnactment.selector), registry.recordModule());
        assertEq(registry.moduleOf(I.getRuling.selector), registry.outcomeModule());
        assertTrue(reg.supportsInterface(type(I).interfaceId));
        assertEq(address(reg.policies()), address(pol));
    }

    function test_unknownSelectorReverts() public {
        bytes4 unknown = bytes4(keccak256("notAFunction()"));
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_UnknownFunction.selector, unknown));
        registry.moduleOf(unknown);
        (bool ok, bytes memory ret) = address(reg).call(abi.encodeWithSelector(unknown));
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSelector(E.ADRF_UnknownFunction.selector, unknown));
    }

    function test_noEtherAccepted() public {
        vm.deal(rando, 1 ether);
        vm.prank(rando);
        (bool ok, ) = address(reg).call{value: 1}("");
        assertFalse(ok, "plain transfer");
        vm.prank(rando);
        (ok, ) = address(reg).call{value: 1}(abi.encodeWithSelector(I.decide.selector, bytes32(0)));
        assertFalse(ok, "call with value");
        assertEq(address(reg).balance, 0);
    }

    /// A module refuses to run on its own storage, whether the function writes or reads.
    function test_modulesRefuseDirectCalls() public {
        address[6] memory modules = [
            registry.bindingModule(), registry.filingModule(), registry.resolutionModule(),
            registry.decisionModule(), registry.recordModule(), registry.outcomeModule()
        ];
        bytes[6] memory calls = [
            abi.encodeWithSelector(I.revokeBinding.selector, bindingId),
            abi.encodeWithSelector(I.fileAdvisory.selector, policyId, duplicateClaim(), uint64(START), uint64(START - 1)),
            abi.encodeWithSelector(I.answer.selector, bytes32(0)),
            abi.encodeWithSelector(I.decide.selector, bytes32(0)),
            abi.encodeWithSelector(I.getCase.selector, bytes32(0)),
            abi.encodeWithSelector(I.getRuling.selector, bytes32(0))
        ];
        for (uint256 i = 0; i < modules.length; i++) {
            (bool ok, bytes memory ret) = modules[i].call(calls[i]);
            assertFalse(ok, "direct call");
            assertEq(ret, abi.encodeWithSelector(E.ADRF_DirectCall.selector), "direct call error");
        }
        // the pure helpers have no storage to protect
        assertEq(ADRFRecordModule(registry.recordModule()).exclusivityKeyOf(address(escrow), bytes32("o"), bytes32("p")),
            reg.exclusivityKeyOf(address(escrow), bytes32("o"), bytes32("p")));
    }

    /// The registry refuses a module built for another policy registry and an address without code.
    function test_constructorChecksModules() public {
        ADRFPolicyRegistry other = new ADRFPolicyRegistry();
        address foreign = address(new ADRFBindingModule(other));
        // the module addresses are read first: expectRevert targets the creation, not a getter
        (address b, address f, address r, address d, address rec, address o) = (registry.bindingModule(), registry.filingModule(),
            registry.resolutionModule(), registry.decisionModule(), registry.recordModule(), registry.outcomeModule());
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InvalidModule.selector, foreign));
        new ADRFDisputeRegistry(pol, foreign, f, r, d, rec, o);
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_InvalidModule.selector, rando));
        new ADRFDisputeRegistry(pol, b, f, r, rando, rec, o);
        // the same modules serve a second registry built for the same policy registry: storage is the registry's
        ADRFDisputeRegistry second = new ADRFDisputeRegistry(pol, b, f, r, d, rec, o);
        I reg2 = I(address(second));
        assertEq(reg2.getBinding(bindingId).source, address(0), "second registry has its own record");
        assertEq(reg.getBinding(bindingId).source, address(escrow), "first registry keeps its record");
    }

    /// Every entry a module writes is logged under the registry's address, and a routed revert carries the
    /// module's error unchanged.
    function test_routedCallsLogUnderTheRegistryAndPassRevertsThrough() public {
        vm.recordLogs();
        bytes32 caseId = fileAs(client, duplicateClaim());
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool filed = false;
        bool admitted = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(reg)) continue;
            if (logs[i].topics[0] == I.CaseFiled.selector) { filed = true; assertEq(logs[i].topics[1], caseId); }
            if (logs[i].topics[0] == I.CaseAdmitted.selector) admitted = true;
        }
        assertTrue(filed && admitted, "CaseFiled and CaseAdmitted under the registry's address");
        for (uint256 i = 0; i < 6; i++) {
            address m = [registry.bindingModule(), registry.filingModule(), registry.resolutionModule(),
                registry.decisionModule(), registry.recordModule(), registry.outcomeModule()][i];
            for (uint256 j = 0; j < logs.length; j++) assertTrue(logs[j].emitter != m, "no log under a module's address");
        }
        assertEq(uint8(reg.getCase(caseId).state), uint8(T.ProcedureState.Admitted));
        // revert data of the resolution module, through the registry
        vm.expectRevert(abi.encodeWithSelector(E.ADRF_WrongQuestionType.selector, uint32(0)));
        reg.openJudgment(caseId, 0);
        // return data of the record module, through the registry
        assertEq(reg.activeCaseOf(reg.exclusivityKeyOf(address(escrow), reg.getCase(caseId).obligationRef, dupProposition(callId, 2))), caseId);
    }
}
