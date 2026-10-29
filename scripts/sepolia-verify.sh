#!/usr/bin/env bash
# Verifies the contracts of the Sepolia evidence run on Sourcify from the project's own build.
#
#   bash scripts/sepolia-verify.sh [deployments/<record>.json]
#   (default: the record named by RECORD, sepolia-rev4 unless set; the revision-3 record is deployments/sepolia.json)
#
# Submits the standard JSON input of each contract with its constructor arguments (taken from the deployments
# file), one by one, and prints Sourcify's answer for each. Needs forge and python3; no key, no RPC.
set -uo pipefail
cd "$(dirname "$0")/.."
RECORD="${RECORD:-sepolia-rev4}"
D="${1:-deployments/$RECORD.json}"
j() { python3 -c "import json; print(json.load(open('$D'))['$1'])"; }
POL=$(j policies); REG=$(j registry); ACDF=$(j acdfRegistry)
MOD=$(cast abi-encode "constructor(address)" "$POL")

verify() {   # address  path:Name  [constructor args]
    local addr=$1 contract=$2 args=${3:-}
    printf '\n== %s  %s\n' "$contract" "$addr"
    if [ -n "$args" ]; then
        forge verify-contract --verifier sourcify --chain 11155111 "$addr" "$contract" --constructor-args "$args" 2>&1 | tail -n 4
    else
        forge verify-contract --verifier sourcify --chain 11155111 "$addr" "$contract" 2>&1 | tail -n 4
    fi
}

forge build >/dev/null
C=assets/erc-adrf/contracts
verify "$POL"                 "$C/ADRFPolicyRegistry.sol:ADRFPolicyRegistry"
verify "$(j bindingModule)"    "$C/modules/ADRFBindingModule.sol:ADRFBindingModule"       "$MOD"
verify "$(j filingModule)"     "$C/modules/ADRFFilingModule.sol:ADRFFilingModule"         "$MOD"
verify "$(j resolutionModule)" "$C/modules/ADRFResolutionModule.sol:ADRFResolutionModule" "$MOD"
verify "$(j decisionModule)"   "$C/modules/ADRFDecisionModule.sol:ADRFDecisionModule"     "$MOD"
verify "$(j recordModule)"     "$C/modules/ADRFRecordModule.sol:ADRFRecordModule"         "$MOD"
verify "$(j outcomeModule)"    "$C/modules/ADRFOutcomeModule.sol:ADRFOutcomeModule"       "$MOD"
verify "$REG" "$C/ADRFDisputeRegistry.sol:ADRFDisputeRegistry" \
    "$(cast abi-encode "constructor(address,address,address,address,address,address,address)" "$POL" "$(j bindingModule)" "$(j filingModule)" "$(j resolutionModule)" "$(j decisionModule)" "$(j recordModule)" "$(j outcomeModule)")"
verify "$(j verifier)"         "$C/examples/DuplicateSettlementVerifier.sol:DuplicateSettlementVerifier"
verify "$(j versionVerifier)"  "$C/examples/DeclaredVersionVerifier.sol:DeclaredVersionVerifier"
verify "$(j rule)"             "$C/examples/AttestorQuorumRule.sol:AttestorQuorumRule"
verify "$(j bridge)"           "$C/bridges/ADRFACDFBridge.sol:ADRFACDFBridge" "$(cast abi-encode "constructor(address,address)" "$REG" "$ACDF")"
verify "$(j escrow)"           "$C/examples/ADRFServiceEscrow.sol:ADRFServiceEscrow" "$(cast abi-encode "constructor(address)" "$REG")"
echo
echo "check any address at https://repo.sourcify.dev/11155111/<address> or https://sourcify.dev/server/v2/contract/11155111/<address>"
