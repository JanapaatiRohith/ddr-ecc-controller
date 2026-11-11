#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p build/iverilog

OUT="build/iverilog/ecc_full_integration.vvp"
LOG="build/iverilog/ecc_full_integration.log"

echo "========== ECC FULL INTEGRATION COMPILE =========="

iverilog -g2012 -Wall \
  -s tb_ecc_mig_full_integration \
  -o "$OUT" \
  rtl/ecc_secded.v \
  rtl/ecc_mig_axi_master.v \
  rtl/ecc_mig_selftest.v \
  tb/axi128_ram_model.v \
  tb/tb_ecc_mig_full_integration.v

echo "========== ECC FULL INTEGRATION SIMULATION =========="

vvp "$OUT" | tee "$LOG"

echo "========== RESULT =========="
echo "Simulation log: $LOG"
