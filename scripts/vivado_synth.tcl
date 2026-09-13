set root_dir [file normalize [file join [file dirname [info script]] ..]]
cd $root_dir
file mkdir reports/synthesis

if {![info exists ::env(APB_UART_PART)]} { error "Run through run_vivado_synth.ps1 to resolve the toolchain" }
set target_part $::env(APB_UART_PART)
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
read_xdc constraints/synth_ooc.xdc
synth_design -top apb_uart -part $target_part -mode out_of_context -flatten_hierarchy rebuilt

set meta_pins [get_pins -hier -quiet -regexp {.*(cfg_req_meta_reg|cfg_ack_meta_reg|rx_full_pclk_q1_reg|rx_frame_err_pclk_q1_reg|tx_empty_pclk_q1_reg)/D}]
if {[llength $meta_pins] != 5} { error "Unexpected single-bit CDC endpoint count" }
set_false_path -to $meta_pins

# Data bundles must settle within one destination cycle, before their
# two-stage synchronized request/pointer can authorize a capture. These max
# delays are not shadowed by set_clock_groups or a blanket false path.
set holds [get_cells -hier -quiet -filter {NAME =~ u_cfg_cdc/cfg_*_hold_reg*}]
set cfg_targets [get_cells -hier -quiet -filter {NAME =~ u_cfg_cdc/*_uart_cfg_reg*}]
set tx_mem [get_cells -hier -quiet -filter {NAME =~ u_tx_fifo/mem_reg*}]
set rx_mem [get_cells -hier -quiet -filter {NAME =~ u_rx_fifo/mem_reg*}]
set tx_capture [get_cells -hier -quiet -filter {NAME =~ u_serial_core/u_uart_tx/shifter_reg*}]
foreach collection [list $holds $cfg_targets $tx_mem $rx_mem $tx_capture] {
  if {[llength $collection] == 0} { error "Missing bounded-data CDC endpoint" }
}
set_max_delay -datapath_only 40.0 -from $holds -to $cfg_targets
set_max_delay -datapath_only 40.0 -from $tx_mem -to $tx_capture
set_max_delay -datapath_only 10.0 -from $rx_mem -to [get_ports {prdata[*]}]

# Gray pointers must arrive with a bounded inter-bit skew. Unlike blanket
# clock grouping, this is an explicit bus-skew requirement for implementation.
foreach fifo {u_tx_fifo u_rx_fifo} {
  foreach pointer {rgray wgray} {
    if {$pointer eq "rgray"} { set target "rgray_wclk_q1" } else { set target "wgray_rclk_q1" }
    set binary [string map {gray bin} $pointer]
    set from [get_cells -hier -quiet -regexp ".*${fifo}/(${pointer}|${binary})_reg\\\[.*"]
    set to [get_cells -hier -quiet -regexp ".*${fifo}/${target}_reg\\\[.*"]
    if {[llength $from] == 0 || [llength $to] == 0} { error "Missing Gray CDC endpoint $fifo/$pointer" }
    set_bus_skew 10.0 -from $from -to $to
    set_max_delay -datapath_only 10.0 -from $from -to $to
  }
}

set retired_from [get_cells -hier -quiet -regexp {.*u_tx_completion/retired_(gray|bin)_reg\[.*}]
set retired_to [get_cells -hier -quiet -regexp {.*u_tx_completion/retired_q1_reg\[.*}]
if {[llength $retired_from] == 0 || [llength $retired_to] != 6} { error "Missing TX completion Gray endpoints" }
set_bus_skew 10.0 -from $retired_from -to $retired_to
set_max_delay -datapath_only 10.0 -from $retired_from -to $retired_to

report_utilization -file reports/synthesis/utilization.rpt
report_timing_summary -delay_type max -max_paths 10 -file reports/synthesis/timing_summary.rpt
report_cdc -details -file reports/synthesis/cdc.rpt
report_exceptions -file reports/synthesis/exceptions.rpt
report_bus_skew -file reports/synthesis/bus_skew.rpt
write_checkpoint -force reports/synthesis/post_synth.dcp

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
set overall_paths [get_timing_paths -quiet -max_paths 1]
if {[llength $overall_paths] == 0} { error "No constrained setup paths" }
set overall_slack [format "%.3f" [get_property SLACK [lindex $overall_paths 0]]]
set out [open reports/synthesis/qor.json w]
puts $out "\{"
puts $out "  \"generatedAt\": \"[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]\","
puts $out "  \"tool\": \"Vivado [version -short]\","
puts $out "  \"flow\": \"out-of-context RTL synthesis\","
puts $out "  \"part\": \"$target_part\","
puts $out "  \"top\": \"apb_uart\","
puts $out "  \"overallSetupWnsNs\": $overall_slack,"
puts $out "  \"constraints\": \{\"pclkPeriodNs\": 10.0, \"uartClockPeriodNs\": 40.0, \"clockGroupsAsynchronous\": false, \"cdcExceptions\": \"endpoint-specific control false paths and bounded datapath max delays\"\},"
puts $out "  \"utilization\": \{\"lutCells\": [cell_count {REF_NAME =~ LUT*}], \"sequentialCells\": [cell_count {IS_SEQUENTIAL == 1}], \"distributedRamCells\": [cell_count {REF_NAME =~ RAM*}]\},"
puts $out "  \"timing\": \{"
puts $out "    \"pclk\": \{\"wnsNs\": $pclk_slack, \"estimatedFmaxMHz\": [estimated_fmax 10.0 $pclk_slack]\},"
puts $out "    \"uartClock\": \{\"wnsNs\": $uart_slack, \"estimatedFmaxMHz\": [estimated_fmax 40.0 $uart_slack]\}"
puts $out "  \},"
puts $out "  \"evidenceBoundary\": \"Generic Artix-7 post-synthesis evidence only; no implementation, bitstream, board measurement, or commercial CDC signoff claim.\""
puts $out "\}"
close $out
puts "SYNTH_EVIDENCE_PASS"
