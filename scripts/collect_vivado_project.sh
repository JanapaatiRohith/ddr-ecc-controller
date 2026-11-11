#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
WIN_PROJECT="/mnt/c/Users/vrnsr/arty_ddr_fpga"
ARCHIVE="$WIN_PROJECT/v25ecc/release/arty_ecc25_full_project.zip"
RECREATE="$WIN_PROJECT/v25ecc/release/arty_ecc25_recreate.tcl"
MIG_PRJ="$WIN_PROJECT/board/mig.prj"

if [[ ! -f "$ARCHIVE" ]]; then
  echo "Missing $ARCHIVE"
  echo "First open arty_ecc25 in Vivado 2025.2 and source scripts/archive_current_vivado_project.tcl."
  exit 2
fi
mkdir -p "$REPO_ROOT/vivado/current_project_archive" "$REPO_ROOT/board"
install -m 0644 "$ARCHIVE" "$REPO_ROOT/vivado/current_project_archive/arty_ecc25_full_project.zip"
if [[ -f "$RECREATE" ]]; then
  install -m 0644 "$RECREATE" "$REPO_ROOT/vivado/current_project_archive/arty_ecc25_recreate.tcl"
fi
if [[ -f "$MIG_PRJ" ]]; then
  install -m 0644 "$MIG_PRJ" "$REPO_ROOT/board/mig.prj"
else
  echo "NOTE: $MIG_PRJ not found; check/copy the board MIG configuration file manually."
fi
echo "Collected current Vivado archive into: $REPO_ROOT/vivado/current_project_archive"
