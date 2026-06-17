# APB UART FIFO UVM Lab

This repository is a small SystemVerilog/UVM lab project for an APB-controlled
UART model with asynchronous FIFO buffers.

The project is rebuilt in small steps:

1. RTL blocks
2. simulation top and interfaces
3. APB and UART UVM agents
4. scoreboard, coverage, and tests
5. scripts, sample logs, and verification notes

The UART model is intentionally lightweight. It is meant for practicing UVM
testbench structure and APB peripheral verification, not for replacing a
production UART IP.
