#!/usr/bin/env bash
# Standalone educational example; not the UART signoff/coverage flow.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo"
verilator_bin=${APB_UART_VERILATOR:-verilator}
jobs=${JOBS:-2}
seed=${SEED:-1702}
build_timeout=${BUILD_TIMEOUT_SECONDS:-300}
run_timeout=${RUN_TIMEOUT_SECONDS:-30}
: "${UVM_HOME:?Set UVM_HOME to the Accellera uvm-core checkout containing src/}"
[[ -f "$UVM_HOME/src/uvm_pkg.sv" ]] || { echo 'UVM_HOME/src/uvm_pkg.sv missing' >&2; exit 1; }
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo 'JOBS must be a positive integer' >&2; exit 1; }
[[ "$seed" =~ ^[1-9][0-9]*$ ]] || { echo 'SEED must be a positive integer' >&2; exit 1; }
UVM_HOME=$(cd -- "$UVM_HOME" && pwd)
command -v "$verilator_bin" >/dev/null || { echo 'APB_UART_VERILATOR executable not found' >&2; exit 1; }
command -v timeout >/dev/null || { echo 'GNU timeout is required' >&2; exit 1; }
[[ "$(timeout --version)" == *'GNU coreutils'* ]] || { echo 'GNU timeout is required' >&2; exit 1; }
[[ "$build_timeout" =~ ^[1-9][0-9]*$ && "$run_timeout" =~ ^[1-9][0-9]*$ ]] || {
  echo 'BUILD_TIMEOUT_SECONDS and RUN_TIMEOUT_SECONDS must be positive integers' >&2; exit 1;
}
"$verilator_bin" --version
echo "UVM_HOME=$UVM_HOME"
echo "Logs: $repo/logs/apb-regblock/ (seed=$seed, build timeout=${build_timeout}s, run timeout=${run_timeout}s)"
command -v python3 >/dev/null || { echo 'python3 is required for precise log checks' >&2; exit 1; }
# A unique temporary build directory avoids mixing generated baseline/fault code.
build_root=$(mktemp -d "${TMPDIR:-/tmp}/apb-regblock.XXXXXXXX")
trap 'rm -rf -- "$build_root"' EXIT
for mode in baseline fault; do
  out="$repo/logs/apb-regblock/verilator_${mode}_${seed}"
  mkdir -p "$out"
  rm -f -- "$out/compile.log" "$out/run.log"
  defines=(+define+UVM_NO_DPI)
  if [[ "$mode" == fault ]]; then defines+=(+define+REGBLOCK_INJECT_FAULT); fi
  echo "Building $mode (seed=$seed); log: $out/compile.log"
  if ! timeout --kill-after=5s "${build_timeout}s" "$verilator_bin" --binary --timing --assert -Wno-fatal -CFLAGS -O0 -j "$jobs" \
      --Mdir "$build_root/$mode" --top-module tb_regblock \
      "+incdir+$UVM_HOME/src" "${defines[@]}" "$UVM_HOME/src/uvm_pkg.sv" \
      -f examples/apb-regblock/filelist.f >"$out/compile.log" 2>&1; then
    echo "Compilation failed or timed out: $out/compile.log" >&2; exit 1
  fi
  if ! timeout --kill-after=5s "${run_timeout}s" "$build_root/$mode/Vtb_regblock" "+verilator+seed+$seed" \
      +UVM_TESTNAME=regblock_test >"$out/run.log" 2>&1; then
    echo "Simulation failed or timed out: $out/run.log" >&2; exit 1
  fi
  python3 - "$mode" "$out/run.log" <<'PY'
import re
import sys
from pathlib import Path
mode, path = sys.argv[1:]
text = Path(path).read_text(errors='replace')
def require(condition, reason):
    if not condition:
        sys.exit(f'FAIL ({mode}): {reason}; see {path}')
def count_summary(severity, expected):
    matches = re.findall(rf'^\s*{severity}\s*:\s*(\d+)\s*$', text, re.M)
    require(matches == [str(expected)], f'{severity} summary must equal {expected}')
require('REGBLOCK_TIMEOUT' not in text, 'watchdog timeout')
require(re.search(r'\[REGBLOCK_SUMMARY\][^\n]*observed=12 expected=12', text),
        'missing complete 12-transfer summary')
count_summary('UVM_ERROR', 2 if mode == 'fault' else 0)
count_summary('UVM_FATAL', 0)
count_summary('UVM_WARNING', 2)
warnings = re.findall(r'^\s*UVM_WARNING[^\n]*?\[([^\]]+)\]', text, re.M)
require(sorted(warnings) == ['NO_DPI_USED', 'NO_VISIT_CHECK'],
        f'unexpected warning IDs: {warnings}')
errors = re.findall(r'^\s*UVM_ERROR[^\n]*?\[([^\]]+)\]', text, re.M)
require(errors == (['REGBLOCK_DATA'] * 2 if mode == 'fault' else []),
        f'unexpected error IDs: {errors}')
require(not re.search(r'^\s*(?:%Error|Error:|Fatal:|UVM_FATAL\s+@)', text, re.M),
        'simulator or UVM fatal diagnostic')
print(('EXPECTED_FAULT_DETECTED' if mode == 'fault' else 'PASS') +
      f': {mode}, 12 monitored transfers; {path}')
PY
done
echo 'PASS: baseline passed and the specified fault was detected (exit 0)'
