# Pull request: Add ERC: AI Dispute Resolution Framework

*Text for the ethereum/ERCs pull request, opened as [ethereum/ERCs#2123](https://github.com/ethereum/ERCs/pull/2123) on 2026-10-28 under the placeholder number 9999; ERC-8471 was assigned on 2026-10-29 and the files were renamed to `ERCS/erc-8471.md` and `assets/erc-8471/...` (47 files from `ercs-pr-package/`). Branch `add-erc-ai-dispute`, cut from `ethereum/ERCs` master.*

---

**Title:** Add ERC: AI Dispute Resolution Framework

**Description:**

This PR adds the AI Dispute Resolution Framework (ADRF), a draft ERC for disputes about AI systems, resources and services and about the conduct, deliveries and declarations around them, between participants that may be people, organizations, agents or contracts.

A dispute is a specific claim about a specific object — that an identified record, delivery, settlement, declaration or action does or does not conform to an obligation declared before the event — admitted under a pre-committed binding, resolved by typed methods (deterministic verifiers, evidence rules, judgment methods) and closed by a ruling whose effects are limited to what the binding authorized. Two co-deployable registries hold the normative record and never move funds or execute an effect. The reference judgment method consumes ERC-8436 through its published interface (one binary question per sub-question, Final results only, full provenance), which is why ERC-8436 is listed in `requires`.

Discussion: https://ethereum-magicians.org/t/erc-8471-ai-dispute-resolution-framework-adrf/30121

Reference implementation, schemas, vectors, worked examples and the test suite (64 Foundry tests, including the two complete flows against the vendored ERC-8436 reference registry) are in the assets and in the companion repository: https://github.com/garyyang-finchip/ai-dispute-resolution

Filed under the placeholder number 9999; renamed to ERC-8471 when the number was assigned.
