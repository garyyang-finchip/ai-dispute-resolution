# Pull request: Update ERC-8471 (revision 6)

*Text for the ethereum/ERCs update pull request of revision 6, the first change after the merge of ethereum/ERCs#2123 on 2026-11-25. Branch `update-erc-8471-rev6` of the author's fork, cut from `ethereum/ERCs` master; it changes `ERCS/erc-8471.md` and seven files under `assets/erc-8471/contracts/` (the files of `ercs-pr-package/` that differ from master), and nothing else.*

---

**Title:** Update ERC-8471: evidence rule read at expiry, strict evidence window

**Description:**

Revision 6 of ERC-8471 (Draft), after the fourth round of review on the discussion thread, in reply to [post 18](https://ethereum-magicians.org/t/erc-8471-ai-dispute-resolution-framework-adrf/30121/18): once the decision deadline had passed, whether an evidenced question ended `METHOD_UNDETERMINED` or `TIMEOUT`, and whether a quorum formed inside the evidence window counted at all, depended on whether anyone had called before the deadline.

Specification:

- Section 3.2: a policy's evidence window must be shorter than its decision window (`<` instead of `<=`); with equal windows an `UNDETERMINED` could never be resolved, pending until the window closed and refused after the deadline.
- Section 9.1, and Section 9.4 for `enforceDeadline`: a decisive question that nobody resolved by the decision deadline is recorded as a resolution at the deadline would have recorded it, wherever the registry can establish that without a party's input. For an evidenced question the registry calls the rule's `evaluate` once, with an empty bundle and a fixed gas allowance of at least 1,000,000: `TRUE` or `FALSE` is recorded as the rule's finding, `UNDETERMINED` as `METHOD_UNDETERMINED`, a revert, an exhausted allowance or a malformed answer as `TIMEOUT`; an expiry that cannot forward the whole allowance reverts. An unresolved premise gives `TIMEOUT` and a premise with another value `PREMISE_NOT_ESTABLISHED`; formal and judged questions, which the registry cannot evaluate itself, stay `TIMEOUT`.
- Section 8.3: a resolution or an expiry during which the rule called back into the registry and changed the case (its state, its round or the sub-question's finding) reverts; at expiry a rule should answer from the material it already holds.
- Section 8.1 (closing sentence), Section 15 (what each reason means to a declaration keyed on it), a Rationale paragraph, a Security Considerations paragraph, and Test Cases (items 1 and 9 adjusted, item 17 added).

Reference implementation: `ADRFPolicyRegistry` (the strict window), `ADRFErrors` (`ADRF_InsufficientGas`, `ADRF_ReentrantChange`), `ADRFModule`, `ADRFResolutionModule` and `ADRFDecisionModule` (the expiry read and the check after a call to a rule), and the comments of `IADRFDisputeRegistry` and `IADRFEvidenceRule`.

No function signature, ERC-165 identifier, vector, schema or worked example changes; the preamble is unchanged. The companion repository's suite grows from 105 to 125 Foundry tests (Foundry 1.5.1 and 1.7.1), twenty of them on the expiry, and eipw reports no errors; a fourth Sepolia run with the expiry cases on chain will be recorded there.

Discussion: https://ethereum-magicians.org/t/erc-8471-ai-dispute-resolution-framework-adrf/30121 · Companion repository: https://github.com/garyyang-finchip/ai-dispute-resolution
