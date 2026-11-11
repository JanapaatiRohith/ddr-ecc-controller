# Run this in the Vivado 2025.2 Tcl Console while arty_ecc25 is the current project.
# It archives the active XPR, source RTL, XDC constraints, IP configuration and project settings.
# Run results are excluded to keep the GitHub archive reasonably sized; they can be regenerated.
set proj_dir "C:/Users/vrnsr/arty_ddr_fpga/v25ecc"
set out_dir  [file join $proj_dir release]
set temp_dir "C:/VivadoArchiveTemp"
file mkdir $out_dir
file mkdir $temp_dir

if {[current_project] eq "" || [get_property NAME [current_project]] ne "arty_ecc25"} {
    error "Open the final arty_ecc25 project in Vivado 2025.2 before archiving."
}

archive_project -force -exclude_run_results -include_config_settings -temp_dir $temp_dir [file join $out_dir arty_ecc25_full_project.zip]

write_project_tcl -force [file join $out_dir arty_ecc25_recreate.tcl]
puts "ARCHIVE: [file join $out_dir arty_ecc25_full_project.zip]"
puts "RECREATE TCL: [file join $out_dir arty_ecc25_recreate.tcl]"
