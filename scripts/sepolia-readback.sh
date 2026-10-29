#!/usr/bin/env bash
# Reads the state of the Sepolia evidence run back from the chain, for the evidence document.
#
#   export SEPOLIA_RPC_URL=https://...
#   bash scripts/sepolia-readback.sh [deployments/<record>.json] [deployments/<record>.transactions.json]
#   (default: the record named by RECORD, sepolia-rev4 unless set; the revision-3 record is deployments/sepolia.json)
#
# Prints: the block timestamps of the phase boundaries, the two cases (header, clock, decisive finding, round 1,
# ruling, enactment of the refund), the ERC-8436 issue and its result, the escrow's record of the two calls and the
# balances of the six accounts. Read-only; needs cast and python3; no key.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SEPOLIA_RPC_URL:?set SEPOLIA_RPC_URL}"
RECORD="${RECORD:-sepolia-rev4}"
D="${1:-deployments/$RECORD.json}"
TX="${2:-deployments/$RECORD.transactions.json}"
j() { python3 -c "import json,sys; print(json.load(open('$D'))['$1'])"; }
call() { cast call --rpc-url "$SEPOLIA_RPC_URL" "$@"; }

REG=$(j registry); ESC=$(j escrow); ACDF=$(j acdfRegistry); BRIDGE=$(j bridge)
CF=$(j caseFormal); CJ=$(j caseJudged); ISSUE=$(j issueJudged); POL=$(j policies)
REFUND=$(call "$ESC" 'EFFECT_REFUND()(bytes32)')

RULING='getRuling(bytes32)((uint8,uint8,uint8,uint8,uint8,uint64,uint64,uint32,uint32,bool,bool,uint8,bytes32,bytes32,bytes32,bytes32,address,bytes32,(address,bytes32,bytes32,uint32,uint32,bool,uint8)))'
CASE='getCase(bytes32)((bytes32,bytes32,address,uint8,uint8,address,address,bytes32,(uint256,address,uint256,bytes32),bytes32,bytes32,bytes32,bytes32,uint8,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint32,uint8,uint32))'
CLOCK='getClock(bytes32)((uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64,bool,uint32,uint32))'
FINDING='getFinding(bytes32,uint32)((bool,uint8,uint8,bytes32,address,uint8,uint32,uint64,(address,bytes32,bytes32,uint32,uint32,bool,uint8)))'
ROUND='getRound(bytes32,uint32)((uint8,uint8,uint64,bool,uint8,uint8,(address,bytes32,bytes32,uint32,uint32,bool,uint8)))'
ENACT='getEnactment(bytes32,bytes32)((uint8,address,bytes32,uint64))'
RESULT='getResult(bytes32)((uint8,uint8,bool,uint8,uint64,uint64,bytes32,uint32,uint32,uint8,address,bytes32,bytes32,bytes32,bytes32,bool))'
ISSUEQ='getIssue(bytes32)((bytes32,uint8,uint8,uint8,address,address,bytes32,(uint256,address,uint256,bytes32),bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint64,uint64,uint64,uint32,uint8,bool,uint8,uint32,uint64))'

echo "== chain $(cast chain-id --rpc-url "$SEPOLIA_RPC_URL"), head block $(cast block-number --rpc-url "$SEPOLIA_RPC_URL")"
echo
echo "== phase boundaries (first block of each phase: number, timestamp)"
python3 - "$TX" <<'EOF' | while read -r phase block; do printf '%-16s %s  %s\n' "$phase" "$block" "$(cast block "$block" --rpc-url "$SEPOLIA_RPC_URL" -f timestamp)"; done
import json,sys
d=json.load(open(sys.argv[1])); seen=set()
for t in d['transactions']:
    if t['phase'] not in seen: seen.add(t['phase']); print(t['phase'], t['block'])
EOF
echo
echo "== registry $REG: supportsInterface(IADRFDisputeRegistry 0xedc59c17) = $(call "$REG" 'supportsInterface(bytes4)(bool)' 0xedc59c17), policies() = $(call "$REG" 'policies()(address)'), CLOCK_MODE = $(call "$REG" 'CLOCK_MODE()(string)')"
echo "== policy registry $POL: policyExists = $(call "$POL" 'policyExists(bytes32)(bool)' "$(j policyId)")"
echo
for pair in "formal:$CF" "judged:$CJ"; do
    name=${pair%%:*}; id=${pair#*:}
    echo "== $name case $id"
    echo "-- getCase (policyId, bindingId, source, effectClass, state, claimant, respondent, actorRef, object, eventRef, proposition, normRef, clause, obligationKind, obligationRef, exclusivityKey, effectOnSustained, effectOnNotSustained, fallbackRef, evidenceScopeHash, documentHash, decisive, supportsWhen, subQuestionCount)"
    call "$REG" "$CASE" "$id"
    echo "-- getClock (eventAt, filedAt, admittedAt, evidenceCloseAt, decisionDeadline, hardDeadline, reviewOpenUntil, answerDeadline, answered, roundCount, reviewsUsed)"
    call "$REG" "$CLOCK" "$id"
    echo "-- getFinding 0 (resolved, value, supportKinds, resultHash, acceptedBy, reason, round, at, source(method, handle, resultRef, sourceRound, roundCount, adoptedFromEarlierRound, reason))"
    call "$REG" "$FINDING" "$id" 0
    echo "-- getRound 1 (result, reason, at, bySilence, supportKinds, decisiveValue, judgment)"
    call "$REG" "$ROUND" "$id" 1
    echo "-- getRuling (state, result, effectClass, reason, closure, decidedAt, finalAt, roundCount, sourceRound, adoptedFromEarlierRound, bySilence, supportKinds, allowedEffect, fallbackRef, policyId, bindingId, source, proposition, judgment)"
    call "$REG" "$RULING" "$id"
    echo "-- getEnactment REFUND (status, reporter, ref, at)"
    call "$REG" "$ENACT" "$id" "$REFUND"
    echo "-- escrow.refunded(caseId) = $(call "$ESC" 'refunded(bytes32)(bool)' "$id")"
    echo
done
echo "== ERC-8436 issue $ISSUE on $ACDF"
echo "-- getIssue (policyId, mode, effectClass, state, filer, consumer, acceptanceId, subject, question, effectYes, effectNo, disposition, obligationId, obligationKey, filedAt, admittedAt, consumerDeadline, hardDeadline, finalAt, roundCount, outcomeType, outcomeYes, reason, sourceRound, decidedAt)"
call "$ACDF" "$ISSUEQ" "$ISSUE"
echo "-- getResult (state, outcomeType, outcomeYes, reason, decidedAt, finalAt, policyId, roundCount, sourceRound, effectClass, consumer, effectYes, effectNo, disposition, obligationId, adoptedFromEarlierRound)"
call "$ACDF" "$RESULT" "$ISSUE"
echo "-- bridge.issueOf(keccak(caseJudged, 0)) = $(call "$BRIDGE" 'issueOf(bytes32)(bytes32)' "$(cast keccak "$(cast abi-encode 'f(bytes32,uint32)' "$CJ" 0)")")"
echo
echo "== escrow $ESC"
for c in $(j callFormal) $(j callJudged); do
    n=$(call "$ESC" 'settlementCount(uint256)(uint32)' "$c")
    echo "-- call $c: settlementCount = $n; heldOf = $(call "$ESC" 'heldOf(uint256)(uint256)' "$c") wei; versionsOf (committed, declared) = $(call "$ESC" 'versionsOf(uint256)(bytes32,bytes32)' "$c" | tr '\n' ' ')"
    for ((k = 1; k <= n; k++)); do
        echo "   settlement $k: (at, state 0 Held / 1 Released / 2 Refunded) = $(call "$ESC" 'settlementOf(uint256,uint32)(uint64,uint8)' "$c" "$k" | tr '\n' ' '); eventRef = $(call "$ESC" 'settlementEventRef(uint32)(bytes32)' "$k")"
    done
done
echo "-- balanceOf(provider) = $(call "$ESC" 'balanceOf(address)(uint256)' "$(python3 - "$TX" <<'PY'
import json,sys
tx=json.load(open(sys.argv[1]))['transactions']
print([t['to'] for t in tx if t['phase']=='deploy' and t['kind']=='CALL' and t['function'] is None][1])
PY
)") wei (released settlements only; nothing is credited at settlement)"
echo
echo "== balances (ETH)"
python3 - "$TX" <<'EOF' | while read -r label addr; do printf '%-10s %s  %s\n' "$label" "$addr" "$(cast balance "$addr" --rpc-url "$SEPOLIA_RPC_URL" --ether)"; done
import json,sys
d=json.load(open(sys.argv[1])); tx=d['transactions']
dep=tx[0]['from']; funded=[t['to'] for t in tx if t['phase']=='deploy' and t['kind']=='CALL' and t['function'] is None]
print('deployer', dep)
for i,a in enumerate(funded): print(['client','provider','juror0','juror1','juror2'][i], a)
EOF
echo "escrow     $ESC  $(cast balance "$ESC" --rpc-url "$SEPOLIA_RPC_URL" --ether)"
