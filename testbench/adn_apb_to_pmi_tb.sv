/*

| TEST CASE  | DATE       | AUTHOR               | DESCRIPTION                                                                                           |
|------------|------------|----------------------|-------------------------------------------------------------------------------------------------------|
| TC_RST_01  | 2026-08-23 | Ahasan Ullah Khalid  | Active-low reset assertion and default signal initialization check (`mreq == 0`, `pready == 0`)       |
| TC_WR_01   | 2026-08-23 | Ahasan Ullah Khalid  | Zero-wait write transaction (immediate `mgnt=1` and `mack=1` completion in same cycle)                |
| TC_RD_01   | 2026-08-23 | Ahasan Ullah Khalid  | Zero-wait read transaction with return read-data propagation verification                             |
| TC_GNT_DLY | 2026-08-23 | Ahasan Ullah Khalid  | PMI grant delay test: APB stall & PMI request hold stability check while waiting for `mgnt` (`S_REQ`) |
| TC_ACK_DLY | 2026-08-23 | Ahasan Ullah Khalid  | PMI ack delay test: Multi-cycle response latency after grant acceptance (`S_WAIT_ACK`)                |
| TC_ERR_01  | 2026-08-23 | Ahasan Ullah Khalid  | Error response check: Verification of `mrsp=1` propagation to `pslverr=1` upon transaction completion |
| TC_B2B_01  | 2026-08-23 | Ahasan Ullah Khalid  | Back-to-back backpressure test with variable grant/ack latency sequences                              |
| TC_STRB_01 | 2026-08-23 | Ahasan Ullah Khalid  | Byte strobe mapping check: Ensure `pstrb` is mapped on writes and forced to `'0` during reads         |
| TC_ALL     | 2026-08-23 | Ahasan Ullah Khalid  | Default regression suite executing all test scenarios sequentially (`TC_RST_01` through `TC_STRB_01`) |

| REVISION  | DATE       | AUTHOR              | DESCRIPTION                                           |
|-----------|------------|---------------------|-------------------------------------------------------|
| 0.1       | 2026-08-23 | Ahasan Ullah Khalid | Initial version                                       |
| 1.0       | 2026-08-23 | Ahasan Ullah Khalid | Stable release                                        |

Author : Ahasan Ullah Khalid (aukhalid02@gmail.com)
This file is part of ADN-VLSI/adn_apb
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

module adn_apb_to_pmi_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // bring in the testbench essentials functions and macros
  `include "vip/adn_common_tb_headers.sv"
  `include "apb/typedef.svh"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int AddrWidth = 32;
  localparam int DataWidth = 32;
  localparam int StrbWidth = DataWidth / 8;
  localparam time CLKPeriod = 10ns;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `APB_T(apb, AddrWidth, DataWidth)

  typedef struct packed {
    logic [AddrWidth-1:0] maddr;
    logic                 mwe;
    logic [DataWidth-1:0] mwdata;
    logic [StrbWidth-1:0] mstrb;
    logic                 mreq;
  } pmi_req_t;

  typedef struct packed {
    logic                 mgnt;
    logic                 mack;
    logic [DataWidth-1:0] mrdata;
    logic                 mrsp;
  } pmi_rsp_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                     clk;
  logic                     rst_n;

  apb_req_t                 apb_req;
  apb_rsp_t                 apb_rsp;

  pmi_req_t                 pmi_req;
  pmi_rsp_t                 pmi_rsp;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit                       is_clk_edge_aligned;
  logic     [AddrWidth-1:0] exp_pmi_addr;
  logic                     exp_pmi_we;
  logic     [DataWidth-1:0] exp_pmi_wdata;
  logic     [StrbWidth-1:0] exp_pmi_strb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  adn_apb_to_pmi #(
      .apb_req_t(apb_req_t),
      .apb_rsp_t(apb_rsp_t),
      .pmi_req_t(pmi_req_t),
      .pmi_rsp_t(pmi_rsp_t)
  ) u_dut (
      .clk_i    (clk),
      .rst_ni   (rst_n),
      .apb_req_i(apb_req),
      .apb_rsp_o(apb_rsp),
      .pmi_req_o(pmi_req),
      .pmi_rsp_i(pmi_rsp)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic start_clock();
    fork
      forever #(CLKPeriod / 2) clk <= ~clk;
    join_none
    @(posedge clk);
  endtask

  task automatic apply_reset();
    rst_n   <= '0;
    apb_req <= '0;
    pmi_rsp <= '0;
    repeat (2) @(posedge clk);
    rst_n <= '1;
    @(posedge clk);
  endtask

  // Master APB Transfer Driver
  task automatic apb_transfer(input logic [AddrWidth-1:0] addr, input logic write,
                              input logic [DataWidth-1:0] wdata, input logic [StrbWidth-1:0] strb,
                              output logic [DataWidth-1:0] rdata, output logic slverr);
    // Setup Phase
    wait (is_clk_edge_aligned);
    apb_req.psel    <= 1'b1;
    apb_req.penable <= 1'b0;
    apb_req.paddr   <= addr;
    apb_req.pwrite  <= write;
    apb_req.pwdata  <= wdata;
    apb_req.pstrb   <= strb;
    @(posedge clk);

    // Access Phase
    apb_req.penable <= 1'b1;
    @(posedge clk);

    // Wait for pready response
    while (!apb_rsp.pready) begin
      @(posedge clk);
    end

    rdata  = apb_rsp.prdata;
    slverr = apb_rsp.pslverr;

    // Clear Bus
    apb_req <= '0;
    @(posedge clk);
  endtask

  // PMI Slave Responder Task
  task automatic pmi_slave_respond(input int gnt_delay, input int ack_delay,
                                   input logic [DataWidth-1:0] rdata, input logic resp_err);
    fork
      begin
        // Wait for request
        while (!pmi_req.mreq) @(posedge clk);

        // Grant delay
        if (gnt_delay > 0) begin
          pmi_rsp.mgnt <= 1'b0;
          repeat (gnt_delay) @(posedge clk);
        end
        pmi_rsp.mgnt <= 1'b1;

        if (ack_delay == 0) begin
          // Immediate ACK
          pmi_rsp.mack   <= 1'b1;
          pmi_rsp.mrdata <= rdata;
          pmi_rsp.mrsp   <= resp_err;
          @(posedge clk);
          pmi_rsp <= '0;
        end else begin
          @(posedge clk);
          pmi_rsp.mgnt <= 1'b0;
          repeat (ack_delay - 1) @(posedge clk);
          pmi_rsp.mack   <= 1'b1;
          pmi_rsp.mrdata <= rdata;
          pmi_rsp.mrsp   <= resp_err;
          @(posedge clk);
          pmi_rsp <= '0;
        end
      end
    join_none
  endtask

  task automatic start_checking();
    fork
      forever
      @(posedge clk) begin
        #1ps;  // Sample post-clock edge updates

        // Check 1: Mapping Verification during Request
        if (rst_n && pmi_req.mreq) begin
          if (pmi_req.maddr === apb_req.paddr &&
              pmi_req.mwe   === apb_req.pwrite &&
              pmi_req.mwdata === apb_req.pwdata) begin
            note_case(1);
          end else begin
            note_case(0);
            $display("[%s] [FAIL] PMI Request payload mismatch! [%0t]", test_name, $realtime);
          end

          // Check 2: Strobe Mask Rule (Write passes strb, Read forces 0)
          if (apb_req.pwrite ? (pmi_req.mstrb === apb_req.pstrb) : (pmi_req.mstrb === '0)) begin
            note_case(1);
          end else begin
            note_case(0);
            $display("[%s] [FAIL] PMI Strobe mapping rule violated! [%0t]", test_name, $realtime);
          end
        end

        // Check 3: Reset Check
        if (!rst_n) begin
          if (pmi_req === '0 && apb_rsp === '0) begin
            note_case(1);
          end else begin
            note_case(0);
            $display("[%s] [FAIL] Outputs non-zero during active reset! [%0t]", test_name,
                     $realtime);
          end
        end
      end
    join_none
  endtask

  task automatic run_tc_rst_01();
    apply_reset();
  endtask

  task automatic run_tc_wr_01();
    logic [DataWidth-1:0] rdata;
    logic slverr;
    apply_reset();

    pmi_slave_respond(.gnt_delay(0), .ack_delay(0), .rdata('0), .resp_err(1'b0));
    apb_transfer(32'hA000_1000, 1'b1, 32'hDEAD_BEEF, 4'b1111, rdata, slverr);

    if (slverr === 1'b0) note_case(1);
    else begin
      note_case(0);
      $display("[%s] [FAIL] Unexpected slverr asserted on write! [%0t]", test_name, $realtime);
    end
  endtask

  task automatic run_tc_rd_01();
    logic [DataWidth-1:0] rdata;
    logic slverr;
    apply_reset();

    pmi_slave_respond(.gnt_delay(0), .ack_delay(0), .rdata(32'hCAFE_BABE), .resp_err(1'b0));
    apb_transfer(32'hB000_2000, 1'b0, '0, 4'b0000, rdata, slverr);

    if (rdata === 32'hCAFE_BABE && slverr === 1'b0) note_case(1);
    else begin
      note_case(0);
      $display("[%s] [FAIL] Read Data Mismatch! Got: 0x%08x [%0t]", test_name, rdata, $realtime);
    end
  endtask

  task automatic run_tc_gnt_dly();
    logic [DataWidth-1:0] rdata;
    logic slverr;
    apply_reset();

    pmi_slave_respond(.gnt_delay(4), .ack_delay(0), .rdata('0), .resp_err(1'b0));
    apb_transfer(32'hC000_3000, 1'b1, 32'h1234_5678, 4'b1111, rdata, slverr);
  endtask

  task automatic run_tc_ack_dly();
    logic [DataWidth-1:0] rdata;
    logic slverr;
    apply_reset();

    pmi_slave_respond(.gnt_delay(0), .ack_delay(3), .rdata(32'h55AA_55AA), .resp_err(1'b0));
    apb_transfer(32'hD000_4000, 1'b0, '0, 4'b0000, rdata, slverr);

    if (rdata === 32'h55AA_55AA) note_case(1);
    else note_case(0);
  endtask

  task automatic run_tc_err_01();
    logic [DataWidth-1:0] rdata;
    logic slverr;
    apply_reset();

    pmi_slave_respond(.gnt_delay(1), .ack_delay(1), .rdata('0), .resp_err(1'b1));
    apb_transfer(32'hE000_5000, 1'b1, 32'hBAAD_F00D, 4'b1111, rdata, slverr);

    if (slverr === 1'b1) note_case(1);
    else begin
      note_case(0);
      $display("[%s] [FAIL] Expected pslverr=1 on PMI mrsp=1 error! [%0t]", test_name, $realtime);
    end
  endtask

  task automatic run_tc_b2b_01();
    logic [DataWidth-1:0] rdata;
    logic slverr;
    apply_reset();

    // 1st Transfer: Write with 1 grant delay, 2 ack delay
    pmi_slave_respond(.gnt_delay(1), .ack_delay(2), .rdata('0), .resp_err(1'b0));
    apb_transfer(32'h1000, 1'b1, 32'h1111_2222, 4'b1111, rdata, slverr);

    // 2nd Transfer: Immediate Read
    pmi_slave_respond(.gnt_delay(0), .ack_delay(0), .rdata(32'h3333_4444), .resp_err(1'b0));
    apb_transfer(32'h2000, 1'b0, '0, 4'b0000, rdata, slverr);

    if (rdata === 32'h3333_4444) note_case(1);
    else note_case(0);
  endtask

  task automatic run_tc_strb_01();
    logic [DataWidth-1:0] rdata;
    logic slverr;
    apply_reset();

    // Sparse strobe write
    pmi_slave_respond(.gnt_delay(0), .ack_delay(0), .rdata('0), .resp_err(1'b0));
    apb_transfer(32'hF000_0000, 1'b1, 32'hAABB_CCDD, 4'b1001, rdata, slverr);

    // Read strobe mask check
    pmi_slave_respond(.gnt_delay(0), .ack_delay(0), .rdata(32'h0), .resp_err(1'b0));
    apb_transfer(32'hF000_0004, 1'b0, '0, 4'b1111, rdata, slverr);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Clock edge alignment helper flag
  always @(posedge clk) begin
    is_clk_edge_aligned <= rst_n;
    #1ns;
    is_clk_edge_aligned <= '0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    // Signal initialization
    clk     = '0;
    rst_n   = '0;
    apb_req = '0;
    pmi_rsp = '0;

    start_clock();
    start_checking();

    // Execute requested test scenario
    case (test_name)
      "TC_RST_01":  run_tc_rst_01();
      "TC_WR_01":   run_tc_wr_01();
      "TC_RD_01":   run_tc_rd_01();
      "TC_GNT_DLY": run_tc_gnt_dly();
      "TC_ACK_DLY": run_tc_ack_dly();
      "TC_ERR_01":  run_tc_err_01();
      "TC_B2B_01":  run_tc_b2b_01();
      "TC_STRB_01": run_tc_strb_01();
      "TC_ALL": begin
        run_tc_rst_01();
        run_tc_wr_01();
        run_tc_rd_01();
        run_tc_gnt_dly();
        run_tc_ack_dly();
        run_tc_err_01();
        run_tc_b2b_01();
        run_tc_strb_01();
      end

      default: begin
        $fatal(1, "Unrecognized test_name '%s'", test_name);
      end
    endcase

    #100ns;
    $finish;
  end

endmodule
