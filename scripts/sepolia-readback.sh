#!/usr/bin/env bash
# Reads the state of the Sepolia evidence run back from the chain, for the evidence document.
#
#   export SEPOLIA_RPC_URL=https://...
#   bash scripts/sepolia-readback.sh [deployments/<record>.json] [deployments/<record>.transactions.json]
#   (default: the record named by RECORD, sepolia-rev5 unless set; the earlier records are deployments/sepolia.json and sepolia-rev4.json)
#
# Prints: the block timestamps of the phase boundaries, the cases (header, clock, decisive finding, round 1, ruling,
# enactment of the refund), the ERC-8436 issue and its result, the escrow's record of the calls, the balances of the
# six accounts and, for a revision-5 record, the two bindings, the attestation tallies and the refusals re-checked
# against the chain (eth_call, nothing is sent). Read-only; needs cast and python3; no key.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SEPOLIA_RPC_URL:?set SEPOLIA_RPC_URL}"
RECORD="${RECORD:-sepolia-rev5}"
D="${1:-deployments/$RECORD.json}"
TX="${2:-deployments/$RECORD.transactions.json}"
j() { python3 -c "import json,sys; print(json.load(open('$D'))['$1'])"; }
has() { python3 -c "import json,sys; sys.exit(0 if '$1' in json.load(open('$D')) else 1)"; }
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
CASES="formal:$CF judged:$CJ"
if has caseEarlier; then CASES="$CASES earlier:$(j caseEarlier) later:$(j caseLater)"; fi
for pair in $CASES; do
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
CALLS="$(j callFormal) $(j callJudged)"
if has callEarlier; then CALLS="$CALLS $(j callEarlier) $(j callLater)"; fi
for c in $CALLS; do
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
python3 - "$TX" "$D" <<'EOF' | while read -r label addr; do printf '%-10s %s  %s\n' "$label" "$addr" "$(cast balance "$addr" --rpc-url "$SEPOLIA_RPC_URL" --ether)"; done
import json,sys
d=json.load(open(sys.argv[1])); tx=d['transactions']; st=json.load(open(sys.argv[2]))
print('deployer', tx[0]['from'])
if 'client' in st:
    for k in ['client','provider','juror0','juror1','juror2']: print(k, st[k])
else:
    funded=[t['to'] for t in tx if t['phase']=='deploy' and t['kind']=='CALL' and t['function'] is None]
    for i,a in enumerate(funded): print(['client','provider','juror0','juror1','juror2'][i], a)
EOF
echo "escrow     $ESC  $(cast balance "$ESC" --rpc-url "$SEPOLIA_RPC_URL" --ether)"

if has bindingIdV2; then
    B1=$(j bindingId); B2=$(j bindingIdV2); RULE=$(j rule); PANEL=$(j panelId)
    BINDING='getBinding(bytes32)((address,bytes32,bytes32,uint8,bool,bool,bool,bool,uint64,uint64,bytes32,uint64))'
    echo
    echo "== bindings (source, policyId, scopeKey, mode, openChallenge, hasBeneficiaries, downgradeOnClock, revoked, validUntil, createdAt, termsHash, revokedAt)"
    echo "-- first binding  $B1"; call "$REG" "$BINDING" "$B1"
    echo "-- amended binding $B2"; call "$REG" "$BINDING" "$B2"
    echo "-- escrow.bindingId() = $(call "$ESC" 'bindingId()(bytes32)')"
    echo
    echo "== attestation tallies (yes, no) per case and round"
    for pair in "earlier:$(j caseEarlier)" "later:$(j caseLater)"; do
        echo "-- $pair: $(call "$RULE" 'tallyOf(bytes32,bytes32,uint32,uint32)(uint32,uint32)' "$PANEL" "${pair#*:}" 0 1 | tr '\n' ' ')"
    done
    echo
    echo "== refusals re-checked against the chain (eth_call from the client or a juror; nothing is sent)"
    name() {   # the error a reverting eth_call returned, by selector
        local out sel; out=$(cast call --rpc-url "$SEPOLIA_RPC_URL" "$@" 2>&1 || true)
        sel=$(printf '%s' "$out" | grep -o '0x[0-9a-f]\{8\}' | head -1)
        for e in 'ADRF_BindingNotInForce(bytes32,uint64)' 'ADRF_NormNotApplicable(string)' 'ADRF_WindowOpen(string)' \
                 'ADRF_AlreadyResolved(uint32)' 'ADRF_Duplicate(bytes32,bytes32)' 'ADRF_WrongState(bytes32,uint8)' 'Rule_WindowClosed(bytes32,uint64)' 'Rule_QuorumReached(bytes32,uint32,uint32)'; do
            [ "$sel" = "$(cast sig "$e")" ] && { echo "refused: ${e%%(*}"; return; }
        done
        echo "not refused as expected: $out"
    }
    CLAIM='file(bytes32,((uint256,address,uint256,bytes32),bytes32,bytes32,bytes32,bytes32,uint8,address,bytes32,bytes32[],bytes32,bytes32,bytes32,bytes32,bytes32,uint32,uint8,(bytes32,uint8,uint8,bytes32,uint32[],uint8[])[]))'
    claim() {   # the performance claim of the run on call $1 under terms $2
        local obj; obj=$(call "$ESC" 'objectOf(uint256)((uint256,address,uint256,bytes32))' "$1" | sed -E 's/ \[[^]]*\]//g' | tr -d ' ')
        local refund; refund=$REFUND
        printf '(%s,%s,%s,%s,%s,1,%s,0x%064x,[%s],%s,0x%064x,%s,%s,%s,0,2,[(%s,1,1,0x%064x,[],[])])' \
            "$obj" "$(call "$ESC" 'EVENT_DELIVERY()(bytes32)')" "$(cast keccak 'claim: the service was not performed')" "$2" \
            "$(cast keccak 'terms: the service is performed as agreed')" "$(j provider)" 0 "$refund" "$refund" 0 \
            "$(call "$ESC" 'DISPOSITION_STATUS_QUO()(bytes32)')" "$(cast keccak 'evidence scope')" \
            "$(cast keccak "$(cast abi-encode 'f(string,uint256,bytes32)' 'case document' "$1" "$(cast keccak 'claim: the service was not performed')")")" \
            "$(cast keccak 'the service was actually performed')" 0
    }
    V1=$(cast keccak 'service terms v1'); V2=$(cast keccak 'service terms v2')
    echo "-- earlier delivery under the amended binding:   $(name --from "$(j client)" "$REG" "$CLAIM" "$B2" "$(claim "$(j callEarlier)" "$V1")")"
    echo "-- later delivery under the revoked binding:     $(name --from "$(j client)" "$REG" "$CLAIM" "$B1" "$(claim "$(j callLater)" "$V2")")"
    echo "-- earlier delivery under the amended terms:     $(name --from "$(j client)" "$REG" "$CLAIM" "$B1" "$(claim "$(j callEarlier)" "$V2")")"
    echo "-- attestation on the later case after its window: $(name --from "$(j juror1)" "$RULE" 'attest(bytes32,bytes32,uint32,uint8)' "$PANEL" "$(j caseLater)" 0 2)"
    echo "-- local checks recorded by the run: $(python3 -c "import json; d=json.load(open('$D')); print('; '.join(k + ': ' + v for k, v in d.items() if k.startswith('check')))")"
fi
