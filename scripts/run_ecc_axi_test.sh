#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for tool in iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool not found in PATH" >&2
        exit 127
    fi
done

mkdir -p build/iverilog
iverilog -g2012 -Wall -s tb_ecc_mig_axi_bridge \
    -o build/iverilog/tb_ecc_mig_axi_bridge.vvp \
    rtl/ecc_secded.v \
    rtl/ecc_mig_axi_master.v \
    tb/axi128_ram_model.v \
    tb/tb_ecc_mig_axi_bridge.v

vvp build/iverilog/tb_ecc_mig_axi_bridge.vvp \
    | tee build/iverilog/ecc_axi_bridge.log
