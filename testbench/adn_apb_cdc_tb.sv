/*

| TEST CASE | DATE | AUTHOR | DESCRIPTION |
|-----------|------------|-----------------|-------------------------------------------------------| 
| TC_001 | 2026-08-09 | Shuparna Haque | Apply Reset Test |
| TC_002 | 2026-08-09 | Shuparna Haque | Single Write then Read |
| TC_003 | 2026-08-06 | Shuparna Haque | Test case description goes here |

| REVISION | DATE | AUTHOR | DESCRIPTION |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1 | 2026-08-06 | Shuparna Haque | Initial version |
| 1.0 | 2026-08-06 | Shuparna Haque | Stable release |

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
localparam int STRB_WIDTH = DATA_WIDTH / 8;
localparam int MEM_DEPTH = 2**ADDR_WIDTH;
localparam int TIMEOUT_CYCLES = 100;

//////////////////////////////////////////////////////////////////////////////////////////////////
// TYPEDEFS
//////////////////////////////////////////////////////////////////////////////////////////////////
`APB_T(apb, ADDR_WIDTH, DATA_WIDTH)
//////////////////////////////////////////////////////////////////////////////////////////////////
// SIGNALS
//////////////////////////////////////////////////////////////////////////////////////////////////
real mst_clk_period = 10.0;
real slv_clk_period = 10.0;
logic mst_clk_i = 1'b0;
logic slv_clk_i = 1'b0;
logic mst_arst_ni;
logic slv_arst_ni;

apb_req_t mst_req_i;
apb_resp_t mst_resp_o;
apb_req_t slv_req_o;
apb_resp_t slv_resp_i;

logic [DATA_WIDTH-1:0] mem_model[MEM_DEPTH];

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
.apb_req_t (apb_req_t),
.apb_resp_t (apb_resp_t),
.SYNC_STAGES(2)
) dut (
.mst_clk_i (mst_clk_i),
.mst_arst_ni(mst_arst_ni),
.mst_req_i (mst_req_i),
.mst_resp_o (mst_resp_o),
.slv_clk_i (slv_clk_i),
.slv_arst_ni(slv_arst_ni),
.slv_req_o (slv_req_o),
.slv_resp_i (slv_resp_i)
);

//////////////////////////////////////////////////////////////////////////////////////////////////
// METHODS
//////////////////////////////////////////////////////////////////////////////////////////////////
task automatic apply_reset();
mst_arst_ni = 1'b0;
slv_arst_ni = 1'b0;
mst_req_i = '0;
#5;
mst_arst_ni = 1'b1;
#5;
slv_arst_ni = 1'b1;
endtask

task automatic apb_transfer(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] wdata,
input logic write, output logic [DATA_WIDTH-1:0] rdata, output bit timeout);
int unsigned wait_cycles;
@(posedge mst_clk_i);
mst_req_i.psel <= '1;
mst_req_i.penable <= 1'b0;
mst_req_i.paddr <= addr;
mst_req_i.pprot <= '0;
mst_req_i.pwrite <= write;
mst_req_i.pwdata <= wdata;
mst_req_i.pstrb <= write ? '1 : '0;

@(posedge mst_clk_i);
mst_req_i.penable <= 1'b1;

wait_cycles = 0;
timeout = 1'b0;
while (!mst_resp_o.pready) begin
@(posedge mst_clk_i);
wait_cycles++;
if (wait_cycles > TIMEOUT_CYCLES) begin
timeout = 1'b1;
break;
end
end
rdata = mst_resp_o.prdata;
@(posedge mst_clk_i);
mst_req_i.psel <= 1'b0;
mst_req_i.penable <= 1'b0;

endtask

task automatic check_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] wdata);
logic [DATA_WIDTH-1:0] rdata;
bit timed_out;
bit ok;
ok = 1'b1;

apb_transfer(addr, 1'b1, wdata, rdata, timed_out);

if (timed_out) begin
$display("\033[1;31mError: write to addr 0x%08h timed out\033[0m", addr);
ok = 1'b0;
end 
else if (mst_resp_o.pslverr) begin
$display("\033[1;31mError: unexpected pslverr on write to addr 0x%08h\033[0m", addr);
ok = 1'b0;
end 
else begin
$display("Write Successfully : addr 0x%08h <= 0x%08h", addr, wdata);
ok = 1'b1;
end
note_case (ok);
endtask
task automatic check_read(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] expected);
logic [DATA_WIDTH-1:0] rdata;
bit timed_out;
bit ok;
ok = 1'b1;

apb_transfer(addr, '0, 1'b0, rdata, timed_out);

if (timed_out) begin
$display("\033[1;31mError: read from addr 0x%08h timed out\033[0m", addr);
ok = 1'b0;
end else if (mst_resp_o.pslverr) begin
$display("\033[1;31mError: unexpected pslverr on read from addr 0x%08h\033[0m", addr);
ok = 1'b0;
end else if (rdata !== expected) begin
$display("\033[1;31mError: read mismatch at addr 0x%08h. Expected: 0x%08h, Got: 0x%08h\033[0m",
addr, expected, rdata);
ok = 1'b0;
end else begin
$display("Read Successfully: addr = 0x%08h , data : %0d ", addr, rdata);
ok = 1'b1;
end
endtask

//////////////////////////////////////////////////////////////////////////////////////////////////
// SEQUENTIALS
//////////////////////////////////////////////////////////////////////////////////////////////////
always #(mst_clk_period / 2.0) begin
mst_clk_i = ~mst_clk_i;
end
always #(slv_clk_period / 2.0) begin
slv_clk_i = ~slv_clk_i;
end

always_ff @(posedge slv_clk_i) begin
if (slv_req_o.psel && slv_req_o.penable && slv_req_o.pwrite) begin
mem_model[slv_req_o.paddr] <= slv_req_o.pwdata;
end
end
//////////////////////////////////////////////////////////////////////////////////////////////////
// PROCEDURALS
//////////////////////////////////////////////////////////////////////////////////////////////////

always_comb begin
slv_resp_i.pready = slv_req_o.psel & slv_req_o.penable;
slv_resp_i.pslverr = 1'b0;
slv_resp_i.prdata = mem_model[slv_req_o.paddr];

end

initial begin // main initial
apply_reset();
/*
case (test_name)

"TC_001": begin
check_write(32'h0000_0001, 32'hDED);
apply_reset();
check_write(32'h0000_0001, 32'hDEAD);
end

"TC_002": begin
check_write(32'h0000_0001, 32'hBAE);
check_read (32'h0000_0001, 32'hBAE);
end

"TC_003": begin

end

"TC_004": begin

end

"TC_005": begin

end

endcase
*/
check_write(32'h0000_0001, 32'hDED);
apply_reset();
check_write(32'h0000_0001, 32'hDEAD);

repeat (5) @(mst_clk_i);
check_write(32'h0000_0001, 32'hBAE);
check_read (32'h0000_0001, 32'hBAE);
repeat (5) @(mst_clk_i);




$finish;

end

endmodule

