# Test record (v0.1)

Toolchain: Foundry 1.5.1-stable (forge, anvil, cast), solc 0.8.30, via-IR, optimizer runs 200, EVM cancun. The vendored ERC-8436 reference registry (`test/vendor/acdf`) is a test fixture compiled with the same settings; it exceeds EIP-170 by 438 bytes under these settings (its own repository compiles it with optimizer runs 1), so `foundry.toml` raises the test EVM's code size limit. Every ADRF contract is under the limit (`forge build --sizes`).

## Sizes

| contract | runtime bytes |
|---|---|
| ADRFDisputeRegistry | 14,386 |
| ADRFAdmission (external library) | 11,959 |
| ADRFLifecycle (external library) | 13,207 |
| ADRFPolicyRegistry | 8,540 |
| ADRFACDFBridge | 4,782 |
| ADRFServiceEscrow | 6,923 |
| AttestorQuorumRule | 2,048 |
| DuplicateSettlementVerifier | 806 |

## Suite (58 tests, all passing)

Ran 9 tests for test/ADRFOptimisticAndPolicy.t.sol:ADRFOptimisticAndPolicyTest
[PASS] test_interfaceIds() (gas: 20977)
[PASS] test_nonOptimisticCase_hasNoAnswerWindow() (gas: 841784)
[PASS] test_optimistic_answerContinuesTheOrdinaryProcedure() (gas: 1038296)
[PASS] test_optimistic_meritsBeforeSilence() (gas: 1014903)
[PASS] test_optimistic_silenceAdoptsTheSilenceRule() (gas: 1261152)
[PASS] test_policy_familiesAndVersions() (gas: 812247)
[PASS] test_policy_idIsTheHashOfTheSpec() (gas: 60029)
[PASS] test_policy_lookups() (gas: 98980)
[PASS] test_policy_validation() (gas: 656221)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 16.32ms (8.66ms CPU time)
Ran 21 tests for test/ADRFAdmission.t.sol:ADRFAdmissionTest
[PASS] test_advisory_fullProcedureNoDisposal() (gas: 1792689)
[PASS] test_advisory_stillNeedsIdentifiableElements() (gas: 123378)
[PASS] test_binding_requiresSourceInterfaceAndDeclaredEffects() (gas: 373965)
[PASS] test_binding_revokedOrExpiredStopsNewFilings() (gas: 78275)
[PASS] test_binding_scopeKeyRestrictsTheObject() (gas: 927206)
[PASS] test_clock_downgradeToAdvisoryWhenPreAllowed() (gas: 1614456)
[PASS] test_clock_incompatibleWindowIsRefused() (gas: 122905)
[PASS] test_criteria_accountableRespondent() (gas: 918836)
[PASS] test_criteria_decidable() (gas: 513192)
[PASS] test_criteria_filingWindow() (gas: 97246)
[PASS] test_criteria_identifiableEvent() (gas: 152637)
[PASS] test_criteria_normMustBeRecognisedAndPreDeclared() (gas: 299940)
[PASS] test_effects_mustBeAuthorizedAndSubstantive() (gas: 176997)
[PASS] test_exclusivity_oneActiveBindingCasePerContestedPoint() (gas: 3214451)
[PASS] test_postDispute_acceptanceAdmits() (gas: 1690675)
[PASS] test_postDispute_bindingNeedsAnAcceptanceWindow() (gas: 713658)
[PASS] test_postDispute_withdrawAndLapse() (gas: 2332331)
[PASS] test_shape_rules() (gas: 1145815)
[PASS] test_standing_openChallengeRequiresPolicyStanding() (gas: 61884)
[PASS] test_standing_openChallengeWhenPolicyAllows() (gas: 2251288)
[PASS] test_standing_partiesAndBeneficiaries() (gas: 918449)
Suite result: ok. 21 passed; 0 failed; 0 skipped; finished in 16.93ms (9.19ms CPU time)
Ran 7 tests for test/ADRFFormalFlow.t.sol:ADRFFormalFlowTest
[PASS] test_duplicateCharge_endToEnd() (gas: 1402615)
[PASS] test_enactmentLog_authorityAndEffects() (gas: 1341252)
[PASS] test_evidenceWindow() (gas: 842599)
[PASS] test_formal_burdenRuleOnTimeout() (gas: 985232)
[PASS] test_formal_inputsMustMatchPinnedHash() (gas: 842565)
[PASS] test_formal_notSustainedWhenVerifierSaysFalse() (gas: 1322832)
[PASS] test_leadReportOpensNothing() (gas: 31106)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 5.06ms (2.50ms CPU time)
Ran 10 tests for test/ADRFReview.t.sol:ADRFReviewTest
[PASS] test_dependencyTable_gatesResolutionAndPropagatesPremises() (gas: 1388599)
[PASS] test_dependencyTable_provenanceIsAUnionThatConfersNothing() (gas: 1672603)
[PASS] test_evidenced_quorumAndAttestorGuards() (gas: 1023121)
[PASS] test_reviewWindowLapse_adoptsProvisionalDecision_closureReviewLapsed() (gas: 1261707)
[PASS] test_review_decisionWindowLapses_adoptsEarlierDecision() (gas: 1318143)
[PASS] test_review_guards() (gas: 1134601)
[PASS] test_review_hardDeadline_adoptsEarlierDecision_withTimeoutClosure() (gas: 1315625)
[PASS] test_review_requireFreshDecision_vacatesTheEarlierDecision() (gas: 3662499)
[PASS] test_review_targetMustReachTheDecisive() (gas: 1218530)
[PASS] test_review_undeterminedRound_preservesTheEarlierDecision() (gas: 1380993)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 13.11ms (8.75ms CPU time)
Ran 7 tests for test/ADRFJudgedFlow.t.sol:ADRFJudgedFlowTest
[PASS] test_bridge_guards() (gas: 2009585)
[PASS] test_judgment_expiredWhenNeverOpened() (gas: 1159196)
[PASS] test_judgment_mustFitDecisionWindow() (gas: 66513)
[PASS] test_quality_approvedByPanel_claimNotSustained() (gas: 2210366)
[PASS] test_quality_blockedByPanel_claimSustained() (gas: 2420711)
[PASS] test_quality_finalityByAdoption_isImportedAsSuch() (gas: 2300756)
[PASS] test_quality_noDecision_keepsItsMeaning() (gas: 2191755)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 7.70ms (4.86ms CPU time)
Ran 4 tests for test/ADRFVectors.t.sol:ADRFVectorsTest
[PASS] test_identifiers() (gas: 30558)
[PASS] test_interfaceIds() (gas: 52890)
[PASS] test_keys() (gas: 37020)
[PASS] test_policyIdFollowsTheAbiEncoding() (gas: 100933)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 6.50ms (4.80ms CPU time)
Ran 6 test suites in 39.53ms (65.63ms CPU time): 58 tests passed, 0 failed, 0 skipped (58 total tests)

## Tools

`npm run check` rebuilds the nine worked examples, regenerates the vectors (interface ids from the compiled artifacts, identifiers, the policy id and its ABI encoding, keys) and validates every example against the six schemas with the manifest hashes re-checked. `test/ADRFVectors.t.sol` reads the same vectors and checks each value against the Solidity side. `npm run lint:erc` runs eipw (the validator of the ethereum/ERCs repository) over the ERC text in a scratch layout with stubs for the linked proposals: 0 errors.

## Anvil rehearsal of the evidence script

`anvil --code-size-limit 32768`, then `PHASE=deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close` with `forge script script/SepoliaEvidence.s.sol --broadcast --code-size-limit 32768`, warping the clock by eleven minutes between the phases that wait for a window. All seven phases broadcast successfully: the formal case ended `Sustained` with the refund `Enacted`; the judged case opened an ERC-8436 issue, two of three jurors blocked the proposition, the Final result was imported as `FALSE` (source round 1 of 1), the claim ended `Sustained` and the refund was `Enacted`.
