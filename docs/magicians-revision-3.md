# Revision 3 note (reply for the Magicians thread)

*Posted as a reply on topic 30121 after ERC-8471 was assigned. Plain text for the forum; the links are the companion repository and the pull request.*

---

**Revision 3 — ERC-8471 assigned; the reference registry made deployable under Sepolia's gas cap.**

The proposal has its number: ERC-8471 (ethereum/ERCs#2123, files renamed from the placeholder). Revision 3 changes the reference implementation only; the specification text, every interface, every identifier and the vectors are unchanged.

What changed and why. Sepolia's current gas schedule caps a transaction at 16,777,216 gas and prices deployment at roughly 1,500 gas per byte of code, so nothing above about 10.5 KB of runtime code can be deployed there. The revision-2 dispute registry was 14.4 KB with two externally linked libraries of 12.0 and 13.2 KB — none of the three would have deployed. Revision 3 keeps the whole of `IADRFDisputeRegistry` at one address: a 2 KB registry holds the record in its own storage and runs each function of the interface in one of six modules by delegatecall (bindings; filing and admission; resolution and reviews; decisions and finality; the case reads and the informative entries; the reads of findings, rounds and rulings), each between 3.9 and 8.5 KB. The modules share the registry's storage layout, are fixed at construction, refuse to run on their own storage, and must have been built for the same policy registry; every entry is logged under the registry's address and a module's revert reaches the caller unchanged. `supportsInterface` and the interface identifier are as before.

The suite is now 70 tests (six new ones for the module mechanics: routing of every interface function, direct-call refusal, foreign-module refusal, unknown selectors, no ether, logs under the registry), and the seven-phase evidence script was rehearsed again on Anvil end to end. The Sepolia run follows; its record will be posted here.

Repository: https://github.com/garyyang-finchip/ai-dispute-resolution · PR: https://github.com/ethereum/ERCs/pull/2123
