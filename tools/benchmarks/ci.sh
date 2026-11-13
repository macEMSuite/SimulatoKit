#!/bin/bash
# The audit workflow's nightly CPU benchmark (.github/workflows/audit.yml, the suite's template): runs the float64 FFT
# timings (Tests/SimulatoCoreTests/FFTBenchmarkTests.swift, SIMULATO_FFT_BENCH=1) and writes them to $1 as a JSON list
# of {name, dtype, size, ms: [median]}. Each case is already a median of 21 calls; the run compares the kit with its own
# previous night. The Metal and abTEM tables (run.sh, the parity target) stay local.
set -euo pipefail
out="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
log="$(mktemp)"
SIMULATO_FFT_BENCH=1 swift test -c release --filter FFTBenchmarkTests 2>&1 | tee "$log"
python3 -I - "$log" "$out" <<'PY'
import json, re, sys
rows = []
for line in open(sys.argv[1]):
    m = re.search(r"FFTBENCH (.+?) ([0-9.]+) ms\s*$", line)
    if not m:
        continue
    words = m.group(1).split()
    size = next((w.split("=", 1)[1] for w in words if re.match(r"[nm]=", w)), "")
    rows.append({"name": " ".join(w for w in words if not re.match(r"[nm]=", w)), "dtype": "float64", "size": size,
                 "ms": [float(m.group(2))]})
if not rows:
    sys.exit("no FFTBENCH lines in the test output")
json.dump(rows, open(sys.argv[2], "w"), indent=1)
print(f"{len(rows)} cases")
PY
