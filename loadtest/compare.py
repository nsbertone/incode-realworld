"""Fail when p95 latency regresses against the baseline from main.

    python3 loadtest/compare.py <baseline.json> <current.json> [max_ratio]

A metric regresses when current > baseline * max_ratio AND the difference is
more than MIN_DELTA_MS (tiny absolute changes on fast endpoints are noise).
Shared CI runners are noisy, so the ratio is deliberately generous; the
absolute thresholds in api.js catch outright slow builds.
"""

import json
import sys

MIN_DELTA_MS = 20.0


def main() -> int:
    baseline = json.load(open(sys.argv[1]))["p95_ms"]
    current = json.load(open(sys.argv[2]))["p95_ms"]
    max_ratio = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5

    rows, failed = [], False
    for name in sorted(current):
        cur, base = current[name], baseline.get(name)
        if base is None:
            rows.append(f"| {name} | - | {cur:.0f} | - | new |")
            continue
        ratio = cur / base if base else 1.0
        bad = ratio > max_ratio and (cur - base) > MIN_DELTA_MS
        failed |= bad
        rows.append(f"| {name} | {base:.0f} | {cur:.0f} | {ratio:.2f}x | {'REGRESSION' if bad else 'ok'} |")

    print(f"p95 latency vs main (fail above {max_ratio}x)\n")
    print("| endpoint | main p95 ms | this p95 ms | ratio | result |")
    print("|---|---|---|---|---|")
    print("\n".join(rows))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
