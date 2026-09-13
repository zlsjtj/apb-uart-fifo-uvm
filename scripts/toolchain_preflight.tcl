if {![info exists ::env(APB_UART_PART)]} { error "Missing APB_UART_PART" }
set part $::env(APB_UART_PART)
if {[llength [get_parts -quiet $part]] != 1} { error "Requested part is not installed: $part" }
puts "TOOLCHAIN_PART_PASS $part"
puts "TOOLCHAIN_VIVADO_VERSION [version -short]"
