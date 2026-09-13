module toolchain_smoke_tb;
  initial begin
    #1;
    $display("TOOLCHAIN_SIMULATION_PASS");
    $finish;
  end
endmodule
