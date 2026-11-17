# Event-scoped norms across amendments

`test/ADRFNormRevisions.t.sol` exercises the real ADRF registries and evidence rule with
a test-only business source whose current terms can change between deliveries.

The source snapshots the norm, its declaration time, the event time and the adoption
deadline when it records each delivery. Updating current terms does not rewrite those
snapshots. Admission still checks the source's event-specific statement, and an
already admitted case keeps its recorded norm through resolution and finality.

The seven tests cover:

- Filing an old delivery under its original norm after an amendment.
- Rejecting substitution of the latest norm for that old delivery.
- Admitting a new delivery under the amended norm, while rejecting the old norm for it.
- Resolving and finalizing an admitted old case after current terms change.
- Preserving exclusivity for the same event and decisive proposition.
- Refusing to refresh an old filing window through an amendment.
- Rejecting a different object version paired with the old event.

Run from the repository root:

```sh
forge test --match-contract ADRFNormRevisionsTest --code-size-limit 200000
forge test --code-size-limit 200000
```

Validated with Forge 1.7.1 and the repository's Solidity 0.8.30 configuration: 7 new
tests, 86 total, all passing. The test-only size override accommodates the large test
contracts, which embed deployment code for the existing ADRF and ACDF fixtures. With
Forge 1.7.1 the existing suites also exceed the repository's default test size limit.
This command is not evidence of production deployment size or gas limits.

This is an adapter example, not an ERC-8448 implementation. Its controller stands in
for application-level amendment authorization; it neither transfers funds nor enacts
refunds. ADRF relies on the business source to attest the historical norm honestly:
the registry cannot reconstruct history that a source overwrites. This contribution
changes no production contract or normative interface.
