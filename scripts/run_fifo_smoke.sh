#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
iverilog=${IVERILOG:-iverilog}
vvp=${VVP:-vvp}
for tool in "$iverilog" "$vvp" timeout; do
  command -v "$tool" >/dev/null || { printf 'Missing tool: %s\n' "$tool" >&2; exit 1; }
done

mkdir -p work_fifo_smoke
out=$(mktemp -d "$root/work_fifo_smoke/run.XXXXXX")
printf 'Logs: %s\n' "$out"
"$iverilog" -V > "$out/iverilog-version.txt" 2>&1
sed -n '1p' "$out/iverilog-version.txt"

run_case() {
  local name=$1 width=$2 wr_half=$3 rd_half=$4 seed=$5 detector=$6
  shift 6
  local status=0
  if ! "$iverilog" -g2012 -s async_fifo_random_tb \
    "-Pasync_fifo_random_tb.ADDR_WIDTH=$width" \
    "-Pasync_fifo_random_tb.WR_HALF=$wr_half" \
    "-Pasync_fifo_random_tb.RD_HALF=$rd_half" "$@" \
    -o "$out/$name.vvp" rtl/reset_sync.sv rtl/async_fifo.sv \
    tb/unit/async_fifo_random_tb.sv > "$out/$name.compile.log" 2>&1; then
    cat "$out/$name.compile.log" >&2
    return 1
  fi
  timeout 30s "$vvp" "$out/$name.vvp" "+FIFO_SEED=$seed" \
    > "$out/$name.log" 2>&1 || status=$?

  if [[ $detector == PASS ]]; then
    if [[ $status != 0 ]] || ! grep -q '^FIFO_RANDOM_PASS ' "$out/$name.log" ||
      grep -Eq '^(ERROR|FATAL):' "$out/$name.log"; then
      cat "$out/$name.log" >&2
      printf 'FAIL: %s (exit %s)\n' "$name" "$status" >&2
      return 1
    fi
    grep '^FIFO_RANDOM_PASS ' "$out/$name.log"
    printf 'PASS %s seed=%s\n' "$name" "$seed" | tee -a "$out/summary.txt"
  else
    # A timeout or compile/tool failure is not a detected FIFO fault.
    if [[ $status != 1 ]] || ! grep -Eq "^FATAL: .*${detector}([[:space:]]|$)" "$out/$name.log" ||
      grep -q '^FIFO_RANDOM_PASS ' "$out/$name.log"; then
      cat "$out/$name.log" >&2
      printf 'FAIL: %s did not reach %s (exit %s)\n' "$name" "$detector" "$status" >&2
      return 1
    fi
    printf 'DETECTED %s seed=%s detector=%s\n' "$name" "$seed" "$detector" | tee -a "$out/summary.txt"
  fi
}

seed=1401
for width in 1 2 4 6; do
  for clocks in '3 5' '7 2'; do
    read -r wr_half rd_half <<< "$clocks"
    run_case "w${width}_${wr_half}_${rd_half}" "$width" "$wr_half" "$rd_half" "$seed" PASS
    seed=$((seed + 1))
  done
done

# Both negatives use the exact settings of the first passing baseline.
run_case full_stuck_low 1 3 5 1401 FIFO_REFERENCE_OVERFLOW -DUART_MUTATE_FIFO_FULL_STUCK_LOW
run_case corrupt_read 1 3 5 1401 FIFO_REFERENCE_ORDER -Pasync_fifo_random_tb.INJECT_READ_ERROR=1
printf 'FIFO smoke: 8/8 baselines passed; 2/2 injected faults detected.\n' | tee -a "$out/summary.txt"
