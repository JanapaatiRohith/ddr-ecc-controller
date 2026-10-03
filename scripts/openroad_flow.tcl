# Template only: OpenROAD needs a real PDK/platform.
# Supply the course/lab Liberty + LEF + site/platform information before running.
#
# Example conceptual sequence:
#   read_lef <tech.lef>
#   read_lef <cells.lef>
#   read_liberty <cells.lib>
#   read_verilog ../scripts/ddr_controller_synth.v
#   link_design ddr_controller
#   initialize_floorplan ...
#   place_design
#   clock_tree_synthesis
#   global_route
#   detailed_route
#   report_checks
#   write_db ddr_controller.odb
#   write_def ddr_controller.def
#
# Do not run this file until a PDK/platform has been selected.
