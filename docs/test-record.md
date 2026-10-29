# Test record (v0.4)

Toolchain: Foundry 1.5.1-stable (forge, anvil, cast), solc 0.8.30, via-IR, optimizer runs 200, EVM cancun. The vendored ERC-8436 reference registry (`test/vendor/acdf`) is a test fixture compiled with the same settings; it exceeds EIP-170 by 438 bytes under these settings (its own repository compiles it with optimizer runs 1), so `foundry.toml` raises the test EVM's code size limit. Every ADRF contract is under 9,300 bytes of runtime code (`forge build --sizes`; the kernel under 8,800, the worked-example escrow at 9,209 now that it keeps a settlement ledger), which keeps each deployable unit within the 16,777,216-gas per-transaction cap of Sepolia's current schedule (1,571 to 1,804 gas per deployed byte as measured by the revision-3 run: the escrow at about 88% of the cap, the largest kernel units at about 82%); revision 2 had the dispute registry at 14,428 bytes with two externally linked libraries of 11,970 and 13,207 bytes, none of which could have been deployed under that cap. Revision 4 changed the bytecode of four deployable units — `ADRFBindingModule` (the source interface identifier it checks), `ADRFFilingModule`, `DuplicateSettlementVerifier` and `ADRFServiceEscrow` — and left the other nine identical to revision 3.

## Sizes

| contract | runtime bytes |
|---|---|
| ADRFDisputeRegistry (router over the six modules) | 2,043 |
| ADRFBindingModule | 5,801 |
| ADRFFilingModule | 8,784 |
| ADRFResolutionModule | 7,062 |
| ADRFDecisionModule | 8,535 |
| ADRFRecordModule | 3,895 |
| ADRFOutcomeModule | 5,830 |
| ADRFPolicyRegistry | 8,540 |
| ADRFACDFBridge | 4,782 |
| ADRFServiceEscrow | 9,209 |
| AttestorQuorumRule | 2,048 |
| DuplicateSettlementVerifier | 903 |
| DeclaredVersionVerifier | 900 |

## Suite (79 tests, all passing)

Ran 6 tests for test/ADRFModules.t.sol:ADRFModulesTest
[PASS] test_constructorChecksModules() (gas: 3538944)
[PASS] test_everyInterfaceFunctionIsServed() (gas: 238407)
[PASS] test_modulesRefuseDirectCalls() (gas: 96393)
[PASS] test_noEtherAccepted() (gas: 28295)
[PASS] test_routedCallsLogUnderTheRegistryAndPassRevertsThrough() (gas: 930612)
[PASS] test_unknownSelectorReverts() (gas: 17125)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 13.29ms (2.64ms CPU time)
Ran 9 tests for test/ADRFOptimisticAndPolicy.t.sol:ADRFOptimisticAndPolicyTest
[PASS] test_interfaceIds() (gas: 20498)
[PASS] test_nonOptimisticCase_hasNoAnswerWindow() (gas: 854767)
[PASS] test_optimistic_answerContinuesTheOrdinaryProcedure() (gas: 1067317)
[PASS] test_optimistic_meritsBeforeSilence() (gas: 1037965)
[PASS] test_optimistic_silenceAdoptsTheSilenceRule() (gas: 1296333)
[PASS] test_policy_familiesAndVersions() (gas: 891637)
[PASS] test_policy_idIsTheHashOfTheSpec() (gas: 64750)
[PASS] test_policy_lookups() (gas: 115066)
[PASS] test_policy_validation() (gas: 749990)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 7.68ms (4.28ms CPU time)
Ran 21 tests for test/ADRFAdmission.t.sol:ADRFAdmissionTest
[PASS] test_advisory_fullProcedureNoDisposal() (gas: 1821408)
[PASS] test_advisory_stillNeedsIdentifiableElements() (gas: 116688)
[PASS] test_binding_requiresSourceInterfaceAndDeclaredEffects() (gas: 369834)
[PASS] test_binding_revokedOrExpiredStopsNewFilings() (gas: 80909)
[PASS] test_binding_scopeKeyRestrictsTheObject() (gas: 1047851)
[PASS] test_clock_downgradeToAdvisoryWhenPreAllowed() (gas: 1741490)
[PASS] test_clock_incompatibleWindowIsRefused() (gas: 127151)
[PASS] test_criteria_accountableRespondent() (gas: 928236)
[PASS] test_criteria_decidable() (gas: 521927)
[PASS] test_criteria_filingWindow() (gas: 101217)
[PASS] test_criteria_identifiableEvent() (gas: 151173)
[PASS] test_criteria_normMustBeRecognisedAndPreDeclared() (gas: 293265)
[PASS] test_effects_mustBeAuthorizedAndSubstantive() (gas: 182757)
[PASS] test_exclusivity_oneActiveBindingCasePerContestedPoint() (gas: 3898259)
[PASS] test_postDispute_acceptanceAdmits() (gas: 1818521)
[PASS] test_postDispute_bindingNeedsAnAcceptanceWindow() (gas: 769952)
[PASS] test_postDispute_withdrawAndLapse() (gas: 2470787)
[PASS] test_shape_rules() (gas: 1131787)
[PASS] test_standing_openChallengeRequiresPolicyStanding() (gas: 60481)
[PASS] test_standing_openChallengeWhenPolicyAllows() (gas: 2433732)
[PASS] test_standing_partiesAndBeneficiaries() (gas: 931017)
Suite result: ok. 21 passed; 0 failed; 0 skipped; finished in 21.67ms (10.85ms CPU time)
Ran 7 tests for test/ADRFFormalFlow.t.sol:ADRFFormalFlowTest
[PASS] test_duplicateCharge_endToEnd() (gas: 1468634)
[PASS] test_enactmentLog_authorityAndEffects() (gas: 1386380)
[PASS] test_evidenceWindow() (gas: 860877)
[PASS] test_formal_burdenRuleOnTimeout() (gas: 1005394)
[PASS] test_formal_inputsMustMatchPinnedHash() (gas: 854721)
[PASS] test_formal_notSustainedWhenVerifierSaysFalse() (gas: 2299385)
[PASS] test_leadReportOpensNothing() (gas: 46633)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 5.94ms (3.24ms CPU time)
Ran 9 tests for test/ADRFRecognition.t.sol:ADRFRecognitionTest
[PASS] test_deliveryClaim_refundsTheHeldCharge() (gas: 1397010)
[PASS] test_eachSettlementBeyondTheFirst_isItsOwnCase() (gas: 3342695)
[PASS] test_exclusivity_isOnTheDecisiveProposition_notTheWording() (gas: 1514982)
[PASS] test_invertedDirection_isRefused() (gas: 98178)
[PASS] test_lateExecutor_reportsFailed() (gas: 1329968)
[PASS] test_recognitionIsTheSourcesStatement() (gas: 1825569)
[PASS] test_settlementsAreHeld_untilTheAttestedDeadline() (gas: 1384454)
[PASS] test_triviallyTrueDecisiveQuestion_isRefused() (gas: 911307)
[PASS] test_unrecognisedProposition_andWrongKind_areRefused() (gas: 1155862)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 8.17ms (5.48ms CPU time)
Ran 6 tests for test/ADRFGeneralization.t.sol:ADRFGeneralizationTest
[PASS] test_actualVersion_isAFactEstablishedByEvidence_notAFilingPrerequisite() (gas: 1781626)
[PASS] test_actualVersion_noQuorum_isNoDecision_notLiability() (gas: 1717783)
[PASS] test_declaredVersionDiffersFromCommitted_isFormal() (gas: 1573560)
[PASS] test_plainServiceAccounts_noAgentIdentityRequired() (gas: 1348417)
[PASS] test_rulingScopeIsTheObject_notTheProvider() (gas: 2851284)
[PASS] test_versionVerifier_undeterminedBeforeDelivery_andForOtherPropositions() (gas: 171746)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 6.61ms (3.54ms CPU time)
Ran 10 tests for test/ADRFReview.t.sol:ADRFReviewTest
[PASS] test_dependencyTable_gatesResolutionAndPropagatesPremises() (gas: 1402525)
[PASS] test_dependencyTable_provenanceIsAUnionThatConfersNothing() (gas: 1693095)
[PASS] test_evidenced_quorumAndAttestorGuards() (gas: 1036141)
[PASS] test_reviewWindowLapse_adoptsProvisionalDecision_closureReviewLapsed() (gas: 1285294)
[PASS] test_review_decisionWindowLapses_adoptsEarlierDecision() (gas: 1344085)
[PASS] test_review_guards() (gas: 1154600)
[PASS] test_review_hardDeadline_adoptsEarlierDecision_withTimeoutClosure() (gas: 1342479)
[PASS] test_review_requireFreshDecision_vacatesTheEarlierDecision() (gas: 4236013)
[PASS] test_review_targetMustReachTheDecisive() (gas: 1228638)
[PASS] test_review_undeterminedRound_preservesTheEarlierDecision() (gas: 1413662)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 9.68ms (6.78ms CPU time)
Ran 7 tests for test/ADRFJudgedFlow.t.sol:ADRFJudgedFlowTest
[PASS] test_bridge_guards() (gas: 2024233)
[PASS] test_judgment_expiredWhenNeverOpened() (gas: 1184312)
[PASS] test_judgment_mustFitDecisionWindow() (gas: 71355)
[PASS] test_quality_approvedByPanel_claimNotSustained() (gas: 2231673)
[PASS] test_quality_blockedByPanel_claimSustained() (gas: 2453761)
[PASS] test_quality_finalityByAdoption_isImportedAsSuch() (gas: 2322035)
[PASS] test_quality_noDecision_keepsItsMeaning() (gas: 2221494)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 8.75ms (5.45ms CPU time)
Ran 4 tests for test/ADRFVectors.t.sol:ADRFVectorsTest
[PASS] test_identifiers() (gas: 30558)
[PASS] test_interfaceIds() (gas: 52885)
[PASS] test_keys() (gas: 42922)
[PASS] test_policyIdFollowsTheAbiEncoding() (gas: 100911)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 5.74ms (4.00ms CPU time)
Ran 9 test suites in 51.54ms (87.53ms CPU time): 79 tests passed, 0 failed, 0 skipped (79 total tests)

## Tools

`npm run check` rebuilds the thirteen worked examples, regenerates the vectors (interface ids from the compiled artifacts, identifiers, the policy id and its ABI encoding, keys) and validates every example against the six schemas with the manifest hashes re-checked; revision 4 changed the interface identifier of `IADRFObligationSource` (`0xa52f2870`, `recognizesBreach` added), the keys vector (the proposition is now the decisive sub-question's: the duplicate-settlement statement for settlement 2 of call 17) and the worked examples (the binding lists the breaches the escrow recognizes, the duplicate-charge case names settlement 2 as its event and the verifier's proposition for it). `test/ADRFVectors.t.sol` reads the same vectors and checks each value against the Solidity side. `npm run lint:erc` runs eipw (the validator of the ethereum/ERCs repository) over the ERC text in a scratch layout with stubs for the linked proposals: 0 errors.

## Anvil rehearsal of the evidence script

`anvil --code-size-limit 32768`, then `PHASE=deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close` with `forge script script/SepoliaEvidence.s.sol --broadcast --code-size-limit 32768`, warping the clock by eleven minutes between the phases that wait for a window. All seven phases broadcast successfully, rehearsed again after revision 3 with the modular registry (the deploy phase now creates the policy registry, the six modules and the dispute registry over them) and once more with the same flags as the Sepolia run (`--skip-simulation --gas-estimate-multiplier 150 --slow --code-size-limit 65536`), under Foundry 1.5.1 and 1.7.1, after the script was changed to deploy from artifacts (`vm.deployCode`), which keeps the script contract's own creation code at 34 KB: the formal case ended `Sustained` with the refund `Enacted`; the judged case opened an ERC-8436 issue, two of three jurors blocked the proposition, the Final result was imported as `FALSE` (source round 1 of 1), the claim ended `Sustained` and the refund was `Enacted`. Rehearsed once more after revision 4 with the same Sepolia flags (48 transactions on Anvil, where the vendored ERC-8436 registry and its policy registry are deployed as well): the formal claim now names settlement 2 as its event and the verifier's proposition for that ordinal, and both refunds were `Enacted` from the held settlements; rehearsed once more with the deploy phase run twice against one ERC-8436 registry, the second time reusing the fast-track policy the first had registered (the live registry refuses a second registration of the same specification), through all seven phases.
