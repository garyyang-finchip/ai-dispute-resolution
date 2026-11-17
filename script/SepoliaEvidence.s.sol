// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ADRFTypes as T} from "adrf/ADRFTypes.sol";
import {ADRFErrors as E} from "adrf/ADRFErrors.sol";
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
/// judged-finalize | judged-close. State is kept in deployments/<chainId>.json. Keys: PRIVATE_KEY (deployer); the
/// client, provider and three jurors are derived from it and topped up in the deploy phase.
///
/// Since revision 5 the judged phases also carry the amended-terms scenario and the pending-evidence scenario: a
/// call delivered under the first binding, the escrow moving to an amended policy (revoke, bind again), a call
/// delivered after it under amended terms; one evidenced case under each binding; on the earlier case a quorum
/// reached inside the evidence window, ruled and enacted under the revoked binding, on the later one a single
/// attestation that is pending inside the window and recorded UNDETERMINED after it. What must be refused (a filing
/// under the binding not in force at the event, borrowed terms, an early resolution, an attestation after a quorum
/// or after the window) is checked against the deployed contracts by local calls that are never broadcast; a check
/// that does not hold stops the phase before anything is sent, and the outcomes are written to the state file.
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
        bytes32 policyIdV2; bytes32 bindingIdV2; uint256 callEarlier; bytes32 caseEarlier; uint256 callLater; bytes32 caseLater;
        address client; address provider; address juror0; address juror1; address juror2;
        // outcomes of the local checks (never broadcast): the error each refused call returned
        string checkEarlierUnderAmended; string checkLaterUnderRevoked; string checkBorrowedTerms;
        string checkEarlyResolve; string checkAfterQuorum; string checkLaterPending; string checkLateAttestation;
    }

    uint64 constant MIN = 60;
    bytes32 constant TERMS_V1 = keccak256("service terms v1");
    bytes32 constant TERMS_V2 = keccak256("service terms v2");
    bytes32 constant STATEMENT_PERFORMED = keccak256("the service was actually performed");

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
        s.policyIdV2 = vm.parseJsonBytes32(j, ".policyIdV2");
        s.bindingIdV2 = vm.parseJsonBytes32(j, ".bindingIdV2");
        s.callEarlier = vm.parseJsonUint(j, ".callEarlier");
        s.caseEarlier = vm.parseJsonBytes32(j, ".caseEarlier");
        s.callLater = vm.parseJsonUint(j, ".callLater");
        s.caseLater = vm.parseJsonBytes32(j, ".caseLater");
        s.client = vm.parseJsonAddress(j, ".client");
        s.provider = vm.parseJsonAddress(j, ".provider");
        s.juror0 = vm.parseJsonAddress(j, ".juror0");
        s.juror1 = vm.parseJsonAddress(j, ".juror1");
        s.juror2 = vm.parseJsonAddress(j, ".juror2");
        s.checkEarlierUnderAmended = vm.parseJsonString(j, ".checkEarlierUnderAmended");
        s.checkLaterUnderRevoked = vm.parseJsonString(j, ".checkLaterUnderRevoked");
        s.checkBorrowedTerms = vm.parseJsonString(j, ".checkBorrowedTerms");
        s.checkEarlyResolve = vm.parseJsonString(j, ".checkEarlyResolve");
        s.checkAfterQuorum = vm.parseJsonString(j, ".checkAfterQuorum");
        s.checkLaterPending = vm.parseJsonString(j, ".checkLaterPending");
        s.checkLateAttestation = vm.parseJsonString(j, ".checkLateAttestation");
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
        vm.serializeBytes32(o, "issueJudged", s.issueJudged);
        vm.serializeBytes32(o, "policyIdV2", s.policyIdV2);
        vm.serializeBytes32(o, "bindingIdV2", s.bindingIdV2);
        vm.serializeUint(o, "callEarlier", s.callEarlier);
        vm.serializeBytes32(o, "caseEarlier", s.caseEarlier);
        vm.serializeUint(o, "callLater", s.callLater);
        vm.serializeBytes32(o, "caseLater", s.caseLater);
        vm.serializeAddress(o, "client", s.client);
        vm.serializeAddress(o, "provider", s.provider);
        vm.serializeAddress(o, "juror0", s.juror0);
        vm.serializeAddress(o, "juror1", s.juror1);
        vm.serializeAddress(o, "juror2", s.juror2);
        vm.serializeString(o, "checkEarlierUnderAmended", s.checkEarlierUnderAmended);
        vm.serializeString(o, "checkLaterUnderRevoked", s.checkLaterUnderRevoked);
        vm.serializeString(o, "checkBorrowedTerms", s.checkBorrowedTerms);
        vm.serializeString(o, "checkEarlyResolve", s.checkEarlyResolve);
        vm.serializeString(o, "checkAfterQuorum", s.checkAfterQuorum);
        vm.serializeString(o, "checkLaterPending", s.checkLaterPending);
        string memory out = vm.serializeString(o, "checkLateAttestation", s.checkLateAttestation);
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
        AttestorQuorumRule rule = AttestorQuorumRule(vm.deployCode("AttestorQuorumRule.sol:AttestorQuorumRule", abi.encode(reg)));

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
        // the policy is content-addressed: an earlier run of this script with the same deployer (and so the same
        // derived jurors) has already registered it on a live registry, and the registry refuses a second
        // registration of the same specification; the existing policy is the same policy, so it is reused
        s.acdfPolicyId = acdfPol.policyIdOf(ap);
        if (acdfPol.policyExists(s.acdfPolicyId)) {
            console2.log("ERC-8436 policy already registered by an earlier run, reused:");
            console2.logBytes32(s.acdfPolicyId);
        } else {
            s.acdfPolicyId = acdfPol.registerPolicy(ap);
        }

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

        // the amended procedure (version 2 of the family): a 2-day filing window and a 10-minute evidence window
        p.version = 2;
        p.previous = s.policyId;
        p.track.filingWindow = 2 days;
        p.track.evidenceWindow = 10 * MIN;
        p.descriptorHash = keccak256("adrf evidence run: amended policy document");
        s.policyIdV2 = pol.registerPolicy(p);

        s.bindingId = escrow.bindTo(bindingInputFor(escrow, s.policyId));

        // fund the actors: top up to what the run needs, nothing when an earlier run left enough
        topUp(client, 0.016 ether);
        topUp(provider, 0.004 ether);
        for (uint256 i = 0; i < 3; i++) topUp(jurors[i], 0.003 ether);
        vm.stopBroadcast();

        s.policies = address(pol); s.registry = address(reg); s.verifier = address(verifier);
        s.bindingModule = binding; s.filingModule = filing; s.resolutionModule = resolution; s.decisionModule = decision; s.recordModule = record; s.outcomeModule = outcome; s.versionVerifier = address(versionVerifier); s.rule = address(rule);
        s.bridge = address(bridge); s.escrow = address(escrow); s.acdfRegistry = address(acdf); s.acdfPolicies = address(acdfPol);
        s.client = client; s.provider = provider; s.juror0 = jurors[0]; s.juror1 = jurors[1]; s.juror2 = jurors[2];
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
        console2.log("judged case filed; ERC-8436 issue opened");
        console2.logBytes32(s.issueJudged);

        amendedFile(pk, s);
        save(s);
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

        amendedFinalize(pk, s);
        save(s);
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

        vm.startBroadcast(pk);
        reg.finalize(s.caseLater);
        vm.stopBroadcast();
        T.Ruling memory l = reg.getRuling(s.caseLater);
        console2.log("later case: state (4 = Final), result (3 = NoDecision):", uint8(l.state), uint8(l.result));
    }

    // ------------------------------------------------------------------ amended terms and pending evidence (revision 5)

    /// A call delivered under the first binding; the escrow moves to the amended policy (revoke, bind again); a call
    /// delivered after it under amended terms; an evidenced case under each binding. On the earlier case a quorum is
    /// reached inside the evidence window and the case is decided; on the later one a single attestation stays
    /// pending. The checks: the binding not in force at an event does not take it, terms cannot be borrowed, an early
    /// resolution of evidence still pending is refused, a quorum cannot be turned.
    function amendedFile(uint256 pk, State memory s) internal {
        ADRFServiceEscrow escrow = ADRFServiceEscrow(payable(s.escrow));
        IADRFDisputeRegistry reg = IADRFDisputeRegistry(s.registry);
        AttestorQuorumRule rule = AttestorQuorumRule(s.rule);
        uint256 clientPk = derived(pk, "client");
        uint256 providerPk = derived(pk, "provider");
        address client = vm.addr(clientPk);
        address provider = vm.addr(providerPk);
        address unrelated = address(uint160(uint256(keccak256("adrf evidence run: an unrelated account"))));

        // the earlier call: terms v1, delivered and charged while the first binding is in force
        vm.startBroadcast(clientPk);
        escrow.deposit{value: 0.002 ether}();
        s.callEarlier = escrow.openCall(provider, 0.001 ether, TERMS_V1, keccak256("model v2"), 4 hours);
        vm.stopBroadcast();
        vm.startBroadcast(providerPk);
        escrow.deliver(s.callEarlier, keccak256("model v2"));
        escrow.settle(s.callEarlier);
        vm.stopBroadcast();

        // the amendment: the escrow revokes its binding and binds the amended policy. The script runs every call
        // locally at one instant before broadcasting; on chain the amendment lands blocks after the earlier delivery
        // and the later delivery blocks after the amendment, and these local steps of one second reproduce that
        // order for the local checks below (nothing broadcast depends on them)
        vm.warp(vm.getBlockTimestamp() + 1);
        vm.startBroadcast(pk);
        escrow.revokeBinding();
        s.bindingIdV2 = escrow.bindTo(bindingInputFor(escrow, s.policyIdV2));
        vm.stopBroadcast();

        // the later call: terms v2, delivered and charged under the amended binding
        vm.warp(vm.getBlockTimestamp() + 1);
        vm.startBroadcast(clientPk);
        escrow.deposit{value: 0.002 ether}();
        s.callLater = escrow.openCall(provider, 0.001 ether, TERMS_V2, keccak256("model v2"), 4 hours);
        vm.stopBroadcast();
        vm.startBroadcast(providerPk);
        escrow.deliver(s.callLater, keccak256("model v2"));
        escrow.settle(s.callLater);
        vm.stopBroadcast();

        // each delivery under the binding in force when it was made, and under its own call's terms
        T.ClaimInput memory earlier = performanceClaim(escrow, s.callEarlier, TERMS_V1, provider);
        T.ClaimInput memory later = performanceClaim(escrow, s.callLater, TERMS_V2, provider);
        vm.startBroadcast(clientPk);
        s.caseEarlier = reg.file(s.bindingId, earlier);
        s.caseLater = reg.file(s.bindingIdV2, later);
        vm.stopBroadcast();
        s.checkEarlierUnderAmended = refused("earlier delivery filed under the amended binding", client, s.registry,
            abi.encodeCall(IADRFDisputeRegistry.file, (s.bindingIdV2, earlier)), E.ADRF_BindingNotInForce.selector, "ADRF_BindingNotInForce");
        s.checkLaterUnderRevoked = refused("later delivery filed under the revoked binding", client, s.registry,
            abi.encodeCall(IADRFDisputeRegistry.file, (s.bindingId, later)), E.ADRF_BindingNotInForce.selector, "ADRF_BindingNotInForce");
        s.checkBorrowedTerms = refused("earlier delivery filed under the amended terms", client, s.registry,
            abi.encodeCall(IADRFDisputeRegistry.file, (s.bindingId, performanceClaim(escrow, s.callEarlier, TERMS_V2, provider))),
            E.ADRF_NormNotApplicable.selector, "ADRF_NormNotApplicable");

        // the earlier case: one attestation is pending, the second makes the quorum, which nobody can turn
        vm.startBroadcast(derived(pk, "juror0"));
        rule.attest(s.panelId, s.caseEarlier, 0, T.Value.FALSE); // the service was not performed
        vm.stopBroadcast();
        s.checkEarlyResolve = refused("earlier case resolved by an unrelated account on one attestation", unrelated, s.registry,
            abi.encodeCall(IADRFDisputeRegistry.resolveEvidenced, (s.caseEarlier, uint32(0), bytes(""))), abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "evidence"), "ADRF_WindowOpen(evidence)");
        vm.startBroadcast(derived(pk, "juror1"));
        rule.attest(s.panelId, s.caseEarlier, 0, T.Value.FALSE);
        vm.stopBroadcast();
        s.checkAfterQuorum = refused("attestation after the quorum", vm.addr(derived(pk, "juror2")), s.rule,
            abi.encodeCall(AttestorQuorumRule.attest, (s.panelId, s.caseEarlier, uint32(0), T.Value.TRUE)),
            AttestorQuorumRule.Rule_QuorumReached.selector, "Rule_QuorumReached");
        vm.startBroadcast(clientPk);
        reg.resolveEvidenced(s.caseEarlier, 0, "");
        reg.decide(s.caseEarlier);
        vm.stopBroadcast();

        // the later case: a single attestation, pending while the evidence window is open
        vm.startBroadcast(derived(pk, "juror0"));
        rule.attest(s.panelId, s.caseLater, 0, T.Value.FALSE);
        vm.stopBroadcast();
        s.checkLaterPending = refused("later case resolved by an unrelated account on one attestation", unrelated, s.registry,
            abi.encodeCall(IADRFDisputeRegistry.resolveEvidenced, (s.caseLater, uint32(0), bytes(""))), abi.encodeWithSelector(E.ADRF_WindowOpen.selector, "evidence"), "ADRF_WindowOpen(evidence)");
        console2.log("earlier case (revoked binding) decided on a quorum; later case (amended binding) pending");
    }

    /// The earlier case becomes Final and the escrow, now bound under the amended policy, enacts its refund; the
    /// later case's evidence window has closed without a quorum, so a late attestation is refused and UNDETERMINED
    /// is recorded, and the burden rule decides NoDecision.
    function amendedFinalize(uint256 pk, State memory s) internal {
        ADRFServiceEscrow escrow = ADRFServiceEscrow(payable(s.escrow));
        IADRFDisputeRegistry reg = IADRFDisputeRegistry(s.registry);
        vm.startBroadcast(pk);
        reg.finalize(s.caseEarlier);
        escrow.enact(s.caseEarlier, escrow.EFFECT_REFUND());
        vm.stopBroadcast();
        s.checkLateAttestation = refused("attestation after the evidence window", vm.addr(derived(pk, "juror1")), s.rule,
            abi.encodeCall(AttestorQuorumRule.attest, (s.panelId, s.caseLater, uint32(0), T.Value.FALSE)),
            AttestorQuorumRule.Rule_WindowClosed.selector, "Rule_WindowClosed");
        vm.startBroadcast(pk);
        reg.resolveEvidenced(s.caseLater, 0, "");
        reg.decide(s.caseLater);
        vm.stopBroadcast();
        console2.log("earlier case enactment status (2 = Enacted):", uint8(reg.getEnactment(s.caseEarlier, escrow.EFFECT_REFUND()).status));
        console2.log("later case finding value (0 = UNDETERMINED):", uint8(reg.getFinding(s.caseLater, 0).value));
    }

    // ------------------------------------------------------------------ helpers

    function bindingInputFor(ADRFServiceEscrow escrow, bytes32 policyId) internal view returns (T.BindingInput memory b) {
        b.policyId = policyId;
        b.mode = T.AcceptanceMode.PRE_COMMIT;
        b.authorizedEffects = new bytes32[](2);
        b.authorizedEffects[0] = escrow.EFFECT_REFUND();
        b.authorizedEffects[1] = keccak256("adrf:effect/fee-split");
        b.executors = new address[](0);
        b.beneficiaries = new address[](0);
        b.termsHash = keccak256("adrf evidence run: binding document");
    }

    /// Claim: the service was not performed (evidenced, RESULT obligation): sustained when "performed" is FALSE.
    function performanceClaim(ADRFServiceEscrow escrow, uint256 callId, bytes32 terms, address provider)
        internal view returns (T.ClaimInput memory c)
    {
        c = baseClaim(escrow, callId, escrow.EVENT_DELIVERY(), keccak256("claim: the service was not performed"),
            keccak256("terms: the service is performed as agreed"), escrow.KIND_RESULT(), T.Value.FALSE, provider);
        c.normRef = terms;
        c.subQuestions = new T.SubQuestionInput[](1);
        c.subQuestions[0] = sub(STATEMENT_PERFORMED, T.QuestionType.EVIDENCED, escrow.KIND_RESULT(), bytes32(0));
    }

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

    function topUp(address who, uint256 target) internal {
        if (who.balance < target) payable(who).transfer(target - who.balance);
    }

    /// A local call, never broadcast, made as `who` against the deployed contracts: it must revert with the error
    /// `expected`, or the phase stops before anything is sent. Returns the outcome for the state file.
    function refused(string memory label, address who, address target, bytes memory data, bytes4 expected, string memory name)
        internal returns (string memory outcome)
    {
        vm.prank(who);
        (bool ok, bytes memory ret) = target.call(data);
        require(!ok && ret.length >= 4 && bytes4(ret) == expected, string.concat("check failed: ", label));
        outcome = string.concat("refused: ", name);
        console2.log(string.concat(label, " -> ", outcome));
    }

    /// The same check against the complete revert data, for an error shared by several conditions.
    function refused(string memory label, address who, address target, bytes memory data, bytes memory expected, string memory name)
        internal returns (string memory outcome)
    {
        vm.prank(who);
        (bool ok, bytes memory ret) = target.call(data);
        require(!ok && keccak256(ret) == keccak256(expected), string.concat("check failed: ", label));
        outcome = string.concat("refused: ", name);
        console2.log(string.concat(label, " -> ", outcome));
    }
}
