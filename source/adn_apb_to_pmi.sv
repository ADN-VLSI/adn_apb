/*
This module acts as a bridge between the APB (Advanced Peripheral Bus) and the PMI (Parallel Memory Interface) protocols. It translates APB read/write transactions into PMI requests, managing the handshake signals and state transitions required to ensure data integrity and protocol compliance.

### Use Case
The `adn_apb_to_pmi` module is designed to interface standard APB-compliant peripherals or interconnects with memory-mapped components that utilize the PMI protocol. It is typically used in SoC designs where a control bus (APB) needs to access high-speed memory or custom hardware accelerators that do not natively support APB.

| REVISION | DATE       | AUTHOR                 | DESCRIPTION                                            |
|----------|------------|------------------------|--------------------------------------------------------|
| 0.1      | 2026-08-13 | Annim Jannat           | Initial version                                        |
| 1.0      | 2026-08-16 | Annim Jannat           | Stable release                                         |
| 1.1      | 2026-08-27 | Ahasan Ullah Khalid    | Stable release                                         |

Author : Annim Jannat (jannatannim@gmail.com)
This file is part of ADN-VLSI/adn_apb
Copyright (c) 2026 ADN Semiconductors
Licensed under the MIT License
See LICENSE file in the project root for full license information
*/
`include "apb/typedef.svh"
`include "pmi/typedef.svh"

module adn_apb_to_pmi #(

    // PARAMETERS

    parameter type apb_req_t  = logic,  // `APB_REQ_T`  generated struct
    parameter type apb_rsp_t = logic,  // `APB_RSP_T` generated struct
    parameter type pmi_req_t  = logic,  // `PMI_REQ_T`  generated struct
    parameter type pmi_rsp_t = logic   // `PMI_RSP_T` generated struct
) (
    // PORTS
    // ---------------- Global signals ----------------
    input logic clk_i,
    input logic rst_ni,

    // ---------------- APB slave port ----------------
    input  apb_req_t  apb_req_i,
    output apb_rsp_t apb_rsp_o,

    // ---------------- PMI master port ---------------
    output pmi_req_t  pmi_req_o,
    input  pmi_rsp_t pmi_rsp_i
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  typedef enum logic [1:0] {
    S_IDLE,     // no APB transfer in progress
    S_REQ,      // APB transfer active, PMI request pending mgnt
    S_WAIT_ACK  // PMI request accepted, waiting on mack
  } state_e;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  state_e current_state, next_state;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // ---- Next-state logic ----
  always_comb begin
    next_state = current_state;
    unique case (current_state)
      S_IDLE: begin
        if (apb_req_i.psel && apb_req_i.penable) begin
          if (pmi_rsp_i.mgnt) next_state = pmi_rsp_i.mack ? S_IDLE : S_WAIT_ACK;
          else next_state = S_REQ;
        end
      end

      S_REQ: begin
        if (pmi_rsp_i.mgnt) next_state = pmi_rsp_i.mack ? S_IDLE : S_WAIT_ACK;
      end

      S_WAIT_ACK: begin
        if (pmi_rsp_i.mack) next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // ---- PMI request channel ----

  always_comb begin
    pmi_req_o = '0;

    if (rst_ni) begin
      pmi_req_o.maddr  = apb_req_i.paddr;
      pmi_req_o.mwe    = apb_req_i.pwrite;
      pmi_req_o.mwdata = apb_req_i.pwdata;
      pmi_req_o.mstrb  = apb_req_i.pwrite ? apb_req_i.pstrb : '0;

      unique case (current_state)
        S_IDLE:  pmi_req_o.mreq = apb_req_i.psel && apb_req_i.penable;
        S_REQ:   pmi_req_o.mreq = 1'b1;
        default: pmi_req_o.mreq = 1'b0;
      endcase
    end
  end

  // ---- PMI response channel -> APB response phase ----
  always_comb begin
    apb_rsp_o = '0;
    apb_rsp_o.pready = pmi_rsp_i.mack && ((current_state == S_WAIT_ACK) || (pmi_req_o.mreq && pmi_rsp_i.mgnt));
    apb_rsp_o.prdata = pmi_rsp_i.mrdata;  // valid per PR-11 when mack=1
    apb_rsp_o.pslverr = pmi_rsp_i.mresp;  // 0 = OKAY, 1 = ERROR
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // PMI reset rule: mreq/mgnt/mack = 0 during reset -> force state back to S_IDLE
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) current_state <= S_IDLE;
    else current_state <= next_state;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // PR-4: request signals must stay stable while mreq=1 and mgnt=0
  ap_stable_req_while_stalled :
  assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (pmi_req_o.mreq && !pmi_rsp_i.mgnt) |=>
      $stable(
      pmi_req_o.maddr
  ) && $stable(
      pmi_req_o.mwe
  ) && $stable(
      pmi_req_o.mwdata
  ) && $stable(
      pmi_req_o.mstrb
  ))
  else $error("adn_apb_to_pmi: PMI request signals changed while stalled (PR-4 violation)");

  // PR-13: pready must only ever be asserted while waiting on an outstanding ack
  ap_pready_only_after_pmi_completion :
  assert property (
  @(posedge clk_i) disable iff (!rst_ni)
  apb_rsp_o.pready |->
    ((current_state == S_WAIT_ACK) ||
     (pmi_req_o.mreq && pmi_rsp_i.mgnt))
)
  else $error("adn_apb_to_pmi: pready asserted without a PMI completion");

  // Reset rule: mreq must be low the cycle after reset deasserts if no APB transfer is active
  ap_reset_state :
  assert property (@(posedge clk_i) $rose(rst_ni) |-> (current_state == S_IDLE))
  else $error("adn_apb_to_pmi: FSM did not return to S_IDLE out of reset");

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INITIAL CHECKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Elaboration-time sanity checks that the bound struct types agree on data width.
  // Catches a mis-matched `APB_T`/`PMI_T` instantiation before simulation.
  initial begin
    assert ($bits(apb_req_i.pwdata) == $bits(pmi_req_o.mwdata))
    else
      $error(
          "adn_apb_to_pmi: APB pwdata width (%0d) != PMI mwdata width (%0d)",
          $bits(
              apb_req_i.pwdata
          ),
          $bits(
              pmi_req_o.mwdata
          )
      );

    assert ($bits(apb_rsp_o.prdata) == $bits(pmi_rsp_i.mrdata))
    else
      $error(
          "adn_apb_to_pmi: APB prdata width (%0d) != PMI mrdata width (%0d)",
          $bits(
              apb_rsp_o.prdata
          ),
          $bits(
              pmi_rsp_i.mrdata
          )
      );

    assert ($bits(apb_req_i.paddr) == $bits(pmi_req_o.maddr))
    else
      $error(
          "adn_apb_to_pmi: APB paddr width (%0d) != PMI maddr width (%0d)",
          $bits(
              apb_req_i.paddr
          ),
          $bits(
              pmi_req_o.maddr
          )
      );
  end
endmodule
