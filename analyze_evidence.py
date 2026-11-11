#!/usr/bin/env python3
"""Offline evidence summary. NEVER infers root cause from temporal correlation."""
import argparse
import json
from pathlib import Path


def inspect(record):
    if not isinstance(record, dict) or record.get("schema") != 2:
        raise ValueError("Unsupported evidence schema")
    sources = record.get("sources") or {}
    signals = []
    incomplete = []
    for name, source in sources.items():
        state = source.get("status", "UNAVAILABLE")
        if state not in ("OK", "DISABLED"):
            incomplete.append(name)
        if state != "OK":
            continue
        data = source.get("data")
        if name.startswith("events_") and isinstance(data, list):
            for event in data:
                try:
                    code = int(event.get("code", -1))
                except (ValueError, TypeError):
                    continue
                provider = str(event.get("provider", ""))
                if code == 4101 and provider.lower() == "display":
                    signals.append("GPU_DISPLAY_RESET_4101")
                elif code == 41 and "Kernel-Power" in provider:
                    signals.append("UNEXPECTED_SHUTDOWN_41")
                elif "WHEA" in provider.upper():
                    signals.append("HARDWARE_WHEA")
                elif code == 1000 and name == "events_application":
                    signals.append("APPLICATION_ERROR_1000")
        if name == "comfy_log_evidence" and isinstance(data, dict):
            for match in data.get("signatures", []):
                label = str(match.get("code", ""))
                if label in {"CUDA", "OOM", "EXCEPTION", "AIMDO", "IMPORT"}:
                    signals.append("COMFY_" + label)
    signals = sorted(set(signals))
    caveats = [
        "Temporal adjacency does not prove causation.",
        "Kernel-Power 41 is a shutdown marker, not proof of the initial fault.",
        "Logs may be missing after a full Windows/GPU hang.",
    ]
    if incomplete:
        caveats.append("Incomplete evidence sources: " + ", ".join(sorted(incomplete)))
    return {
        "schema": 1,
        "machine": record.get("machine", "UNKNOWN"),
        "snapshot_utc": record.get("created_utc"),
        "signals": signals,
        "available_sources": sorted(k for k, v in sources.items() if v.get("status") == "OK"),
        "missing_sources": sorted(incomplete),
        "root_cause": "NOT_CONFIRMED",
        "caveats": caveats,
    }


def compare_environment(first, second):
    def find(snapshot, k):
        return ((snapshot.get("sources") or {}).get("environment") or {}).get("data", {}).get(k, "UNKNOWN")
    keys = ("python", "pytorch", "comfyui", "cuda", "aimdo")
    return {
        key: {"before": find(first, key), "after": find(second, key)}
        for key in keys
        if find(first, key) != find(second, key)
    }


def main():
    parser = argparse.ArgumentParser(description="Read-only ComfyUI diagnostics evidence summary")
    parser.add_argument("snapshot", type=Path, help="Evidence JSON file")
    parser.add_argument("--compare", type=Path, help="Earlier evidence JSON, optional")
    args = parser.parse_args()
    item = json.loads(args.snapshot.read_text(encoding="utf-8-sig"))
    result = inspect(item)
    if args.compare:
        earlier = json.loads(args.compare.read_text(encoding="utf-8-sig"))
        result["environment_changes"] = compare_environment(earlier, item)
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
