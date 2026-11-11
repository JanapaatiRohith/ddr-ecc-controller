#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for tool in iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool is not installed or not on PATH."
        exit 127
    fi
done

for file in rtl/ecc_secded.v tb/tb_ecc_secded.v; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Missing source file: $file"
        exit 1
    fi
done

mkdir -p build/iverilog

echo "=== Compiling SECDED testbench ==="

iverilog -g2012 -Wall \
    -s tb_ecc_secded \
    -o build/iverilog/tb_ecc_secded.vvp \
    rtl/ecc_secded.v \
    tb/tb_ecc_secded.v

echo "=== Running SECDED regression ==="

set -o pipefail
vvp build/iverilog/tb_ecc_secded.vvp \
    | tee build/iverilog/ecc_regression.log
