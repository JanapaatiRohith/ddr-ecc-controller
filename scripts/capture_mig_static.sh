#!/usr/bin/env bash
set -euo pipefail
DEFAULT_ROOT="/mnt/c/Users/vrnsr/arty_ddr_fpga/mig_example/mig_7series_0_ex"
PROJECT_ROOT="${1:-$DEFAULT_ROOT}"
OUT="${2:-$PWD/build/mig_static_snapshot.txt}"
mkdir -p "$(dirname "$OUT")"

{
  echo "MIG static source snapshot"
  echo "Captured: $(date -Is)"
  echo "Project root: $PROJECT_ROOT"
  echo
  if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "PROJECT_NOT_FOUND: $PROJECT_ROOT"
    echo "Pass the actual directory containing the .xpr file as argument 1."
    exit 0
  fi

  echo "=== Project files (.xpr, XCI, MIG wrappers, top wrappers, MIG PRJ) ==="
  find "$PROJECT_ROOT" -type f \( \
      -iname '*.xpr' -o -iname '*.xci' -o -iname 'mig_7series_0.v' -o \
      -iname 'arty_ddr_top.v' -o -iname 'example_top.v' -o -iname 'mig.prj' \
    \) -print | sort

  echo
  echo "=== MIG interface declarations and configuration properties ==="
  while IFS= read -r -d '' f; do
    case "$f" in
      *.v)
        if grep -Eq 'module[[:space:]]+mig_7series_0|app_(addr|cmd|en|rdy|wdf_data|wdf_mask|wdf_wren|wdf_end|wdf_rdy|rd_data|rd_data_valid|rd_data_end)' "$f"; then
          echo
          echo "--- VERILOG: $f ---"
          grep -nE 'module[[:space:]]+mig_7series_0|parameter[^;]*(APP|ADDR|DATA|MASK)|app_(addr|cmd|en|rdy|wdf_data|wdf_mask|wdf_wren|wdf_end|wdf_rdy|rd_data|rd_data_valid|rd_data_end)|ui_clk_sync_rst|ui_clk|init_calib_complete' "$f" | head -n 180 || true
        fi
        ;;
      *.xci)
        if grep -Eq 'mig_7series|APP_DATA_WIDTH|APP_ADDR_WIDTH|APP_MASK_WIDTH|DataWidth|BurstLength|MemoryPart|InputClkFreq|TimePeriod' "$f"; then
          echo
          echo "--- XCI: $f ---"
          grep -nEi 'APP_DATA_WIDTH|APP_ADDR_WIDTH|APP_MASK_WIDTH|DataWidth|BurstLength|MemoryPart|InputClkFreq|TimePeriod|MemoryType|ECC|AXI' "$f" | head -n 180 || true
        fi
        ;;
      *.prj)
        echo
        echo "--- MIG PRJ: $f ---"
        grep -nEi 'DataWidth|BurstLength|MemoryPart|InputClkFreq|TimePeriod|ECC|<Parameters>|<Parameter' "$f" | head -n 120 || true
        ;;
    esac
  done < <(find "$PROJECT_ROOT" -type f \( -iname '*.v' -o -iname '*.xci' -o -iname 'mig.prj' \) -print0)

  echo
  echo "=== End snapshot ==="
} 2>&1 | tee "$OUT"

echo "Snapshot saved to: $OUT"
