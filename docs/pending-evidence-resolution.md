# Pending evidenced findings

Author: Ted (@haot3x). November 17, 2026.

This proposes a resolution rule for [Revinand's report](https://ethereum-magicians.org/t/30121/13). It is a draft behavioral change for author review, not an adopted change to the official ERC. The existing event-scoped norms PR is separate.

## Reproduction

At upstream `bb0e9ec3820614ad80b57ff1e99b47022f25de3e`, an unrelated account can call `resolveEvidenced` while the real `AttestorQuorumRule` has fewer than two of three attestations, then call `decide`. With no reviews, the case becomes Final before its evidence window ends: `NoDecision` or `NotSustained`, according to the burden rule. The finding is already resolved, so later attestations cannot repair it in that round.

The seven new cases run the actual modular registry, real evidence rule and source escrow. Six fail against the old resolution module with `Final` where `Admitted` is required; the determined-quorum boundary control passes. The [before trace](evidence/pending-evidence-before.txt) includes both public calls and their finalization event. The report and original observation are credited to Revinand; this is an independent reproduction and proposed fix.

## Proposed rule

An evidence rule's `UNDETERMINED` result remains pending while `block.timestamp <= evidenceCloseAt` for the current round. The attempt reverts with the existing `ADRF_WindowOpen("evidence")`, retaining no finding, state change or logs. A later attempt can resolve once quorum exists. After the evidence window ends, unresolved evidence can become terminal `UNDETERMINED` under the existing burden rule, within the decision deadline.

The interface has no separate pending value, so this deliberately treats **every** returned `UNDETERMINED` as pending during that interval, including an unsupported proposition or an inconclusive method. Introducing a distinct method-level readiness signal is an alternative requiring a separate design. A `TRUE` or `FALSE` finding can still resolve early; this proposal does not guarantee that an evidence rule's determined result is monotonic or that off-chain work was actually performed. Method-side changes made during the reverted evaluation roll back too.

The evidence deadline is inclusive, matching the existing `submitEvidence` implementation. A review uses its fresh window. A zero-length evidence window includes the admission/review timestamp. If evidence and decision deadlines coincide, the existing timeout path remains available afterwards. Formal/judged resolution and `PREMISE_NOT_ESTABLISHED` short-circuiting are unchanged. No ABI, selector, interface ID, policy hash or stored type changes.

## Validation

- 86 tests pass: 79 existing cases plus seven new cases. Three existing no-quorum tests now assert pending behavior before advancing past the evidence deadline; their terminal-result assertions are retained.
- The new cases cover both burden rules, zero/one attestation followed by quorum, exact deadline boundaries, determined results, fresh review windows, equal evidence/decision deadlines and a zero-length evidence window.
- Failed early calls preserve the case, clock, finding and ruling and retain no logs.
- `npm run check` validates all 13 example documents against six schemas and regenerates identical examples/vectors. `npm run lint:erc` returns zero errors and zero other findings; its advisory spelling list remains.
- A fresh production-only build passes size checks. `ADRFResolutionModule` is 7,160 runtime bytes; the largest ADRF production contract remains the 9,209-byte example escrow.

Toolchain: native Foundry 1.7.1 (`4072e487`), Solidity 0.8.30, Cancun, optimizer runs 200, via-IR. The inherited test fixture embeds contract deployment bytecode and exceeds Foundry 1.7's test-contract size checks. The test command uses a **local test-only** size override; production limits are checked separately with the original compiler settings. No deployment or live transaction was performed.

```sh
forge test --code-size-limit 262144 -vv
forge fmt --check test/ADRFPendingEvidence.t.sol
# Separate artifacts prevent a cached test-only ACDF fixture entering the size report.
task_build_dir=$(mktemp -d)
forge build assets/erc-adrf/contracts --sizes \
  --out "$task_build_dir/out" --cache-path "$task_build_dir/cache"
npm ci --ignore-scripts --no-audit --no-fund
npm run check
npm run lint:erc
```

Recorded outputs: [suite](evidence/pending-evidence-check.txt), [production sizes](evidence/pending-evidence-production-sizes.txt), [tooling](evidence/pending-evidence-tooling.txt). To reproduce the negative control, temporarily restore only `ADRFResolutionModule.sol` from the base commit above and run `forge test --code-size-limit 262144 --match-contract ADRFPendingEvidenceTest -vvvv`, then restore the proposed module. The expected result is six failing regressions and one passing control.
