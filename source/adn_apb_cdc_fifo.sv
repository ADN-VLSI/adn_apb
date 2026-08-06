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
  // Defines internal constants for FIFO depth and pointer widths
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  // Custom structures for internal FIFO data packing
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  // Internal wires and registers for CDC logic, pointers, and FIFO storage
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  // Combinational logic for APB handshake and status flags
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES
  // Instances of synchronizers (e.g., Gray code converters, multi-stage flip-flops)
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  // Clocked logic for FIFO read/write pointers and data buffer updates
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  // Sanity checks for parameter configuration
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  // Functions for calculating Gray code or FIFO status
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  // Formal properties to verify CDC constraints and FIFO overflow/underflow conditions
  //////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef SIMULATION
  initial begin
    if (DATA_WIDTH > 2) begin
      $display("\033[1;33m%m DATA_WIDTH\033[0m");
    end
  end
`endif  // SIMULATION

endmodule
