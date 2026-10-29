#!/usr/bin/env bash
# One-command driver of the Sepolia evidence run (docs/sepolia-runbook.md).
#
#   export SEPOLIA_RPC_URL=https://...        # any Sepolia JSON-RPC endpoint
#   export PRIVATE_KEY=0x...                  # the deployer; funds the derived actors itself
#   scripts/sepolia-run.sh preflight          # chain id, balance, ERC-8436 registry, the three largest creations vs the cap
#   scripts/sepolia-run.sh all                # the seven phases in order, waiting 11 minutes where a window must lapse
#   scripts/sepolia-run.sh record             # deployments/sepolia.json + deployments/sepolia.transactions.json
#
# Single phases: scripts/sepolia-run.sh deploy | formal-file | formal-finalize | judged-file | judged-vote | judged-finalize | judged-close
# Requires Foundry (forge, cast) and python3. Nothing here needs any key other than PRIVATE_KEY.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SEPOLIA_RPC_URL:?set SEPOLIA_RPC_URL}"
: "${PRIVATE_KEY:?set PRIVATE_KEY}"
export ACDF_REGISTRY="${ACDF_REGISTRY:-0x3bE57E74f2E7c280073b6B16A1Db3F562758dB01}"   # ERC-8436 revision-3 registry on Sepolia
CAP=16777216
WAIT="${WAIT_SECONDS:-660}"
RUN=(forge script script/SepoliaEvidence.s.sol --rpc-url "$SEPOLIA_RPC_URL" --broadcast --skip-simulation --gas-estimate-multiplier 150 --slow --disable-code-size-limit -vv)

say() { printf '\n== %s\n' "$*"; }

preflight() {
    say "chain"
    local chain; chain=$(cast chain-id --rpc-url "$SEPOLIA_RPC_URL")
    [ "$chain" = "11155111" ] || { echo "not Sepolia: chain id $chain"; exit 1; }
    local deployer; deployer=$(cast wallet address --private-key "$PRIVATE_KEY")
    echo "deployer $deployer balance $(cast balance "$deployer" --rpc-url "$SEPOLIA_RPC_URL" --ether) ETH, nonce $(cast nonce "$deployer" --rpc-url "$SEPOLIA_RPC_URL")"
    echo "base fee $(cast base-fee --rpc-url "$SEPOLIA_RPC_URL") wei"
    say "ERC-8436 registry $ACDF_REGISTRY"
    echo "policies() = $(cast call "$ACDF_REGISTRY" 'policies()(address)' --rpc-url "$SEPOLIA_RPC_URL")"
    say "largest creations against the per-transaction cap ($CAP)"
    forge build >/dev/null
    local arg; arg=$(cast abi-encode "f(address)" 0x0000000000000000000000000000000000000001 | cut -c3-)
    local ok=1
    for c in ADRFPolicyRegistry:"" ADRFDecisionModule:"$arg" ADRFFilingModule:"$arg" ADRFOutcomeModule:"$arg" ADRFResolutionModule:"$arg" ADRFServiceEscrow:"$arg"; do
        local name=${c%%:*} ctor=${c#*:}
        local code; code=$(forge inspect "$name" bytecode)
        local est; est=$(cast estimate --rpc-url "$SEPOLIA_RPC_URL" --create "${code}${ctor}" 2>&1 || true)
        if [[ "$est" =~ ^[0-9]+$ ]]; then
            printf '%-26s %12s gas  (%d%% of the cap)\n' "$name" "$est" $((est * 100 / CAP))
            [ "$est" -lt "$CAP" ] || ok=0
        else
            printf '%-26s estimate failed: %s\n' "$name" "$est"; ok=0
        fi
    done
    [ "$ok" = 1 ] && echo "pre-flight passed" || { echo "pre-flight FAILED: a creation does not fit the cap"; exit 1; }
}

phase() {
    say "phase $1"
    PHASE="$1" "${RUN[@]}"
}

wait_window() {
    say "waiting ${WAIT}s for the window to lapse"
    local left=$WAIT
    while [ "$left" -gt 0 ]; do printf '\r  %4ds left ' "$left"; sleep 30; left=$((left - 30)); done; echo
}

record() {
    say "record"
    cp deployments/11155111.json deployments/sepolia.json
    python3 scripts/collect-sepolia-record.py
    echo "written deployments/sepolia.json and deployments/sepolia.transactions.json"
}

case "${1:-}" in
    preflight) preflight ;;
    all)
        preflight
        phase deploy
        phase formal-file
        wait_window
        phase formal-finalize
        phase judged-file
        phase judged-vote
        wait_window
        phase judged-finalize
        wait_window
        phase judged-close
        record
        ;;
    deploy|formal-file|formal-finalize|judged-file|judged-vote|judged-finalize|judged-close) phase "$1" ;;
    record) record ;;
    *) echo "usage: $0 preflight | all | <phase> | record"; exit 2 ;;
esac
