// Shared APB subset: 8-bit byte address, 32-bit data, no strobes/protection.
// Compile apb_if before this package. Compile these classes only here.
package apb_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "apb_item.svh"
  `include "apb_sequencer.svh"
  `include "apb_driver.svh"
  `include "apb_monitor.svh"
  `include "apb_agent.svh"
endpackage
