// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ADRFBase, T} from "./ADRFBase.t.sol";
import {IADRFPolicyRegistry} from "adrf/interfaces/IADRFPolicyRegistry.sol";
import {IADRFDisputeRegistry} from "adrf/interfaces/IADRFDisputeRegistry.sol";
import {IADRFObligationSource} from "adrf/interfaces/IADRFObligationSource.sol";
import {IADRFVerifier} from "adrf/interfaces/IADRFVerifier.sol";
import {IADRFEvidenceRule} from "adrf/interfaces/IADRFEvidenceRule.sol";
import {IADRFJudgmentMethod} from "adrf/interfaces/IADRFJudgmentMethod.sol";

/// ethers <-> solc cross-checks of the vectors under assets/erc-adrf/vectors.
contract ADRFVectorsTest is ADRFBase {
    string constant V = "assets/erc-adrf/vectors/";

    function read(string memory f) internal view returns (string memory) {
        return vm.readFile(string.concat(vm.projectRoot(), "/", V, f));
    }

    function test_interfaceIds() public view {
        string memory j = read("interface-ids.json");
        assertEq(bytes4(vm.parseJsonBytes(j, ".IADRFPolicyRegistry")), type(IADRFPolicyRegistry).interfaceId, "policy registry");
        assertEq(bytes4(vm.parseJsonBytes(j, ".IADRFDisputeRegistry")), type(IADRFDisputeRegistry).interfaceId, "dispute registry");
        assertEq(bytes4(vm.parseJsonBytes(j, ".IADRFObligationSource")), type(IADRFObligationSource).interfaceId, "source");
        assertEq(bytes4(vm.parseJsonBytes(j, ".IADRFVerifier")), type(IADRFVerifier).interfaceId, "verifier");
        assertEq(bytes4(vm.parseJsonBytes(j, ".IADRFEvidenceRule")), type(IADRFEvidenceRule).interfaceId, "evidence rule");
        assertEq(bytes4(vm.parseJsonBytes(j, ".IADRFJudgmentMethod")), type(IADRFJudgmentMethod).interfaceId, "judgment method");
        assertTrue(pol.supportsInterface(type(IADRFPolicyRegistry).interfaceId));
        assertTrue(reg.supportsInterface(type(IADRFDisputeRegistry).interfaceId));
        assertTrue(escrow.supportsInterface(type(IADRFObligationSource).interfaceId));
        assertTrue(verifier.supportsInterface(type(IADRFVerifier).interfaceId));
        assertTrue(rule.supportsInterface(type(IADRFEvidenceRule).interfaceId));
        assertTrue(bridge.supportsInterface(type(IADRFJudgmentMethod).interfaceId));
    }

    function test_identifiers() public view {
        string memory j = read("identifiers.json");
        assertEq(vm.parseJsonBytes32(j, ".constants.RESULT_PROFILE_V1"), T.RESULT_PROFILE_V1);
        assertEq(vm.parseJsonBytes32(j, ".constants.EFFECT_TRUE"), bridge.EFFECT_TRUE());
        assertEq(vm.parseJsonBytes32(j, ".constants.EFFECT_FALSE"), bridge.EFFECT_FALSE());
        assertEq(vm.parseJsonBytes32(j, ".constants.DISPOSITION_UNDETERMINED"), bridge.DISPOSITION_UNDETERMINED());
        assertEq(vm.parseJsonBytes32(j, ".constants.QUESTION"), bridge.QUESTION());
        assertEq(vm.parseJsonUint(j, ".enums.procedureState.Expired"), uint8(T.ProcedureState.Expired));
        assertEq(vm.parseJsonUint(j, ".enums.substantiveResult.NoDecision"), uint8(T.SubstantiveResult.NoDecision));
        assertEq(vm.parseJsonUint(j, ".enums.reason.PROCEDURE_FAILURE"), uint8(T.Reason.PROCEDURE_FAILURE));
        assertEq(vm.parseJsonUint(j, ".enums.enactmentStatus.Unknown"), uint8(T.EnactmentStatus.Unknown));
        assertEq(vm.parseJsonUint(j, ".enums.supportKinds.judged"), T.SUPPORT_JUDGED);
        assertEq(vm.parseJsonUint(j, '.enums.reviewTypes["rule-application"]'), T.REVIEW_RULE_APPLICATION);
        assertEq(vm.parseJsonUint(j, ".enums.silenceRule.NOT_SUSTAIN"), uint8(T.SilenceRule.NOT_SUSTAIN));
    }

    function test_policyIdFollowsTheAbiEncoding() public view {
        string memory j = read("policy-id.json");
        T.PolicySpec memory s;
        s.family = vm.parseJsonBytes32(j, ".spec.family");
        s.version = uint32(vm.parseJsonUint(j, ".spec.version"));
        s.previous = vm.parseJsonBytes32(j, ".spec.previous");
        s.updateAuthority = vm.parseJsonAddress(j, ".spec.updateAuthority");
        s.objectKind = vm.parseJsonBytes32(j, ".spec.objectKind");
        s.methods = new T.MethodBinding[](3);
        for (uint256 i = 0; i < 3; i++) {
            string memory p = string.concat(".spec.methods[", vm.toString(i), "]");
            s.methods[i] = T.MethodBinding({
                obligationKind: uint8(vm.parseJsonUint(j, string.concat(p, ".obligationKind"))),
                qType: T.QuestionType(uint8(vm.parseJsonUint(j, string.concat(p, ".qType")))),
                method: vm.parseJsonAddress(j, string.concat(p, ".method")),
                params: vm.parseJsonBytes32(j, string.concat(p, ".params")),
                onUndetermined: T.OnUndetermined(uint8(vm.parseJsonUint(j, string.concat(p, ".onUndetermined"))))
            });
        }
        s.effects = new T.Effect[](2);
        for (uint256 i = 0; i < 2; i++) {
            string memory p = string.concat(".spec.effects[", vm.toString(i), "]");
            s.effects[i] = T.Effect({
                id: vm.parseJsonBytes32(j, string.concat(p, ".id")),
                category: T.EffectCategory(uint8(vm.parseJsonUint(j, string.concat(p, ".category"))))
            });
        }
        s.track.filingWindow = uint64(vm.parseJsonUint(j, ".spec.track.filingWindow"));
        s.track.acceptanceWindow = uint64(vm.parseJsonUint(j, ".spec.track.acceptanceWindow"));
        s.track.evidenceWindow = uint64(vm.parseJsonUint(j, ".spec.track.evidenceWindow"));
        s.track.decisionWindow = uint64(vm.parseJsonUint(j, ".spec.track.decisionWindow"));
        s.track.reviewWindow = uint64(vm.parseJsonUint(j, ".spec.track.reviewWindow"));
        s.track.maxReviews = uint32(vm.parseJsonUint(j, ".spec.track.maxReviews"));
        s.track.reviewTypes = uint8(vm.parseJsonUint(j, ".spec.track.reviewTypes"));
        s.track.reviewMode = T.ReviewMode(uint8(vm.parseJsonUint(j, ".spec.track.reviewMode")));
        s.track.maxTotalDuration = uint64(vm.parseJsonUint(j, ".spec.track.maxTotalDuration"));
        s.track.enactmentMargin = uint64(vm.parseJsonUint(j, ".spec.track.enactmentMargin"));
        s.track.optimistic = vm.parseJsonBool(j, ".spec.track.optimistic");
        s.track.answerWindow = uint64(vm.parseJsonUint(j, ".spec.track.answerWindow"));
        s.track.silenceRule = T.SilenceRule(uint8(vm.parseJsonUint(j, ".spec.track.silenceRule")));
        s.standing = T.StandingMode(uint8(vm.parseJsonUint(j, ".spec.standing")));
        s.resultProfile = vm.parseJsonBytes32(j, ".spec.resultProfile");
        s.economicDeclaration = vm.parseJsonBytes32(j, ".spec.economicDeclaration");
        s.descriptorHash = vm.parseJsonBytes32(j, ".spec.descriptorHash");
        assertEq(keccak256(abi.encode(s)), vm.parseJsonBytes32(j, ".policyId"), "policyId");
        assertEq(pol.policyIdOf(s), vm.parseJsonBytes32(j, ".policyId"), "policyIdOf");
        assertEq(keccak256(abi.encode(s)), keccak256(vm.parseJsonBytes(j, ".encoded")), "encoding");
    }

    function test_keys() public view {
        string memory j = read("keys.json");
        T.ObjectRef memory o = T.ObjectRef({
            chainId: vm.parseJsonUint(j, ".object.chainId"),
            target: vm.parseJsonAddress(j, ".object.target"),
            id: vm.parseJsonUint(j, ".object.id"),
            versionHash: vm.parseJsonBytes32(j, ".object.versionHash")
        });
        assertEq(reg.objectKeyOf(o), vm.parseJsonBytes32(j, ".objectKey"), "object key");
        assertEq(
            reg.exclusivityKeyOf(vm.parseJsonAddress(j, ".source"), vm.parseJsonBytes32(j, ".obligationRef"), vm.parseJsonBytes32(j, ".proposition")),
            vm.parseJsonBytes32(j, ".exclusivityKey"), "exclusivity key");
        assertEq(
            keccak256(abi.encode(vm.parseJsonUint(j, ".chainId"), vm.parseJsonAddress(j, ".registryId.registry"), vm.parseJsonUint(j, ".registryId.nonce"))),
            vm.parseJsonBytes32(j, ".registryId.id"), "registry id");
        bytes32 caseId = vm.parseJsonBytes32(j, ".bridge.caseId");
        assertEq(keccak256(abi.encode(caseId, uint32(0))), vm.parseJsonBytes32(j, ".bridge.obligationId"), "bridge obligation id");
        assertEq(keccak256(abi.encode(bridge.QUESTION(), uint32(0))), vm.parseJsonBytes32(j, ".bridge.question"), "bridge question");
    }
}
