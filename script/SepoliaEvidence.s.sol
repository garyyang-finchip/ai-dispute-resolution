// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ADRFTypes as T} from "adrf/ADRFTypes.sol";
import {ADRFPolicyRegistry} from "adrf/ADRFPolicyRegistry.sol";
import {ADRFDisputeRegistry} from "adrf/ADRFDisputeRegistry.sol";
import {IADRFDisputeRegistry} from "adrf/interfaces/IADRFDisputeRegistry.sol";
// The modules and the vendored ERC-8436 reference are imported so that their artifacts are part of this script's
// compilation output (vm.deployCode finds them there); nothing here references their creation code.
import {ADRFBindingModule} from "adrf/modules/ADRFBindingModule.sol";
import {ADRFFilingModule} from "adrf/modules/ADRFFilingModule.sol";
import {ADRFResolutionModule} from "adrf/modules/ADRFResolutionModule.sol";
import {ADRFDecisionModule} from "adrf/modules/ADRFDecisionModule.sol";
import {ADRFRecordModule} from "adrf/modules/ADRFRecordModule.sol";
import {ADRFOutcomeModule} from "adrf/modules/ADRFOutcomeModule.sol";
import {ADRFACDFBridge} from "adrf/bridges/ADRFACDFBridge.sol";
import {DuplicateSettlementVerifier} from "adrf/examples/DuplicateSettlementVerifier.sol";
import {DeclaredVersionVerifier} from "adrf/examples/DeclaredVersionVerifier.sol";
import {AttestorQuorumRule} from "adrf/examples/AttestorQuorumRule.sol";
import {ADRFServiceEscrow} from "adrf/examples/ADRFServiceEscrow.sol";
import {IACDFRegistry} from "adrf/interfaces/acdf/IACDFRegistry.sol";
import {IACDFPolicyRegistry} from "adrf/interfaces/acdf/IACDFPolicyRegistry.sol";
import {ACDFTypes as A} from "adrf/interfaces/acdf/ACDFTypes.sol";
import {ACDFPolicyRegistry as LocalACDFPolicyRegistry} from "acdf/ACDFPolicyRegistry.sol";
import {ACDFRegistry as LocalACDFRegistry} from "acdf/ACDFRegistry.sol";

/// Evidence run: deploys the registries (the dispute registry with its six modules), the methods, the bridge over a live ERC-8436 registry (or a local one
/// on Anvil), the worked-example escrow bound to a fast-track policy, and walks the two complete flows with
/// real transactions. Phases (env PHASE): deploy | formal-file | formal-finalize | judged-file | judged-vote |
/// judged-finalize. State is kept in deployments/<chainId>.json. Keys: PRIVATE_KEY (deployer); the client,
/// provider and three jurors are derived from it and funded in the deploy phase.
///
/// Every contract is deployed from its compiled artifact (`vm.deployCode`), so that this script's own creation
/// code stays small: a script that embeds the creation code of everything it deploys exceeds the EIP-3860 initcode
/// limit that recent Foundry versions apply to the local deployment of the script contract itself.
///
/// Rehearsal on Anvil (code size limit raised for the vendored ERC-8436 fixture):
///   anvil --code-size-limit 32768 &
///   PRIVATE_KEY=<anvil key> PHASE=deploy forge script script/SepoliaEvidence.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
///   ... then the other phases, warping Anvil's clock (evm_increaseTime) between them.
contract SepoliaEvidence is Script {
    struct State {
        address policies; address registry; address bindingModule; address filingModule; address resolutionModule; address decisionModule; address recordModule; address outcomeModule; address verifier; address versionVerifier; address rule; address bridge; address escrow;
        address acdfRegistry; address acdfPolicies; bytes32 acdfPolicyId; bytes32 panelId; bytes32 policyId; bytes32 bindingId;
        uint256 callFormal; bytes32 caseFormal; uint256 callJudged; bytes32 caseJudged; bytes32 issueJudged;
    }

    uint64 constant MIN = 60;

    function run() external {
        string memory phase = vm.envString("PHASE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (eq(phase, "deploy")) deploy(pk);
        else if (eq(phase, "formal-file")) formalFile(pk);
        else if (eq(phase, "formal-finalize")) formalFinalize(pk);
        else if (eq(phase, "judged-file")) judgedFile(pk);
        else if (eq(phase, "judged-vote")) judgedVote(pk);
        else if (eq(phase, "judged-finalize")) judgedFinalize(pk);
        else if (eq(phase, "judged-close")) judgedClose(pk);
        else revert("unknown PHASE");
    }

    // ------------------------------------------------------------------ keys and state

    function derived(uint256 pk, string memory label) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(pk, label))) % 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    }

    function statePath() internal view returns (string memory) {
        return string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), ".json");
    }

    function load() internal view returns (State memory s) {
        string memory j = vm.readFile(statePath());
        s.policies = vm.parseJsonAddress(j, ".policies");
        s.registry = vm.parseJsonAddress(j, ".registry");
        s.bindingModule = vm.parseJsonAddress(j, ".bindingModule");
        s.filingModule = vm.parseJsonAddress(j, ".filingModule");
        s.resolutionModule = vm.parseJsonAddress(j, ".resolutionModule");
        s.decisionModule = vm.parseJsonAddress(j, ".decisionModule");
        s.recordModule = vm.parseJsonAddress(j, ".recordModule");
        s.outcomeModule = vm.parseJsonAddress(j, ".outcomeModule");
        s.verifier = vm.parseJsonAddress(j, ".verifier");
        s.versionVerifier = vm.parseJsonAddress(j, ".versionVerifier");
        s.rule = vm.parseJsonAddress(j, ".rule");
        s.bridge = vm.parseJsonAddress(j, ".bridge");
        s.escrow = vm.parseJsonAddress(j, ".escrow");
        s.acdfRegistry = vm.parseJsonAddress(j, ".acdfRegistry");
        s.acdfPolicies = vm.parseJsonAddress(j, ".acdfPolicies");
        s.acdfPolicyId = vm.parseJsonBytes32(j, ".acdfPolicyId");
        s.panelId = vm.parseJsonBytes32(j, ".panelId");
        s.policyId = vm.parseJsonBytes32(j, ".policyId");
        s.bindingId = vm.parseJsonBytes32(j, ".bindingId");
        s.callFormal = vm.parseJsonUint(j, ".callFormal");
        s.caseFormal = vm.parseJsonBytes32(j, ".caseFormal");
        s.callJudged = vm.parseJsonUint(j, ".callJudged");
        s.caseJudged = vm.parseJsonBytes32(j, ".caseJudged");
        s.issueJudged = vm.parseJsonBytes32(j, ".issueJudged");
    }

    function save(State memory s) internal {
        string memory o = "state";
        vm.serializeAddress(o, "policies", s.policies);
        vm.serializeAddress(o, "registry", s.registry);
        vm.serializeAddress(o, "bindingModule", s.bindingModule);
        vm.serializeAddress(o, "filingModule", s.filingModule);
        vm.serializeAddress(o, "resolutionModule", s.resolutionModule);
        vm.serializeAddress(o, "decisionModule", s.decisionModule);
        vm.serializeAddress(o, "recordModule", s.recordModule);
        vm.serializeAddress(o, "outcomeModule", s.outcomeModule);
        vm.serializeAddress(o, "verifier", s.verifier);
        vm.serializeAddress(o, "versionVerifier", s.versionVerifier);
        vm.serializeAddress(o, "rule", s.rule);
        vm.serializeAddress(o, "bridge", s.bridge);
        vm.serializeAddress(o, "escrow", s.escrow);
        vm.serializeAddress(o, "acdfRegistry", s.acdfRegistry);
        vm.serializeAddress(o, "acdfPolicies", s.acdfPolicies);
        vm.serializeBytes32(o, "acdfPolicyId", s.acdfPolicyId);
        vm.serializeBytes32(o, "panelId", s.panelId);
        vm.serializeBytes32(o, "policyId", s.policyId);
        vm.serializeBytes32(o, "bindingId", s.bindingId);
        vm.serializeUint(o, "callFormal", s.callFormal);
        vm.serializeBytes32(o, "caseFormal", s.caseFormal);
        vm.serializeUint(o, "callJudged", s.callJudged);
        vm.serializeBytes32(o, "caseJudged", s.caseJudged);
        string memory out = vm.serializeBytes32(o, "issueJudged", s.issueJudged);
        vm.writeJson(out, statePath());
    }

    // ------------------------------------------------------------------ phase: deploy

    function deploy(uint256 pk) internal {
        State memory s;
        address deployer = vm.addr(pk);
        address client = vm.addr(derived(pk, "client"));
        address provider = vm.addr(derived(pk, "provider"));
        address[] memory jurors = new address[](3);
        for (uint256 i = 0; i < 3; i++) jurors[i] = vm.addr(derived(pk, string.concat("juror", vm.toString(i))));

        vm.startBroadcast(pk);
        ADRFPolicyRegistry pol = ADRFPolicyRegistry(vm.deployCode("ADRFPolicyRegistry.sol:ADRFPolicyRegistry"));
        address binding = vm.deployCode("ADRFBindingModule.sol:ADRFBindingModule", abi.encode(pol));
        address filing = vm.deployCode("ADRFFilingModule.sol:ADRFFilingModule", abi.encode(pol));
        address resolution = vm.deployCode("ADRFResolutionModule.sol:ADRFResolutionModule", abi.encode(pol));
        address decision = vm.deployCode("ADRFDecisionModule.sol:ADRFDecisionModule", abi.encode(pol));
        address record = vm.deployCode("ADRFRecordModule.sol:ADRFRecordModule", abi.encode(pol));
        address outcome = vm.deployCode("ADRFOutcomeModule.sol:ADRFOutcomeModule", abi.encode(pol));
        IADRFDisputeRegistry reg = IADRFDisputeRegistry(vm.deployCode("ADRFDisputeRegistry.sol:ADRFDisputeRegistry",
            abi.encode(pol, binding, filing, resolution, decision, record, outcome)));
        DuplicateSettlementVerifier verifier = DuplicateSettlementVerifier(vm.deployCode("DuplicateSettlementVerifier.sol:DuplicateSettlementVerifier"));
        DeclaredVersionVerifier versionVerifier = DeclaredVersionVerifier(vm.deployCode("DeclaredVersionVerifier.sol:DeclaredVersionVerifier"));
        AttestorQuorumRule rule = AttestorQuorumRule(vm.deployCode("AttestorQuorumRule.sol:AttestorQuorumRule"));

        // ERC-8436: the live registry (ACDF_REGISTRY) or a local deployment of the vendored reference on Anvil
        IACDFRegistry acdf;
        if (vm.envOr("ACDF_REGISTRY", address(0)) != address(0)) {
            acdf = IACDFRegistry(vm.envAddress("ACDF_REGISTRY"));
        } else {
            acdf = IACDFRegistry(deployLocalAcdf());
        }
        IACDFPolicyRegistry acdfPol = acdf.policies();
        ADRFACDFBridge bridge = ADRFACDFBridge(vm.deployCode("ADRFACDFBridge.sol:ADRFACDFBridge", abi.encode(reg, acdf)));

        // fast-track ERC-8436 policy: 2-of-3 roster, 15-minute window, one appeal of 10 minutes
        A.BodySpec[] memory bodies = new A.BodySpec[](1);
        bodies[0].kind = A.BodyKind.ROSTER_KOFN;
        bodies[0].acceptance = A.Acceptance.ON_CHAIN_TALLY;
        bodies[0].members = jurors;
        bodies[0].k = 2;
        bodies[0].window = 15 * MIN;
        A.Node[] memory nodes = new A.Node[](1);
        nodes[0].op = A.Combinator.BODY;
        nodes[0].children = new uint32[](0);
        A.PolicySpec memory ap;
        ap.family = keccak256(abi.encode("adrf.evidence.acdf", block.chainid, deployer));
        ap.version = 1;
        ap.updateAuthority = deployer;
        ap.bodies = bodies;
        ap.nodes = nodes;
        ap.maxAppeals = 1;
        ap.appealWindow = 10 * MIN;
        ap.appealable = 3;
        ap.appealStanding = A.AppealStanding.ANYONE;
        ap.appealMode = A.AppealMode.PRESERVE_UNLESS_OVERTURNED;
        ap.maxTotalDuration = 40 * MIN;
        ap.descriptorHash = keccak256("adrf evidence run: acdf fast-track policy");
        s.acdfPolicyId = acdfPol.registerPolicy(ap);

        address[] memory attestors = new address[](3);
        attestors[0] = jurors[0]; attestors[1] = jurors[1]; attestors[2] = jurors[2];
        s.panelId = rule.registerPanel(attestors, 2);

        ADRFServiceEscrow escrow = ADRFServiceEscrow(payable(vm.deployCode("ADRFServiceEscrow.sol:ADRFServiceEscrow", abi.encode(reg))));

        // fast-track ADRF policy
        T.PolicySpec memory p;
        p.family = keccak256(abi.encode("adrf.evidence.service", block.chainid, deployer));
        p.version = 1;
        p.updateAuthority = deployer;
        p.objectKind = keccak256("service-call");
        p.methods = new T.MethodBinding[](4);
        p.methods[0] = T.MethodBinding(escrow.KIND_LIMIT(), T.QuestionType.FORMAL, address(verifier), bytes32(uint256(uint160(address(escrow)))), T.OnUndetermined.NOT_SUSTAINED);
        p.methods[3] = T.MethodBinding(escrow.KIND_RESULT(), T.QuestionType.FORMAL, address(versionVerifier), bytes32(uint256(uint160(address(escrow)))), T.OnUndetermined.NOT_SUSTAINED);
        p.methods[1] = T.MethodBinding(escrow.KIND_RESULT(), T.QuestionType.JUDGED, address(bridge), s.acdfPolicyId, T.OnUndetermined.NO_DECISION);
        p.methods[2] = T.MethodBinding(0, T.QuestionType.EVIDENCED, address(rule), s.panelId, T.OnUndetermined.NO_DECISION);
        p.effects = new T.Effect[](2);
        p.effects[0] = T.Effect(escrow.EFFECT_REFUND(), T.EffectCategory.SUBSTANTIVE);
        p.effects[1] = T.Effect(keccak256("adrf:effect/fee-split"), T.EffectCategory.PROCEDURAL_ECONOMIC);
        p.track.filingWindow = 1 days;
        p.track.acceptanceWindow = 30 * MIN;
        p.track.evidenceWindow = 30 * MIN;
        p.track.decisionWindow = 60 * MIN;
        p.track.reviewWindow = 10 * MIN;
        p.track.maxReviews = 1;
        p.track.reviewTypes = T.REVIEW_FACT | T.REVIEW_EVIDENCE | T.REVIEW_RULE_APPLICATION;
        p.track.reviewMode = T.ReviewMode.PRESERVE_UNLESS_OVERTURNED;
        p.track.maxTotalDuration = 60 * MIN + 1 * (10 * MIN + 60 * MIN);
        p.track.enactmentMargin = 10 * MIN;
        p.standing = T.StandingMode.BENEFICIARIES;
        p.resultProfile = T.RESULT_PROFILE_V1;
        p.economicDeclaration = keccak256("adrf evidence run: economic declaration");
        p.descriptorHash = keccak256("adrf evidence run: policy document");
        s.policyId = pol.registerPolicy(p);

        T.BindingInput memory b;
        b.policyId = s.policyId;
        b.mode = T.AcceptanceMode.PRE_COMMIT;
        b.authorizedEffects = new bytes32[](2);
        b.authorizedEffects[0] = escrow.EFFECT_REFUND();
        b.authorizedEffects[1] = keccak256("adrf:effect/fee-split");
        b.executors = new address[](0);
        b.beneficiaries = new address[](0);
        b.termsHash = keccak256("adrf evidence run: binding document");
        s.bindingId = escrow.bindTo(b);

        // fund the actors
        payable(client).transfer(0.012 ether);
        payable(provider).transfer(0.004 ether);
        for (uint256 i = 0; i < 3; i++) payable(jurors[i]).transfer(0.002 ether);
        vm.stopBroadcast();

        s.policies = address(pol); s.registry = address(reg); s.verifier = address(verifier);
        s.bindingModule = binding; s.filingModule = filing; s.resolutionModule = resolution; s.decisionModule = decision; s.recordModule = record; s.outcomeModule = outcome; s.versionVerifier = address(versionVerifier); s.rule = address(rule);
        s.bridge = address(bridge); s.escrow = address(escrow); s.acdfRegistry = address(acdf); s.acdfPolicies = address(acdfPol);
        save(s);
        console2.log("deployed; registry", address(reg));
    }

    function deployLocalAcdf() internal returns (address) {
        // The vendored ERC-8436 reference (test/vendor/acdf) for rehearsals; Anvil must run with a raised code
        // size limit (the fixture is compiled here with optimizer runs 200). On Sepolia the live registry is used.
        address pol = vm.deployCode("test/vendor/acdf/ACDFPolicyRegistry.sol:ACDFPolicyRegistry");
        return vm.deployCode("test/vendor/acdf/ACDFRegistry.sol:ACDFRegistry", abi.encode(pol));
    }

    // ------------------------------------------------------------------ phase: formal

    function formalFile(uint256 pk) internal {
        State memory s = load();
        ADRFServiceEscrow escrow = ADRFServiceEscrow(payable(s.escrow));
        IADRFDisputeRegistry reg = IADRFDisputeRegistry(s.registry);
        uint256 clientPk = derived(pk, "client");
        uint256 providerPk = derived(pk, "provider");
        address provider = vm.addr(providerPk);

        vm.startBroadcast(clientPk);
        escrow.deposit{value: 0.004 ether}();
        uint256 callId = escrow.openCall(provider, 0.001 ether, keccak256("service terms v1"), keccak256("model v2"), 4 hours);
        vm.stopBroadcast();

        vm.startBroadcast(providerPk);
        escrow.deliver(callId, keccak256("model v2"));
        escrow.settle(callId);
        escrow.settle(callId); // the double charge
        vm.stopBroadcast();

        // the event is the second settlement; the decisive sub-question is the verifier's proposition for it
        T.ClaimInput memory c = baseClaim(escrow, callId, escrow.settlementEventRef(2), keccak256("claim: the call was charged twice"),
            keccak256("terms: at most one charge per call"), escrow.KIND_LIMIT(), T.Value.TRUE, provider);
        c.subQuestions = new T.SubQuestionInput[](1);
        c.subQuestions[0] = sub(DuplicateSettlementVerifier(s.verifier).propositionFor(s.escrow, callId, 2), T.QuestionType.FORMAL, escrow.KIND_LIMIT(), keccak256(abi.encode(callId, uint32(2))));

        vm.startBroadcast(clientPk);
        bytes32 caseId = reg.file(s.bindingId, c);
        reg.resolveFormal(caseId, 0, abi.encode(callId, uint32(2)));
        reg.decide(caseId);
        vm.stopBroadcast();

        s.callFormal = callId;
        s.caseFormal = caseId;
        save(s);
        console2.log("formal case filed, resolved and decided (Provisional); finalize after the review window");
        console2.logBytes32(caseId);
    }

    function formalFinalize(uint256 pk) internal {
        State memory s = load();
        IADRFDisputeRegistry reg = IADRFDisputeRegistry(s.registry);
        ADRFServiceEscrow escrow = ADRFServiceEscrow(payable(s.escrow));
        vm.startBroadcast(pk);
        reg.finalize(s.caseFormal);
        escrow.enact(s.caseFormal, escrow.EFFECT_REFUND());
        vm.stopBroadcast();
        T.Ruling memory u = reg.getRuling(s.caseFormal);
        console2.log("formal ruling result (1 = Sustained):", uint8(u.result));
        console2.log("enactment status (2 = Enacted):", uint8(reg.getEnactment(s.caseFormal, escrow.EFFECT_REFUND()).status));
    }

    // ------------------------------------------------------------------ phase: judged

    function judgedFile(uint256 pk) internal {
        State memory s = load();
        ADRFServiceEscrow escrow = ADRFServiceEscrow(payable(s.escrow));
        IADRFDisputeRegistry reg = IADRFDisputeRegistry(s.registry);
        uint256 clientPk = derived(pk, "client");
        uint256 providerPk = derived(pk, "provider");
        address provider = vm.addr(providerPk);

        vm.startBroadcast(clientPk);
        escrow.deposit{value: 0.002 ether}();
        uint256 callId = escrow.openCall(provider, 0.001 ether, keccak256("service terms v1"), keccak256("model v2"), 4 hours);
        vm.stopBroadcast();
        vm.startBroadcast(providerPk);
        escrow.deliver(callId, keccak256("model v2"));
        escrow.settle(callId);
        vm.stopBroadcast();

        T.ClaimInput memory c = baseClaim(escrow, callId, escrow.EVENT_DELIVERY(), keccak256("claim: the delivery does not conform"),
            keccak256("terms: the deliverable conforms to the acceptance criteria"), escrow.KIND_RESULT(), T.Value.FALSE, provider);
        c.subQuestions = new T.SubQuestionInput[](1);
        c.subQuestions[0] = sub(keccak256("the deliverable conforms to the acceptance criteria"), T.QuestionType.JUDGED, escrow.KIND_RESULT(), bytes32(0));

        vm.startBroadcast(clientPk);
        bytes32 caseId = reg.file(s.bindingId, c);
        reg.openJudgment(caseId, 0);
        vm.stopBroadcast();

        s.callJudged = callId;
        s.caseJudged = caseId;
        s.issueJudged = ADRFACDFBridge(s.bridge).issueOf(keccak256(abi.encode(caseId, uint32(0))));
        save(s);
        console2.log("judged case filed; ERC-8436 issue opened");
        console2.logBytes32(s.issueJudged);
    }

    function judgedVote(uint256 pk) internal {
        State memory s = load();
        IACDFRegistry acdf = IACDFRegistry(s.acdfRegistry);
        for (uint256 i = 0; i < 2; i++) {
            vm.startBroadcast(derived(pk, string.concat("juror", vm.toString(i))));
            acdf.castBallot(s.issueJudged, 1, 0, false); // block: the deliverable does not conform
            vm.stopBroadcast();
        }
        vm.startBroadcast(pk);
        acdf.settleRound(s.issueJudged);
        vm.stopBroadcast();
        console2.log("round 1 settled (No); finalize the issue after the appeal window");
    }

    function judgedFinalize(uint256 pk) internal {
        State memory s = load();
        IACDFRegistry acdf = IACDFRegistry(s.acdfRegistry);
        IADRFDisputeRegistry reg = IADRFDisputeRegistry(s.registry);
        vm.startBroadcast(pk);
        acdf.finalize(s.issueJudged);
        ADRFACDFBridge(s.bridge).importResult(s.caseJudged, 0);
        reg.decide(s.caseJudged);
        vm.stopBroadcast();
        T.Finding memory f = reg.getFinding(s.caseJudged, 0);
        console2.log("imported value (2 = FALSE):", uint8(f.value));
        console2.log("case Provisional; run judged-close after the review window");
    }

    function judgedClose(uint256 pk) internal {
        State memory s = load();
        IADRFDisputeRegistry reg = IADRFDisputeRegistry(s.registry);
        ADRFServiceEscrow escrow = ADRFServiceEscrow(payable(s.escrow));
        vm.startBroadcast(pk);
        reg.finalize(s.caseJudged);
        escrow.enact(s.caseJudged, escrow.EFFECT_REFUND());
        vm.stopBroadcast();
        T.Ruling memory u = reg.getRuling(s.caseJudged);
        console2.log("judged ruling result (1 = Sustained):", uint8(u.result));
        console2.log("judgment source round / round count:", u.judgment.sourceRound, u.judgment.roundCount);
        console2.log("enactment status (2 = Enacted):", uint8(reg.getEnactment(s.caseJudged, escrow.EFFECT_REFUND()).status));
    }

    // ------------------------------------------------------------------ helpers

    function baseClaim(ADRFServiceEscrow escrow, uint256 callId, bytes32 eventRef, bytes32 proposition, bytes32 clause, uint8 kind, T.Value supportsWhen, address respondent)
        internal view returns (T.ClaimInput memory c)
    {
        c.object = escrow.objectOf(callId);
        c.eventRef = eventRef;
        c.proposition = proposition;
        c.normRef = keccak256("service terms v1");
        c.clause = clause;
        c.obligationKind = kind;
        c.respondent = respondent;
        c.requestedEffects = new bytes32[](1);
        c.requestedEffects[0] = escrow.EFFECT_REFUND();
        c.effectOnSustained = escrow.EFFECT_REFUND();
        c.fallbackRef = escrow.DISPOSITION_STATUS_QUO();
        c.evidenceScopeHash = keccak256("evidence scope");
        c.documentHash = keccak256(abi.encode("case document", callId, proposition));
        c.decisive = 0;
        c.supportsWhen = supportsWhen;
    }

    function sub(bytes32 proposition, T.QuestionType qType, uint8 kind, bytes32 inputsHash) internal pure returns (T.SubQuestionInput memory q) {
        q.proposition = proposition;
        q.qType = qType;
        q.obligationKind = kind;
        q.inputsHash = inputsHash;
        q.dependsOn = new uint32[](0);
        q.requiredValues = new T.Value[](0);
    }

    function eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
