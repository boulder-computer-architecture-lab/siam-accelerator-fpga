#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <report_subdir_name>" >&2
    exit 1
fi

REPORT_NAME="$1"

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMPL="$ROOT/build/kria-accelerator.runs/impl_1"
SYNTH="$ROOT/build/kria-accelerator.runs/synth_1"
OUT="$ROOT/reports/$REPORT_NAME"

mkdir -p "$OUT"

cp -v "$IMPL"/design_1_wrapper_timing_summary_postroute_physopted.rpt "$OUT"/timing_summary.rpt
cp -v "$IMPL"/design_1_wrapper_utilization_placed.rpt "$OUT"/utilization_impl.rpt
cp -v "$SYNTH"/design_1_wrapper_utilization_synth.rpt "$OUT"/utilization_synth.rpt
cp -v "$IMPL"/design_1_wrapper_power_routed.rpt "$OUT"/power.rpt
cp -v "$IMPL"/design_1_wrapper_drc_routed.rpt "$OUT"/drc.rpt
cp -v "$IMPL"/design_1_wrapper_methodology_drc_routed.rpt "$OUT"/methodology_drc.rpt
cp -v "$IMPL"/design_1_wrapper_clock_utilization_routed.rpt "$OUT"/clock_utilization.rpt
