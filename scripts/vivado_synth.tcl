set root_dir [file normalize [file join [file dirname [info script]] ..]]
cd $root_dir
file mkdir reports/synthesis

set target_part "xc7a35tcpg236-1"
if {[llength [get_parts -quiet $target_part]] == 0} {
  error "Requested generic evidence part $target_part is not installed"
}

set rtl_files {}
set fp [open rtl_filelist.f r]
while {[gets $fp line] >= 0} {
  set line [string trim $line]
  if {$line ne "" && ![string match "#*" $line]} {
    lappend rtl_files $line
  }
}
close $fp

read_verilog -sv $rtl_files
synth_design -top apb_uart -part $target_part -flatten_hierarchy rebuilt
create_clock -name pclk -period 10.000 [get_ports pclk]
create_clock -name uart_clk -period 40.000 [get_ports uart_clk]
set_clock_groups -asynchronous -group [get_clocks pclk] -group [get_clocks uart_clk]
set_false_path -from [get_ports {presetn uart_rst_n}]

report_utilization -file reports/synthesis/utilization.rpt
report_timing_summary -delay_type max -max_paths 10 -file reports/synthesis/timing_summary.rpt
report_cdc -details -file reports/synthesis/cdc.rpt

proc cell_count {filter_expr} {
  return [llength [get_cells -hier -quiet -filter $filter_expr]]
}
proc clock_slack {clock_name} {
  set paths [get_timing_paths -quiet -from [get_clocks $clock_name] -to [get_clocks $clock_name] -max_paths 1]
  if {[llength $paths] == 0} { return "null" }
  return [format "%.3f" [get_property SLACK [lindex $paths 0]]]
}
proc estimated_fmax {period slack} {
  if {$slack eq "null"} { return "null" }
  set delay [expr {$period - double($slack)}]
  if {$delay <= 0.0} { return "null" }
  return [format "%.3f" [expr {1000.0 / $delay}]]
}

set pclk_slack [clock_slack pclk]
set uart_slack [clock_slack uart_clk]
set out [open reports/synthesis/qor.json w]
puts $out "\{"
puts $out "  \"generatedAt\": \"[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]\","
puts $out "  \"tool\": \"Vivado [version -short]\","
puts $out "  \"flow\": \"out-of-context RTL synthesis\","
puts $out "  \"part\": \"$target_part\","
puts $out "  \"top\": \"apb_uart\","
puts $out "  \"constraints\": \{\"pclkPeriodNs\": 10.0, \"uartClockPeriodNs\": 40.0, \"clockGroupsAsynchronous\": true\},"
puts $out "  \"utilization\": \{\"lutCells\": [cell_count {REF_NAME =~ LUT*}], \"sequentialCells\": [cell_count {IS_SEQUENTIAL == 1}], \"distributedRamCells\": [cell_count {REF_NAME =~ RAM*}]\},"
puts $out "  \"timing\": \{"
puts $out "    \"pclk\": \{\"wnsNs\": $pclk_slack, \"estimatedFmaxMHz\": [estimated_fmax 10.0 $pclk_slack]\},"
puts $out "    \"uartClock\": \{\"wnsNs\": $uart_slack, \"estimatedFmaxMHz\": [estimated_fmax 40.0 $uart_slack]\}"
puts $out "  \},"
puts $out "  \"evidenceBoundary\": \"Generic Artix-7 post-synthesis evidence only; no implementation, bitstream, board measurement, or commercial CDC signoff claim.\""
puts $out "\}"
close $out
puts "SYNTH_EVIDENCE_PASS"
