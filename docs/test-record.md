# Test record (v0.5)

Toolchain: Foundry 1.5.1-stable and 1.7.1 (forge, anvil, cast), solc 0.8.30, via-IR, optimizer runs 200, EVM cancun; the suite below is the 1.5.1 run, and the same 105 tests pass under 1.7.1 with no command-line flag. The vendored ERC-8436 reference registry (`test/vendor/acdf`) is a test fixture compiled with the same settings; it exceeds EIP-170 by 438 bytes under these settings (its own repository compiles it with optimizer runs 1). The test contracts embed the creation code of every contract they deploy (about 150 KB each) and Foundry 1.7 holds test and script contracts to the local code size limit and the initcode limit derived from it, so `foundry.toml` sets that limit to 262,144 bytes (revision 5; before it, `forge test` under 1.7 failed in every `setUp` with "create initcode size limit" unless `--code-size-limit` was passed, as the contributor of the amended-terms tests reported). Nothing deployed to a network depends on it. Every ADRF contract is under 9,200 bytes of runtime code (`forge build --sizes`; the largest are the worked-example escrow at 9,163 and the filing module at 9,033), which keeps each deployable unit within the 16,777,216-gas per-transaction cap of Sepolia's current schedule (1,570 to 1,804 gas per deployed byte as measured by the earlier runs: about 87% of the cap for the two largest). Revision 5 changed the bytecode of five deployable units — `ADRFBindingModule` (the revocation instant), `ADRFFilingModule` (the binding in force at the event), `ADRFResolutionModule` (the pending rule), `AttestorQuorumRule` (registry-bound, strict majority, per-round tallies inside the window, rounds closed at quorum) and `ADRFServiceEscrow` (enactment under any of its bindings) — and left the other eight identical to revision 4.

## Sizes

| contract | runtime bytes |
|---|---|
| ADRFDisputeRegistry (router over the six modules) | 2,043 |
| ADRFBindingModule | 5,943 |
| ADRFFilingModule | 9,033 |
| ADRFResolutionModule | 7,191 |
| ADRFDecisionModule | 8,535 |
| ADRFRecordModule | 3,895 |
| ADRFOutcomeModule | 5,830 |
| ADRFPolicyRegistry | 8,540 |
| ADRFACDFBridge | 4,782 |
| ADRFServiceEscrow | 9,163 |
| AttestorQuorumRule | 3,940 |
| DuplicateSettlementVerifier | 903 |
| DeclaredVersionVerifier | 900 |

## Suite (105 tests, all passing)

Ran 7 tests for test/ADRFNormRevisions.t.sol:ADRFNormRevisionsTest
[PASS] test_amendmentCannotRefreshOldFilingWindow() (gas: 112743)
[PASS] test_amendmentDoesNotChangeAnAdmittedCaseOrItsDecision() (gas: 1309068)
[PASS] test_amendmentDoesNotCreateAnotherSlotForSameEvent() (gas: 1467141)
[PASS] test_latestNormCannotBeSubstitutedForOldEvent() (gas: 889788)
[PASS] test_newEventUsesNewNormAndCannotBorrowOldNorm() (gas: 1733566)
[PASS] test_objectVersionCannotBeReplacedWhileRetainingOldEvent() (gas: 98504)
[PASS] test_oldEventStillAdmittedUnderOriginalNormAfterAmendment() (gas: 859066)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 17.23ms (3.86ms CPU time)

Ran 9 tests for test/ADRFOptimisticAndPolicy.t.sol:ADRFOptimisticAndPolicyTest
[PASS] test_interfaceIds() (gas: 20498)
[PASS] test_nonOptimisticCase_hasNoAnswerWindow() (gas: 855211)
[PASS] test_optimistic_answerContinuesTheOrdinaryProcedure() (gas: 1067881)
[PASS] test_optimistic_meritsBeforeSilence() (gas: 1038529)
[PASS] test_optimistic_silenceAdoptsTheSilenceRule() (gas: 1296706)
[PASS] test_policy_familiesAndVersions() (gas: 891637)
[PASS] test_policy_idIsTheHashOfTheSpec() (gas: 64750)
[PASS] test_policy_lookups() (gas: 115066)
[PASS] test_policy_validation() (gas: 749990)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 8.44ms (4.84ms CPU time)

Ran 22 tests for test/ADRFAdmission.t.sol:ADRFAdmissionTest
[PASS] test_advisory_fullProcedureNoDisposal() (gas: 1821988)
[PASS] test_advisory_stillNeedsIdentifiableElements() (gas: 116688)
[PASS] test_binding_doesNotReachBack_andValidUntilEndsItsPeriod() (gas: 3644881)
[PASS] test_binding_requiresSourceInterfaceAndDeclaredEffects() (gas: 369856)
[PASS] test_binding_revocationEndsItForLaterEventsOnly() (gas: 1705074)
[PASS] test_binding_scopeKeyRestrictsTheObject() (gas: 1047853)
[PASS] test_clock_downgradeToAdvisoryWhenPreAllowed() (gas: 1741956)
[PASS] test_clock_incompatibleWindowIsRefused() (gas: 127617)
[PASS] test_criteria_accountableRespondent() (gas: 929148)
[PASS] test_criteria_decidable() (gas: 522393)
[PASS] test_criteria_filingWindow() (gas: 101717)
[PASS] test_criteria_identifiableEvent() (gas: 151155)
[PASS] test_criteria_normMustBeRecognisedAndPreDeclared() (gas: 295507)
[PASS] test_effects_mustBeAuthorizedAndSubstantive() (gas: 183667)
[PASS] test_exclusivity_oneActiveBindingCasePerContestedPoint() (gas: 3900621)
[PASS] test_postDispute_acceptanceAdmits() (gas: 1818912)
[PASS] test_postDispute_bindingNeedsAnAcceptanceWindow() (gas: 769996)
[PASS] test_postDispute_withdrawAndLapse() (gas: 2471143)
[PASS] test_shape_rules() (gas: 1132071)
[PASS] test_standing_openChallengeRequiresPolicyStanding() (gas: 60503)
[PASS] test_standing_openChallengeWhenPolicyAllows() (gas: 2434198)
[PASS] test_standing_partiesAndBeneficiaries() (gas: 931905)
Suite result: ok. 22 passed; 0 failed; 0 skipped; finished in 31.19ms (21.18ms CPU time)

Ran 7 tests for test/ADRFPendingEvidence.t.sol:ADRFPendingEvidenceTest
[PASS] test_equalEvidenceAndDecisionWindowsStillAllowTimeout() (gas: 2383042)
[PASS] test_evidenceCloseIsInclusiveAndUndeterminedResolvesAfterIt() (gas: 2576220)
[PASS] test_pendingCannotFinalizeNoDecisionBeforeQuorum() (gas: 2655976)
[PASS] test_pendingCannotFinalizeNotSustainedBeforeQuorum() (gas: 2616528)
[PASS] test_quorumAtExactEvidenceCloseCanStillResolve() (gas: 2328596)
[PASS] test_reviewUsesItsFreshEvidenceWindowBeforeAdoptingEarlierRound() (gas: 1685447)
[PASS] test_zeroEvidenceWindowStillClosesAfterAdmissionTimestamp() (gas: 2374203)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 15.82ms (12.91ms CPU time)

Ran 7 tests for test/ADRFEvidenceFinality.t.sol:ADRFEvidenceFinalityTest
[PASS] test_attestationsOnlyForBoundSubQuestionsOfAdmittedCases() (gas: 4813205)
[PASS] test_attestorsMayReviseUntilAQuorumForms() (gas: 1166139)
[PASS] test_panelMustBeAStrictMajorityOfDistinctAttestors() (gas: 163912)
[PASS] test_quorumInsideTheWindow_isFinal_whoeverResolvesWhenever() (gas: 1207206)
[PASS] test_reviewRound_hasItsOwnTallyAndWindow() (gas: 1309423)
[PASS] test_verifierUndetermined_isPendingUntilTheWindowCloses() (gas: 1217083)
[PASS] test_windowClosedWithoutQuorum_isUndetermined_andFinal() (gas: 1204721)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 13.24ms (8.21ms CPU time)

Ran 4 tests for test/ADRFProcedureInForce.t.sol:ADRFProcedureInForceTest
[PASS] test_amendedFilingWindow_doesNotExtendAnEarlierDelivery() (gas: 144150)
[PASS] test_earlierDelivery_runsUnderTheProcedureInForceAtIt() (gas: 936180)
[PASS] test_laterDelivery_runsUnderTheAmendedProcedureAndTerms() (gas: 1178676)
[PASS] test_revokedBinding_stillGovernsAndEnactsTheEarlierCharge() (gas: 1325996)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 5.17ms (1.87ms CPU time)

Ran 7 tests for test/ADRFFormalFlow.t.sol:ADRFFormalFlowTest
[PASS] test_duplicateCharge_endToEnd() (gas: 1469056)
[PASS] test_enactmentLog_authorityAndEffects() (gas: 1386944)
[PASS] test_evidenceWindow() (gas: 861321)
[PASS] test_formal_burdenRuleOnTimeout() (gas: 1005838)
[PASS] test_formal_inputsMustMatchPinnedHash() (gas: 855165)
[PASS] test_formal_notSustainedWhenVerifierSaysFalse() (gas: 2299855)
[PASS] test_leadReportOpensNothing() (gas: 46633)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 10.69ms (5.71ms CPU time)

Ran 9 tests for test/ADRFRecognition.t.sol:ADRFRecognitionTest
[PASS] test_deliveryClaim_refundsTheHeldCharge() (gas: 1445569)
[PASS] test_eachSettlementBeyondTheFirst_isItsOwnCase() (gas: 3344549)
[PASS] test_exclusivity_isOnTheDecisiveProposition_notTheWording() (gas: 1515870)
[PASS] test_invertedDirection_isRefused() (gas: 98622)
[PASS] test_lateExecutor_reportsFailed() (gas: 1330461)
[PASS] test_recognitionIsTheSourcesStatement() (gas: 1826369)
[PASS] test_settlementsAreHeld_untilTheAttestedDeadline() (gas: 1384947)
[PASS] test_triviallyTrueDecisiveQuestion_isRefused() (gas: 912195)
[PASS] test_unrecognisedProposition_andWrongKind_areRefused() (gas: 1157194)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 10.64ms (6.04ms CPU time)

Ran 6 tests for test/ADRFGeneralization.t.sol:ADRFGeneralizationTest
[PASS] test_actualVersion_isAFactEstablishedByEvidence_notAFilingPrerequisite() (gas: 1830375)
[PASS] test_actualVersion_noQuorum_isNoDecision_notLiability() (gas: 1784193)
[PASS] test_declaredVersionDiffersFromCommitted_isFormal() (gas: 1574124)
[PASS] test_plainServiceAccounts_noAgentIdentityRequired() (gas: 1348910)
[PASS] test_rulingScopeIsTheObject_notTheProvider() (gas: 2852457)
[PASS] test_versionVerifier_undeterminedBeforeDelivery_andForOtherPropositions() (gas: 171746)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 8.86ms (4.20ms CPU time)

Ran 10 tests for test/ADRFReview.t.sol:ADRFReviewTest
[PASS] test_dependencyTable_gatesResolutionAndPropagatesPremises() (gas: 1450881)
[PASS] test_dependencyTable_provenanceIsAUnionThatConfersNothing() (gas: 1839667)
[PASS] test_evidenced_quorumAndAttestorGuards() (gas: 1126578)
[PASS] test_reviewWindowLapse_adoptsProvisionalDecision_closureReviewLapsed() (gas: 1333924)
[PASS] test_review_decisionWindowLapses_adoptsEarlierDecision() (gas: 1392715)
[PASS] test_review_guards() (gas: 1203241)
[PASS] test_review_hardDeadline_adoptsEarlierDecision_withTimeoutClosure() (gas: 1391157)
[PASS] test_review_requireFreshDecision_vacatesTheEarlierDecision() (gas: 4277926)
[PASS] test_review_targetMustReachTheDecisive() (gas: 1282268)
[PASS] test_review_undeterminedRound_preservesTheEarlierDecision() (gas: 1586147)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 12.07ms (8.90ms CPU time)

Ran 7 tests for test/ADRFJudgedFlow.t.sol:ADRFJudgedFlowTest
[PASS] test_bridge_guards() (gas: 2024713)
[PASS] test_judgment_expiredWhenNeverOpened() (gas: 1185272)
[PASS] test_judgment_mustFitDecisionWindow() (gas: 71355)
[PASS] test_quality_approvedByPanel_claimNotSustained() (gas: 2232153)
[PASS] test_quality_blockedByPanel_claimSustained() (gas: 2454156)
[PASS] test_quality_finalityByAdoption_isImportedAsSuch() (gas: 2322515)
[PASS] test_quality_noDecision_keepsItsMeaning() (gas: 2228410)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 9.07ms (5.85ms CPU time)

Ran 4 tests for test/ADRFVectors.t.sol:ADRFVectorsTest
[PASS] test_identifiers() (gas: 30558)
[PASS] test_interfaceIds() (gas: 52885)
[PASS] test_keys() (gas: 42922)
[PASS] test_policyIdFollowsTheAbiEncoding() (gas: 100911)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 4.70ms (1.80ms CPU time)

Ran 6 tests for test/ADRFModules.t.sol:ADRFModulesTest
[PASS] test_constructorChecksModules() (gas: 3572123)
[PASS] test_everyInterfaceFunctionIsServed() (gas: 238407)
[PASS] test_modulesRefuseDirectCalls() (gas: 96393)
[PASS] test_noEtherAccepted() (gas: 28295)
[PASS] test_routedCallsLogUnderTheRegistryAndPassRevertsThrough() (gas: 931056)
[PASS] test_unknownSelectorReverts() (gas: 17125)
Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 4.77ms (2.37ms CPU time)

Ran 13 test suites in 79.70ms (151.90ms CPU time): 105 tests passed, 0 failed, 0 skipped (105 total tests)

## Tools

`npm run check` rebuilds the thirteen worked examples, regenerates the vectors (interface ids from the compiled artifacts, identifiers, the policy id and its ABI encoding, keys) and validates every example against the six schemas with the manifest hashes re-checked; revision 5 changes no interface identifier, vector or worked example; revision 4 changed the interface identifier of `IADRFObligationSource` (`0xa52f2870`, `recognizesBreach` added), the keys vector (the proposition is now the decisive sub-question's: the duplicate-settlement statement for settlement 2 of call 17) and the worked examples (the binding lists the breaches the escrow recognizes, the duplicate-charge case names settlement 2 as its event and the verifier's proposition for it). `test/ADRFVectors.t.sol` reads the same vectors and checks each value against the Solidity side. `npm run lint:erc` runs eipw (the validator of the ethereum/ERCs repository) over the ERC text in a scratch layout with stubs for the linked proposals: 0 errors.

## Anvil rehearsal of the evidence script

`anvil --code-size-limit 32768`, then `PHASE=deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close` with `forge script script/SepoliaEvidence.s.sol --broadcast --code-size-limit 32768`, warping the clock by eleven minutes between the phases that wait for a window. All seven phases broadcast successfully, rehearsed again after revision 3 with the modular registry (the deploy phase now creates the policy registry, the six modules and the dispute registry over them) and once more with the same flags as the Sepolia run (`--skip-simulation --gas-estimate-multiplier 150 --slow --code-size-limit 65536`), under Foundry 1.5.1 and 1.7.1, after the script was changed to deploy from artifacts (`vm.deployCode`), which keeps the script contract's own creation code at 34 KB: the formal case ended `Sustained` with the refund `Enacted`; the judged case opened an ERC-8436 issue, two of three jurors blocked the proposition, the Final result was imported as `FALSE` (source round 1 of 1), the claim ended `Sustained` and the refund was `Enacted`. Rehearsed once more after revision 4 with the same Sepolia flags (48 transactions on Anvil, where the vendored ERC-8436 registry and its policy registry are deployed as well): the formal claim now names settlement 2 as its event and the verifier's proposition for that ordinal, and both refunds were `Enacted` from the held settlements; rehearsed once more with the deploy phase run twice against one ERC-8436 registry, the second time reusing the fast-track policy the first had registered (the live registry refuses a second registration of the same specification), through all seven phases.

Revision 5 extends the judged phases with the amended-terms scenario and the pending-evidence scenario (see `docs/sepolia-runbook.md`) and was rehearsed on Anvil under Foundry 1.7.1 with the runner's flags (`--skip-simulation --gas-estimate-multiplier 150 --slow`, plus `--code-size-limit 262144` on Anvil for the vendored ERC-8436 fixture, which the Sepolia run does not deploy) and one block per second (`anvil --block-time 1`), as on a chain with distinct block times: all seven phases succeeded, 71 transactions; the formal and judged cases as before; the earlier evidenced case filed under the revoked binding, decided on a quorum inside the window, finalized and refunded by the escrow under its amended binding; the later case pending on one attestation and recorded `UNDETERMINED` after its 10-minute window, ending `NoDecision`. The seven local checks held (earlier delivery under the amended binding and later delivery under the revoked binding refused with `ADRF_BindingNotInForce`, borrowed terms with `ADRF_NormNotApplicable`, both early resolutions with `ADRF_WindowOpen("evidence")`, an attestation after the quorum with `Rule_QuorumReached`, one after the window with `Rule_WindowClosed`), and `scripts/sepolia-readback.sh` re-checked the four that stay checkable after the run by `eth_call` against the chain with the same outcomes.
