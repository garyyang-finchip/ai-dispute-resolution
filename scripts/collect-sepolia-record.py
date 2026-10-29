#!/usr/bin/env python3
"""Collects the transaction record of the Sepolia evidence run from the Foundry broadcast files.

    python3 scripts/collect-sepolia-record.py [--chain 11155111] [--out deployments/sepolia-rev4.transactions.json]
                                              [--since <run-file timestamp>] [--all]

Reads broadcast/SepoliaEvidence.s.sol/<chain>/run-<timestamp>.json in time order (one file per phase, in the
order the phases were run), and writes one entry per transaction: phase, kind (CREATE or CALL), the contract
created or the function called, sender, target, hash, block, status, gas used and effective gas price, plus the
totals. When the directory holds the files of an earlier run as well, the newest seven are taken (--since keeps
only the files from that time on, --all keeps every file); the files used are listed. The phase names are
assigned in the order of the runbook when exactly seven run files are selected; otherwise each file is labelled
run-N and the names are left to the author of the record.
"""
import argparse
import glob
import json
import os

PHASES = ["deploy", "formal-file", "formal-finalize", "judged-file", "judged-vote", "judged-finalize", "judged-close"]


def hexint(v):
    if v is None:
        return None
    if isinstance(v, int):
        return v
    return int(v, 16) if isinstance(v, str) and v.startswith("0x") else int(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chain", default="11155111")
    ap.add_argument("--out", default=os.path.join("deployments", "sepolia-rev4.transactions.json"))
    ap.add_argument("--since", type=int, default=None, help="keep only the run files whose timestamp (the number in the file name) is at or after this one")
    ap.add_argument("--all", action="store_true", help="keep every run file, however many")
    args = ap.parse_args()

    folder = os.path.join("broadcast", "SepoliaEvidence.s.sol", args.chain)
    files = sorted(
        (f for f in glob.glob(os.path.join(folder, "run-*.json")) if not f.endswith("run-latest.json")),
        key=lambda f: json.load(open(f)).get("timestamp", 0),
    )
    if not files:
        raise SystemExit(f"no run files under {folder}")
    if args.since is not None:
        files = [f for f in files if json.load(open(f)).get("timestamp", 0) >= args.since]
    elif not args.all and len(files) > len(PHASES):
        print(f"{len(files)} run files under {folder}: taking the newest {len(PHASES)} (use --since or --all to choose otherwise)")
        files = files[-len(PHASES):]
    if not files:
        raise SystemExit("no run files selected")
    for f in files:
        print("  ", os.path.basename(f), "timestamp", json.load(open(f)).get("timestamp"))
    names = PHASES if len(files) == len(PHASES) else [f"run-{i + 1}" for i in range(len(files))]

    entries = []
    total_gas = 0
    total_fee = 0
    for name, path in zip(names, files):
        run = json.load(open(path))
        receipts = {r["transactionHash"].lower(): r for r in run.get("receipts", [])}
        for t in run.get("transactions", []):
            r = receipts.get((t.get("hash") or "").lower(), {})
            gas = hexint(r.get("gasUsed"))
            price = hexint(r.get("effectiveGasPrice"))
            status = hexint(r.get("status"))
            tx = t.get("transaction", {})
            entry = {
                "phase": name,
                "kind": t.get("transactionType"),
                "contract": t.get("contractName"),
                "function": t.get("function"),
                "from": tx.get("from"),
                "to": tx.get("to") or t.get("contractAddress"),
                "hash": t.get("hash"),
                "block": hexint(r.get("blockNumber")),
                "status": "success" if status == 1 else ("failed" if status == 0 else "unknown"),
                "gasUsed": gas,
                "effectiveGasPrice": price,
            }
            if gas is not None:
                total_gas += gas
                if price is not None:
                    total_fee += gas * price
            entries.append(entry)

    out = {
        "chainId": int(args.chain),
        "script": "script/SepoliaEvidence.s.sol",
        "execution": "forge script --broadcast --skip-simulation --gas-estimate-multiplier 150 --slow (gas limits from the node's estimates)",
        "phases": names,
        "transactionCount": len(entries),
        "totalGasUsed": total_gas,
        "totalFeeWei": total_fee,
        "transactions": entries,
    }
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(out, f, indent=2)
    failed = [e for e in entries if e["status"] != "success"]
    print(f"{len(entries)} transactions across {len(files)} phase file(s); total gas {total_gas:,}; fees {total_fee / 1e18:.6f} ETH; "
          f"{len(failed)} not successful")
    for e in failed:
        print("  ", e["phase"], e["kind"], e.get("contract") or e.get("function"), e["hash"], e["status"])


if __name__ == "__main__":
    main()
