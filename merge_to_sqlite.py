#!/usr/bin/env python3
"""Offline JSONL importer for local-only diagnostic archives. Python stdlib."""
import argparse
import glob
import hashlib
import json
import sqlite3
from pathlib import Path


def merge(db, inputs):
    with sqlite3.connect(db) as conn:
        conn.execute("""CREATE TABLE IF NOT EXISTS records (
            digest TEXT PRIMARY KEY, machine TEXT NOT NULL,
            timestamp_utc TEXT, kind TEXT NOT NULL,
            source_file TEXT NOT NULL, payload_json TEXT NOT NULL
        )""")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_machine_time ON records(machine,timestamp_utc)")
        added = duplicates = invalid = 0
        for pattern in inputs:
            for path in glob.glob(pattern):
                p = Path(path)
                if not p.is_file() or p.suffix.lower() != ".jsonl":
                    continue
                kind = "event" if p.name.startswith("events_") else "telemetry"
                with p.open(encoding="utf-8-sig", errors="replace") as source:
                    for line in source:
                        if not line.strip():
                            continue
                        try:
                            item = json.loads(line)
                            if not isinstance(item, dict) or not item.get("machine"):
                                raise ValueError("missing machine")
                            canonical = json.dumps(item, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
                            digest = hashlib.sha256((kind + "\0" + canonical).encode()).hexdigest()
                            when = item.get("timestamp_utc") or item.get("event_utc")
                            cursor = conn.execute(
                                "INSERT OR IGNORE INTO records VALUES (?,?,?,?,?,?)",
                                (digest, str(item["machine"]), when, kind, p.name, canonical))
                            added += cursor.rowcount
                            duplicates += 1 - cursor.rowcount
                        except (ValueError, TypeError):
                            invalid += 1
        total = conn.execute("SELECT COUNT(*) FROM records").fetchone()[0]
        return added, duplicates, invalid, total


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="diagnostics.sqlite")
    parser.add_argument("inputs", nargs="+")
    args = parser.parse_args()
    a, d, i, t = merge(args.db, args.inputs)
    print(f"ADDED={a} DUPLICATES={d} INVALID={i} TOTAL={t}")
