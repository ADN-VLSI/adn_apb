/*

### Purpose
This module implements an asynchronous FIFO bridge for the APB (Advanced Peripheral Bus) protocol, enabling reliable data transfer between two clock domains (master and slave). It handles clock domain crossing (CDC) synchronization to ensure data integrity and timing closure when the APB master and slave operate on independent clock frequencies.

### Use Case
This module is primarily used in SoC designs where an APB master (e.g., a CPU or DMA controller) needs to communicate with a peripheral residing in a different clock domain. By acting as a bridge, it buffers APB transactions, preventing metastability issues and ensuring that control signals and data remain coherent despite the asynchronous nature of the two clock trees.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Annim Jannat    | Initial version                                        |
| 1.0      | YYYY-MM-DD | Annim Jannat    | Stable release                                         |

Author : Annim Jannat (jannatannim@gmail.com)
This file is part of ADN-VLSI/adn_apb
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

// `include "include/apb/typedef.svh"
// package apb_pkg;
//  `APB_REQ_T(apb, 32, 32)
//  `APB_RESP_T(apb, 32)
// endpackage

module adn_apb_cdc_fifo
// import apb_pkg::*;
#(
    // PARAMETERS
    parameter type apb_req_t   = logic, // APB request structure type
    parameter type apb_resp_t  = logic, // APB response structure type
    parameter int  SYNC_STAGES = 2      // Number of synchronization stages for CDC

    // LOCALPARAMS

) (
    // PORTS

    // Master-side
    input  logic         mst_clk_i,   // Master clock input
    input  logic         mst_arst_ni, // Master asynchronous reset (active low)
    input  apb_req_t     mst_req_i,   // APB request from master

    output apb_resp_t    mst_resp_o,  // APB response to master

    // Slave-side
    output apb_req_t     slv_req_o,   // APB request to slave

    input  logic         slv_clk_i,   // Slave clock input
    input  logic         slv_arst_ni, // Slave asynchronous reset (active low)
    input  apb_resp_t    slv_resp_i   // APB response from slave
);



  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCALPARAMS GENERATED
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int RESP_WIDTH = $bits(apb_resp_t);
  localparam int REQ_WIDTH = $bits(apb_req_t);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_e;
  state_e    s_state, s_state_n;
  apb_req_t  req_latch;

  apb_req_t  req_dout;
  apb_resp_t resp_dout;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  logic      req_valid, req_ready;
  logic      resp_valid;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////
  assign mst_resp_o.prdata  = resp_dout.prdata;
  assign mst_resp_o.pslverr = resp_dout.pslverr;
  assign mst_resp_o.pready  = resp_valid;


  assign slv_req_o.paddr   = req_latch.paddr;
  assign slv_req_o.pwdata  = req_latch.pwdata;
  assign slv_req_o.pwrite  = req_latch.pwrite;
  assign slv_req_o.pstrb   = req_latch.pstrb;
  assign slv_req_o.pprot   = req_latch.pprot;
  assign slv_req_o.psel    = (s_state != IDLE);
  assign slv_req_o.penable = (s_state == ACCESS);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // request FIFO

  adn_common_cdc_fifo #(
      .DATA_WIDTH (REQ_WIDTH),
      .FIFO_SIZE  (FIFO_SIZE),
      .SYNC_STAGES(SYNC_STAGES)
  ) u_req_fifo (
      .data_in_i       (mst_req_i),
      .data_in_valid_i (mst_req_i.psel && mst_req_i.penable),
      .data_in_ready_o (),
      .data_in_arst_ni (mst_arst_ni),
      .data_in_clk_i   (mst_clk_i),
      .data_in_count_o (),
      .data_out_o      (req_dout),
      .data_out_valid_o(req_valid),
      .data_out_ready_i(req_ready),
      .data_out_arst_ni(slv_arst_ni),
      .data_out_clk_i  (slv_clk_i),
      .data_out_count_o()
  );

  // response FIFO

  adn_common_cdc_fifo #(
      .DATA_WIDTH (RESP_WIDTH),
      .FIFO_SIZE  (FIFO_SIZE),
      .SYNC_STAGES(SYNC_STAGES)
  ) u_resp_fifo (
      .data_in_i       (slv_resp_i),
      .data_in_valid_i (s_state == ACCESS && slv_resp_i.pready),
      .data_in_ready_o (),
      .data_in_arst_ni (slv_arst_ni),
      .data_in_clk_i   (slv_clk_i),
      .data_in_count_o (),
      .data_out_o      (resp_dout),
      .data_out_valid_o(resp_valid),
      .data_out_ready_i(1'b1),
      .data_out_arst_ni(mst_arst_ni),
      .data_out_clk_i  (mst_clk_i),
      .data_out_count_o()
  );


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  assign req_ready = (s_state == IDLE) && req_valid;  // slave fsm

  always_comb begin
    s_state_n = s_state;
    case (s_state)
      IDLE:    s_state_n = req_ready ? SETUP  : IDLE;
      SETUP:   s_state_n = ACCESS;
      ACCESS:  s_state_n = slv_resp_i.pready ? IDLE   : ACCESS;
      default: s_state_n = IDLE;
    endcase
  end

  always_ff @(posedge slv_clk_i or negedge slv_arst_ni) begin
    if (!slv_arst_ni) begin
      s_state   <= IDLE;
      req_latch <= '0;
    end else begin
      s_state <= s_state_n;
      if (req_ready) req_latch <= req_dout;
    end
  end

endmodule
