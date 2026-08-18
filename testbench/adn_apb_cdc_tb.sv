/*

| TEST CASE | DATE | AUTHOR | DESCRIPTION |
|-----------|------------|-----------------|-------------------------------------------------------| 
| TC_001 | 2026-08-09 | Shuparna Haque | Apply Reset Test                                     |
| TC_002 | 2026-08-09 | Shuparna Haque | Single Write then Read                               |
| TC_003 | 2026-08-06 | Shuparna Haque | Read-only propagation                                |
| TC_004 | 2026-08-06 | Shuparna Haque | Write then Read with a different mst/slv clock ratio |
| TC_005 | 2026-08-18 | Shuparna Haque | Rapid overlapping writes, only one must be accepted  |

| REVISION | DATE | AUTHOR | DESCRIPTION |
|----------|------------|-----------------|--------------------------------------------------------|
| 1.0 | 2026-08-06 | Shuparna Haque | Initial version                 |
| 1.1 | 2026-08-06 | Shuparna Haque | Updated test cases and fixes    |
| 1.2 | 2026-08-18 | Shuparna Haque  | Updated and finalized version  |

Author : Shuparna Haque (sheikhshuparna3108@gmail.com)
This file is part of ADN-VLSI/adn_apb
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_apb_cdc_tb;
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"
  `include "apb/typedef.svh"
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int TIMEOUT_CYCLES = 50;  
 
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  `APB_REQ_T(apb, ADDR_WIDTH, DATA_WIDTH)
  `APB_RESP_T(apb, DATA_WIDTH)
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Clock and reset
  logic mst_clk, mst_arst_n;
  logic slv_clk, slv_arst_n;
 
  // Master-side signals
  apb_req_t  mst_req;
  apb_resp_t mst_resp;
 
  // Slave-side signals
  apb_req_t  slv_req;
  apb_resp_t slv_resp;
 
  // Expected response storage
  apb_resp_t expected_resp;
 
 
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACES
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLASSES
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  adn_apb_cdc_fifo #(
      .apb_req_t  (apb_req_t),
      .apb_resp_t (apb_resp_t),
      .SYNC_STAGES(2)
  ) dut (
      .mst_clk_i  (mst_clk),
      .mst_arst_ni(mst_arst_n),
      .mst_req_i  (mst_req),
      .mst_resp_o (mst_resp),
      .slv_req_o  (slv_req),
      .slv_clk_i  (slv_clk),
      .slv_arst_ni(slv_arst_n),
      .slv_resp_i (slv_resp)
  );
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  task automatic apply_reset();
    mst_arst_n = 0;
    slv_arst_n = 0;
    mst_req    = '0;
    slv_resp   = '0;
    #20;
    mst_arst_n = 1;
    slv_arst_n = 1;
    @(posedge mst_clk);
    @(posedge slv_clk);
  endtask
 
 
task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
  bit pass = 1;
  int unsigned wait_cycles;

  @(posedge mst_clk);
  mst_req.psel    <= 1;
  mst_req.penable <= 0;
  mst_req.paddr   <= addr;
  mst_req.pwdata  <= data;
  mst_req.pwrite  <= 1'b1;
  mst_req.pstrb   <= '1;
  mst_req.pprot   <= 3'b000;

  @(posedge mst_clk);
  mst_req.penable <= 1;

  wait_cycles = 0;
  while (!(slv_req.psel && slv_req.penable) && wait_cycles < TIMEOUT_CYCLES) begin
    @(posedge slv_clk);
    wait_cycles++;
  end

  if (wait_cycles >= TIMEOUT_CYCLES) begin
    $display("Error: write to addr %h never reached the slave side (timed out)", addr);
    pass = 0;
  end

  if (slv_req.paddr !== addr)  begin $display("Error: addr mismatch..."); pass = 0; end
  if (slv_req.pwdata !== data) begin $display("Error: data mismatch..."); pass = 0; end
  if (!slv_req.psel || !slv_req.penable || !slv_req.pwrite) begin
    $display("Error: control signals not asserted correctly");
    pass = 0;
  end

  slv_resp.pready  <= 1;
  slv_resp.pslverr <= 0;
  @(posedge slv_clk);
  slv_resp.pready  <= 0;

  note_case(pass);
  if (pass) $display("PASS: WRITE propagated correctly at addr %h , data : %h ", addr,data);
  else      $display("FAIL: WRITE propagation error at addr %h, data : %h ", addr,data);

  @(posedge mst_clk);
  mst_req <= '0;
endtask
 
  task automatic apb_read(input logic [31:0] addr, input logic [31:0] data);
    bit pass = 1;
    int unsigned wait_cycles;
 
    // SETUP phase 
    @(posedge mst_clk);
    mst_req.psel    <= 1;
    mst_req.penable <= 0;
    mst_req.paddr   <= addr;
    mst_req.pwrite  <= 0;
    mst_req.pstrb   <= '0;
    mst_req.pprot   <= 3'b000;
 
    // ACCESS phase
    @(posedge mst_clk);
    mst_req.penable <= 1;
 
    wait_cycles = 0;
    while (!(slv_req.psel && slv_req.penable) && wait_cycles < TIMEOUT_CYCLES) begin
      @(posedge slv_clk);
      wait_cycles++;
    end
 
    if (wait_cycles >= TIMEOUT_CYCLES) begin
      $display("Error: read from addr %h never reached the slave side (timed out)", addr);
      pass = 0;
    end
 
    // Check slave side sees the same
    if (slv_req.paddr !== addr) begin
      $display("Error: addr mismatch. Expected %h, Got %h", addr, slv_req.paddr);
      pass = 0;
    end
    if (slv_req.pwrite !== 0) begin
      $display("Error: expected read, got write");
      pass = 0;
    end
 
    slv_resp.pready  <= 1;
    slv_resp.pslverr <= 0;
    slv_resp.prdata  <= data;
 
    wait_cycles = 0;
    while (!mst_resp.pready && wait_cycles < TIMEOUT_CYCLES) begin
      @(posedge mst_clk);
      wait_cycles++;
    end
 
    if (wait_cycles >= TIMEOUT_CYCLES) begin
      $display("Error: read response for addr %h never reached the master side (timed out)", addr);
      pass = 0;
    end
 
    if (mst_resp.prdata !== data) begin
      $display("Error: response data mismatch. Expected %h, Got %h", data, mst_resp.prdata);
      pass = 0;
    end

    if (!mst_resp.pready) begin
      $display("Error: master did not see pready");
      pass = 0;
    end
 
    note_case(pass);
    if (pass) $display("PASS: READ propagated correctly at addr %h , data : %h ", addr,data);
    else $display("FAIL: READ propagation error at addr %h , data : %h ", addr,data);
 
    mst_req  <= '0;
    slv_resp <= '0;
  endtask
 
    task automatic different_clock();
    //Master: 24ns period (was 10ns)
    // Slave: 50ns period (was 14ns)
    fork : force_clk_block
      begin
        force mst_clk = 0;
        forever #12 force mst_clk = ~mst_clk;
      end
      begin
        force slv_clk = 0;
        forever #25 force slv_clk = ~slv_clk;
      end
    join_none

    #50;
    apb_write(32'h0000_4000, 32'hFACE);
    apb_read (32'h0000_4000, 32'hFACE);

    disable force_clk_block;
    release mst_clk;
    release slv_clk;
  endtask

    task automatic apb_write_multi_attempt();
    localparam int NUM_ATTEMPTS = 4;
    logic [31:0] addrs[NUM_ATTEMPTS] = '{32'h0000_5000, 32'h0000_5004, 32'h0000_5008, 32'h0000_500C};
    logic [31:0] datas[NUM_ATTEMPTS] = '{32'hAAA0, 32'hBBB1, 32'hCCC2, 32'hDDD3};
    int unsigned wait_cycles;
    int unsigned seen_count;
    bit pass;
 
    @(posedge mst_clk);
    mst_req.psel    <= 1;
    mst_req.penable <= 0;
    mst_req.paddr   <= addrs[0];
    mst_req.pwdata  <= datas[0];
    mst_req.pwrite  <= 1'b1;
    mst_req.pstrb   <= '1;
    mst_req.pprot   <= 3'b000;
 
    @(posedge mst_clk);
    mst_req.penable <= 1;
 
    // Keep overwriting addr/data on further master edges without ever
    // waiting for pready -- illegal APB master behavior on purpose, to
    // see whether the bridge only latches the first one.
    for (int i = 1; i < NUM_ATTEMPTS; i++) begin
      @(posedge mst_clk);
      mst_req.paddr  <= addrs[i];
      mst_req.pwdata <= datas[i];
    end
 
    wait_cycles = 0;
    while (!(slv_req.psel && slv_req.penable) && wait_cycles < TIMEOUT_CYCLES) begin
      @(posedge slv_clk);
      wait_cycles++;
    end
 
    if (wait_cycles >= TIMEOUT_CYCLES) begin
      $display("Error: none of the attempted writes ever reached the slave (timed out)");
      pass = 0;
    end else begin
      $display("INFO: slave first saw addr=%h data=%h", slv_req.paddr, slv_req.pwdata);
      pass = 1;
    end
 
    slv_resp.pready  <= 1;
    slv_resp.pslverr <= 0;
    @(posedge slv_clk);
    slv_resp.pready  <= 0;
 
    // Watch for any *additional* transaction arriving on its own --
    // that would mean more than one of our rapid writes got queued.
    seen_count = 1;
    repeat (10) begin
      @(posedge slv_clk);
      if (slv_req.psel && slv_req.penable) begin
        seen_count++;
        $display("INFO: slave saw an ADDITIONAL transaction: addr=%h data=%h (not expected for APB)",
                  slv_req.paddr, slv_req.pwdata);
        slv_resp.pready <= 1;
        @(posedge slv_clk);
        slv_resp.pready <= 0;
      end
    end
 
    pass = pass && (seen_count == 1);
    note_case(pass);
    if (pass) $display("PASS: only 1 write reached the slave, as APB requires");
    else      $display("FAIL: %0d writes reached the slave instead of 1", seen_count);
 
    @(posedge mst_clk);
    mst_req <= '0;
  endtask
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
 
 
  initial begin
    apply_reset();
 
    case (test_name)
      "TC_001": begin
        apb_write(32'h0000_1000, 32'hDEAD);
        apply_reset();
        apb_write(32'h0000_1000, 32'hBEEF);
      end
 
      "TC_002": begin
        apb_write(32'h0000_2000, 32'hCAFE);
        apb_read(32'h0000_2000, 32'hCAFE);
      end
 
      "TC_003": begin
        apb_read(32'h0000_3000, 32'h1234);
      end
      
      "TC_004": begin
        different_clock();
      end

      "TC_005": begin
        apb_write_multi_attempt();
      end

      default: begin
        $display("\033[1;31mError: Unknown test case '%s'\033[0m", test_name);
      end
    endcase
 
    $finish;
  end
 
  initial begin
    mst_clk = 0;
    forever #5 mst_clk = ~mst_clk;
  end
  initial begin
    slv_clk = 0;
    forever #7 slv_clk = ~slv_clk;
  end
 

endmodule

