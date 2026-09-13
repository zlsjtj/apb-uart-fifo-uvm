`timescale 1ns/1ps
module async_fifo_random_tb;
  parameter int ADDR_WIDTH=4;
  parameter int WR_HALF=3, RD_HALF=5;
  localparam int DEPTH=1<<ADDR_WIDTH;
  logic wr_clk=0, rd_clk=0, reset_n=0;
  logic wr_rst_n, rd_rst_n, wr_en=0, rd_en=0;
  logic [7:0] wr_data=0, rd_data;
  logic wr_full, rd_empty;
  bit [7:0] expected[$];
  int written=0, read_count=0, resets=0, full_seen=0, empty_seen=0;
  int mode=0;
  always #(WR_HALF) wr_clk=~wr_clk;
  initial begin #1ns; forever #(RD_HALF) rd_clk=~rd_clk; end
  reset_sync wr_reset(wr_clk,reset_n,wr_rst_n);
  reset_sync rd_reset(rd_clk,reset_n,rd_rst_n);
  async_fifo #(.ADDR_WIDTH(ADDR_WIDTH)) dut(.*);

  // Random peers are independent of pointer/full implementations. A reference
  // queue records only accepted public writes and compares accepted reads.
  always @(negedge wr_clk) begin
    wr_en = wr_rst_n && !wr_full && (mode==1 || (mode==2 && $urandom_range(0,99)<73));
    wr_data = $urandom_range(0,255);
  end
  always @(negedge rd_clk)
    rd_en = rd_rst_n && !rd_empty && (mode==3 || (mode==2 && $urandom_range(0,99)<61));
  always @(posedge wr_clk) if (wr_rst_n) begin
    if (wr_full) full_seen++;
    if (wr_en && !wr_full) begin
      expected.push_back(wr_data);
      written++;
      if (expected.size()>DEPTH) $fatal(1,"FIFO_REFERENCE_OVERFLOW");
    end
  end
  always @(posedge rd_clk) if (rd_rst_n) begin
    if (rd_empty) empty_seen++;
    if (rd_en && !rd_empty) begin
      bit [7:0] value;
      if (expected.size()==0) $fatal(1,"FIFO_REFERENCE_UNDERFLOW");
      value=expected.pop_front();
      if (rd_data !== value) $fatal(1,"FIFO_REFERENCE_ORDER got=%h expected=%h",rd_data,value);
      read_count++;
    end
  end
  task reset_epoch();
    mode=0; reset_n=0; wr_en=0; rd_en=0;
    expected.delete(); resets++;
    #(4*(WR_HALF+RD_HALF)+1);
    reset_n=1;
    repeat(5) @(negedge wr_clk);
    repeat(5) @(negedge rd_clk);
  endtask
  task drain();
    mode=3;
    repeat((DEPTH+10)*4) @(negedge rd_clk);
    if (expected.size()!=0 || !rd_empty) $fatal(1,"FIFO_REFERENCE_DRAIN");
  endtask
  initial begin
    reset_epoch();
    for (int epoch=0; epoch<3; epoch++) begin
      mode=1;
      repeat((DEPTH+8)*2) @(negedge wr_clk);
      if (!wr_full || expected.size()!=DEPTH) $fatal(1,"FIFO_REFERENCE_FULL");
      drain();
      mode=2;
      repeat(1200+DEPTH*20) @(negedge wr_clk);
      // Shared reset while traffic is active invalidates the old queue.
      reset_epoch();
    end
    mode=2;
    repeat(1200+DEPTH*20) @(negedge wr_clk);
    drain();
    if (written<4*DEPTH || read_count<4*DEPTH || full_seen==0 || empty_seen==0)
      $fatal(1,"FIFO_REFERENCE_INSUFFICIENT_STIMULUS");
    $display("FIFO_RANDOM_PASS width=%0d clocks=%0d/%0d writes=%0d reads=%0d resets=%0d full=%0d empty=%0d",
      ADDR_WIDTH,WR_HALF,RD_HALF,written,read_count,resets,full_seen,empty_seen);
    $finish;
  end
  initial begin #2ms; $fatal(1,"FIFO_RANDOM_TIMEOUT"); end
endmodule
