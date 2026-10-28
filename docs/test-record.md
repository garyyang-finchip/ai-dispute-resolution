# Test record (v0.2)

Toolchain: Foundry 1.5.1-stable (forge, anvil, cast), solc 0.8.30, via-IR, optimizer runs 200, EVM cancun. The vendored ERC-8436 reference registry (`test/vendor/acdf`) is a test fixture compiled with the same settings; it exceeds EIP-170 by 438 bytes under these settings (its own repository compiles it with optimizer runs 1), so `foundry.toml` raises the test EVM's code size limit. Every ADRF contract is under the limit (`forge build --sizes`).

## Sizes

| contract | runtime bytes |
|---|---|
| ADRFDisputeRegistry | 14,428 |
| ADRFAdmission (external library) | 11,970 |
| ADRFLifecycle (external library) | 13,207 |
| ADRFPolicyRegistry | 8,540 |
| ADRFACDFBridge | 4,782 |
| ADRFServiceEscrow | 7,175 |
| AttestorQuorumRule | 2,048 |
| DuplicateSettlementVerifier | 806 |
| DeclaredVersionVerifier | 900 |

## Suite (64 tests, all passing)

Ran 7 tests for test/ADRFJudgedFlow.t.sol:ADRFJudgedFlowTest
[PASS] test_bridge_guards() (gas: 2014375)
[PASS] test_judgment_expiredWhenNeverOpened() (gas: 1164564)
[PASS] test_judgment_mustFitDecisionWindow() (gas: 71355)
[PASS] test_quality_approvedByPanel_claimNotSustained() (gas: 2215157)
[PASS] test_quality_blockedByPanel_claimSustained() (gas: 2425673)
[PASS] test_quality_finalityByAdoption_isImportedAsSuch() (gas: 2305520)
[PASS] test_quality_noDecision_keepsItsMeaning() (gas: 2196743)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 7.63ms (4.81ms CPU time)
Ran 9 tests for test/ADRFOptimisticAndPolicy.t.sol:ADRFOptimisticAndPolicyTest
[PASS] test_interfaceIds() (gas: 20977)
[PASS] test_nonOptimisticCase_hasNoAnswerWindow() (gas: 846407)
[PASS] test_optimistic_answerContinuesTheOrdinaryProcedure() (gas: 1045143)
[PASS] test_optimistic_meritsBeforeSilence() (gas: 1021750)
[PASS] test_optimistic_silenceAdoptsTheSilenceRule() (gas: 1268426)
[PASS] test_policy_familiesAndVersions() (gas: 891637)
[PASS] test_policy_idIsTheHashOfTheSpec() (gas: 64750)
[PASS] test_policy_lookups() (gas: 115066)
[PASS] test_policy_validation() (gas: 749990)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 6.79ms (4.01ms CPU time)
Ran 21 tests for test/ADRFAdmission.t.sol:ADRFAdmissionTest
[PASS] test_advisory_fullProcedureNoDisposal() (gas: 1800448)
[PASS] test_advisory_stillNeedsIdentifiableElements() (gas: 125645)
[PASS] test_binding_requiresSourceInterfaceAndDeclaredEffects() (gas: 373965)
[PASS] test_binding_revokedOrExpiredStopsNewFilings() (gas: 80495)
[PASS] test_binding_scopeKeyRestrictsTheObject() (gas: 929445)
[PASS] test_clock_downgradeToAdvisoryWhenPreAllowed() (gas: 1619299)
[PASS] test_clock_incompatibleWindowIsRefused() (gas: 125125)
[PASS] test_criteria_accountableRespondent() (gas: 923401)
[PASS] test_criteria_decidable() (gas: 520144)
[PASS] test_criteria_filingWindow() (gas: 99466)
[PASS] test_criteria_identifiableEvent() (gas: 155077)
[PASS] test_criteria_normMustBeRecognisedAndPreDeclared() (gas: 303052)
[PASS] test_effects_mustBeAuthorizedAndSubstantive() (gas: 179180)
[PASS] test_exclusivity_oneActiveBindingCasePerContestedPoint() (gas: 3226656)
[PASS] test_postDispute_acceptanceAdmits() (gas: 1695519)
[PASS] test_postDispute_bindingNeedsAnAcceptanceWindow() (gas: 771330)
[PASS] test_postDispute_withdrawAndLapse() (gas: 2339608)
[PASS] test_shape_rules() (gas: 1151539)
[PASS] test_standing_openChallengeRequiresPolicyStanding() (gas: 61884)
[PASS] test_standing_openChallengeWhenPolicyAllows() (gas: 2313645)
[PASS] test_standing_partiesAndBeneficiaries() (gas: 923308)
Suite result: ok. 21 passed; 0 failed; 0 skipped; finished in 20.65ms (12.44ms CPU time)
Ran 10 tests for test/ADRFReview.t.sol:ADRFReviewTest
[PASS] test_dependencyTable_gatesResolutionAndPropagatesPremises() (gas: 1393241)
[PASS] test_dependencyTable_provenanceIsAUnionThatConfersNothing() (gas: 1677492)
[PASS] test_evidenced_quorumAndAttestorGuards() (gas: 1027741)
[PASS] test_reviewWindowLapse_adoptsProvisionalDecision_closureReviewLapsed() (gas: 1266552)
[PASS] test_review_decisionWindowLapses_adoptsEarlierDecision() (gas: 1323214)
[PASS] test_review_guards() (gas: 1139534)
[PASS] test_review_hardDeadline_adoptsEarlierDecision_withTimeoutClosure() (gas: 1320696)
[PASS] test_review_requireFreshDecision_vacatesTheEarlierDecision() (gas: 3821086)
[PASS] test_review_targetMustReachTheDecisive() (gas: 1223176)
[PASS] test_review_undeterminedRound_preservesTheEarlierDecision() (gas: 1386271)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 7.84ms (5.54ms CPU time)
Ran 4 tests for test/ADRFVectors.t.sol:ADRFVectorsTest
[PASS] test_identifiers() (gas: 30558)
[PASS] test_interfaceIds() (gas: 52890)
[PASS] test_keys() (gas: 37042)
[PASS] test_policyIdFollowsTheAbiEncoding() (gas: 100911)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 3.96ms (1.57ms CPU time)
Ran 7 tests for test/ADRFFormalFlow.t.sol:ADRFFormalFlowTest
[PASS] test_duplicateCharge_endToEnd() (gas: 1408566)
[PASS] test_enactmentLog_authorityAndEffects() (gas: 1345894)
[PASS] test_evidenceWindow() (gas: 847222)
[PASS] test_formal_burdenRuleOnTimeout() (gas: 989874)
[PASS] test_formal_inputsMustMatchPinnedHash() (gas: 847210)
[PASS] test_formal_notSustainedWhenVerifierSaysFalse() (gas: 1352800)
[PASS] test_leadReportOpensNothing() (gas: 33293)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 7.82ms (3.87ms CPU time)
Ran 6 tests for test/ADRFGeneralization.t.sol:ADRFGeneralizationTest
[PASS] test_actualVersion_isAFactEstablishedByEvidence_notAFilingPrerequisite() (gas: 1747960)
[PASS] test_actualVersion_noQuorum_isNoDecision_notLiability() (gas: 1692000)
[PASS] test_declaredVersionDiffersFromCommitted_isFormal() (gas: 1545020)
[PASS] test_plainServiceAccounts_noAgentIdentityRequired() (gas: 1325540)
[PASS] test_rulingScopeIsTheObject_notTheProvider() (gas: 2795627)
[PASS] test_versionVerifier_undeterminedBeforeDelivery_andForOtherPropositions() (gas: 174126)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 4.42ms (3.80ms CPU time)
Ran 7 test suites in 32.00ms (59.12ms CPU time): 64 tests passed, 0 failed, 0 skipped (64 total tests)

## Tools

`npm run check` rebuilds the thirteen worked examples, regenerates the vectors (interface ids from the compiled artifacts, identifiers, the policy id and its ABI encoding, keys) and validates every example against the six schemas with the manifest hashes re-checked. `test/ADRFVectors.t.sol` reads the same vectors and checks each value against the Solidity side. `npm run lint:erc` runs eipw (the validator of the ethereum/ERCs repository) over the ERC text in a scratch layout with stubs for the linked proposals: 0 errors.

## Anvil rehearsal of the evidence script

`anvil --code-size-limit 32768`, then `PHASE=deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close` with `forge script script/SepoliaEvidence.s.sol --broadcast --code-size-limit 32768`, warping the clock by eleven minutes between the phases that wait for a window. All seven phases broadcast successfully (rehearsed again after revision 2 with the version-aware escrow): the formal case ended `Sustained` with the refund `Enacted`; the judged case opened an ERC-8436 issue, two of three jurors blocked the proposition, the Final result was imported as `FALSE` (source round 1 of 1), the claim ended `Sustained` and the refund was `Enacted`.
