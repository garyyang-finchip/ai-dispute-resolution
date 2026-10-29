# Test record (v0.3)

Toolchain: Foundry 1.5.1-stable (forge, anvil, cast), solc 0.8.30, via-IR, optimizer runs 200, EVM cancun. The vendored ERC-8436 reference registry (`test/vendor/acdf`) is a test fixture compiled with the same settings; it exceeds EIP-170 by 438 bytes under these settings (its own repository compiles it with optimizer runs 1), so `foundry.toml` raises the test EVM's code size limit. Every ADRF contract is under 8,600 bytes of runtime code (`forge build --sizes`), which keeps each deployable unit within the 16,777,216-gas per-transaction cap of Sepolia's current schedule (about 1,500 gas per deployed byte); revision 2 had the dispute registry at 14,428 bytes with two externally linked libraries of 11,970 and 13,207 bytes, none of which could have been deployed under that cap.

## Sizes

| contract | runtime bytes |
|---|---|
| ADRFDisputeRegistry (router over the six modules) | 2,043 |
| ADRFBindingModule | 5,801 |
| ADRFFilingModule | 8,483 |
| ADRFResolutionModule | 7,062 |
| ADRFDecisionModule | 8,535 |
| ADRFRecordModule | 3,895 |
| ADRFOutcomeModule | 5,830 |
| ADRFPolicyRegistry | 8,540 |
| ADRFACDFBridge | 4,782 |
| ADRFServiceEscrow | 7,175 |
| AttestorQuorumRule | 2,048 |
| DuplicateSettlementVerifier | 806 |
| DeclaredVersionVerifier | 900 |

## Suite (70 tests, all passing)

Ran 6 tests for test/ADRFModules.t.sol:ADRFModulesTest
[PASS] test_constructorChecksModules() (gas: 3538944)
[PASS] test_everyInterfaceFunctionIsServed() (gas: 238407)
[PASS] test_modulesRefuseDirectCalls() (gas: 96017)
[PASS] test_noEtherAccepted() (gas: 28295)
[PASS] test_routedCallsLogUnderTheRegistryAndPassRevertsThrough() (gas: 918666)
[PASS] test_unknownSelectorReverts() (gas: 17125)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 13.78ms (3.64ms CPU time)
Ran 21 tests for test/ADRFAdmission.t.sol:ADRFAdmissionTest
[PASS] test_advisory_fullProcedureNoDisposal() (gas: 1812393)
[PASS] test_advisory_stillNeedsIdentifiableElements() (gas: 116443)
[PASS] test_binding_requiresSourceInterfaceAndDeclaredEffects() (gas: 369834)
[PASS] test_binding_revokedOrExpiredStopsNewFilings() (gas: 80558)
[PASS] test_binding_scopeKeyRestrictsTheObject() (gas: 931716)
[PASS] test_clock_downgradeToAdvisoryWhenPreAllowed() (gas: 1623267)
[PASS] test_clock_incompatibleWindowIsRefused() (gas: 122635)
[PASS] test_criteria_accountableRespondent() (gas: 919940)
[PASS] test_criteria_decidable() (gas: 517543)
[PASS] test_criteria_filingWindow() (gas: 97044)
[PASS] test_criteria_identifiableEvent() (gas: 150207)
[PASS] test_criteria_normMustBeRecognisedAndPreDeclared() (gas: 290877)
[PASS] test_effects_mustBeAuthorizedAndSubstantive() (gas: 174253)
[PASS] test_exclusivity_oneActiveBindingCasePerContestedPoint() (gas: 3223625)
[PASS] test_postDispute_acceptanceAdmits() (gas: 1700304)
[PASS] test_postDispute_bindingNeedsAnAcceptanceWindow() (gas: 769952)
[PASS] test_postDispute_withdrawAndLapse() (gas: 2350370)
[PASS] test_shape_rules() (gas: 1125940)
[PASS] test_standing_openChallengeRequiresPolicyStanding() (gas: 60481)
[PASS] test_standing_openChallengeWhenPolicyAllows() (gas: 2315735)
[PASS] test_standing_partiesAndBeneficiaries() (gas: 922256)
Suite result: ok. 21 passed; 0 failed; 0 skipped; finished in 21.77ms (11.40ms CPU time)
Ran 9 tests for test/ADRFOptimisticAndPolicy.t.sol:ADRFOptimisticAndPolicyTest
[PASS] test_interfaceIds() (gas: 20498)
[PASS] test_nonOptimisticCase_hasNoAnswerWindow() (gas: 844311)
[PASS] test_optimistic_answerContinuesTheOrdinaryProcedure() (gas: 1057198)
[PASS] test_optimistic_meritsBeforeSilence() (gas: 1027838)
[PASS] test_optimistic_silenceAdoptsTheSilenceRule() (gas: 1284939)
[PASS] test_policy_familiesAndVersions() (gas: 891637)
[PASS] test_policy_idIsTheHashOfTheSpec() (gas: 64750)
[PASS] test_policy_lookups() (gas: 115066)
[PASS] test_policy_validation() (gas: 749990)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 11.58ms (7.65ms CPU time)
Ran 7 tests for test/ADRFFormalFlow.t.sol:ADRFFormalFlowTest
[PASS] test_duplicateCharge_endToEnd() (gas: 1445562)
[PASS] test_enactmentLog_authorityAndEffects() (gas: 1377488)
[PASS] test_evidenceWindow() (gas: 850274)
[PASS] test_formal_burdenRuleOnTimeout() (gas: 994745)
[PASS] test_formal_inputsMustMatchPinnedHash() (gas: 844118)
[PASS] test_formal_notSustainedWhenVerifierSaysFalse() (gas: 1363973)
[PASS] test_leadReportOpensNothing() (gas: 40697)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 7.86ms (3.89ms CPU time)
Ran 6 tests for test/ADRFGeneralization.t.sol:ADRFGeneralizationTest
[PASS] test_actualVersion_isAFactEstablishedByEvidence_notAFilingPrerequisite() (gas: 1759244)
[PASS] test_actualVersion_noQuorum_isNoDecision_notLiability() (gas: 1695401)
[PASS] test_declaredVersionDiffersFromCommitted_isFormal() (gas: 1550938)
[PASS] test_plainServiceAccounts_noAgentIdentityRequired() (gas: 1340264)
[PASS] test_rulingScopeIsTheObject_notTheProvider() (gas: 2801284)
[PASS] test_versionVerifier_undeterminedBeforeDelivery_andForOtherPropositions() (gas: 174126)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 7.86ms (4.40ms CPU time)
Ran 10 tests for test/ADRFReview.t.sol:ADRFReviewTest
[PASS] test_dependencyTable_gatesResolutionAndPropagatesPremises() (gas: 1396223)
[PASS] test_dependencyTable_provenanceIsAUnionThatConfersNothing() (gas: 1686502)
[PASS] test_evidenced_quorumAndAttestorGuards() (gas: 1028229)
[PASS] test_reviewWindowLapse_adoptsProvisionalDecision_closureReviewLapsed() (gas: 1277382)
[PASS] test_review_decisionWindowLapses_adoptsEarlierDecision() (gas: 1336173)
[PASS] test_review_guards() (gas: 1146688)
[PASS] test_review_hardDeadline_adoptsEarlierDecision_withTimeoutClosure() (gas: 1334567)
[PASS] test_review_requireFreshDecision_vacatesTheEarlierDecision() (gas: 3823629)
[PASS] test_review_targetMustReachTheDecisive() (gas: 1220640)
[PASS] test_review_undeterminedRound_preservesTheEarlierDecision() (gas: 1405750)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 12.90ms (9.00ms CPU time)
Ran 4 tests for test/ADRFVectors.t.sol:ADRFVectorsTest
[PASS] test_identifiers() (gas: 30558)
[PASS] test_interfaceIds() (gas: 52885)
[PASS] test_keys() (gas: 42526)
[PASS] test_policyIdFollowsTheAbiEncoding() (gas: 100911)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 6.91ms (3.85ms CPU time)
Ran 7 tests for test/ADRFJudgedFlow.t.sol:ADRFJudgedFlowTest
[PASS] test_bridge_guards() (gas: 2016347)
[PASS] test_judgment_expiredWhenNeverOpened() (gas: 1170834)
[PASS] test_judgment_mustFitDecisionWindow() (gas: 71355)
[PASS] test_quality_approvedByPanel_claimNotSustained() (gas: 2223787)
[PASS] test_quality_blockedByPanel_claimSustained() (gas: 2443499)
[PASS] test_quality_finalityByAdoption_isImportedAsSuch() (gas: 2314149)
[PASS] test_quality_noDecision_keepsItsMeaning() (gas: 2213564)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 9.69ms (7.34ms CPU time)
Ran 8 test suites in 49.90ms (92.35ms CPU time): 70 tests passed, 0 failed, 0 skipped (70 total tests)

## Tools

`npm run check` rebuilds the thirteen worked examples, regenerates the vectors (interface ids from the compiled artifacts, identifiers, the policy id and its ABI encoding, keys) and validates every example against the six schemas with the manifest hashes re-checked; the vectors are unchanged by revision 3, since neither an interface nor an identifier changed. `test/ADRFVectors.t.sol` reads the same vectors and checks each value against the Solidity side. `npm run lint:erc` runs eipw (the validator of the ethereum/ERCs repository) over the ERC text in a scratch layout with stubs for the linked proposals: 0 errors.

## Anvil rehearsal of the evidence script

`anvil --code-size-limit 32768`, then `PHASE=deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close` with `forge script script/SepoliaEvidence.s.sol --broadcast --code-size-limit 32768`, warping the clock by eleven minutes between the phases that wait for a window. All seven phases broadcast successfully, rehearsed again after revision 3 with the modular registry (the deploy phase now creates the policy registry, the six modules and the dispute registry over them) and once more with the same flags as the Sepolia run (`--skip-simulation --gas-estimate-multiplier 150 --slow --disable-code-size-limit`) after the script was changed to deploy from artifacts (`vm.deployCode`), which keeps the script contract's own creation code at 34 KB: the formal case ended `Sustained` with the refund `Enacted`; the judged case opened an ERC-8436 issue, two of three jurors blocked the proposition, the Final result was imported as `FALSE` (source round 1 of 1), the claim ended `Sustained` and the refund was `Enacted`.
