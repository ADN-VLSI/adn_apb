/*

# Purpose
This file defines SystemVerilog macros for generating APB (Advanced Peripheral Bus) request and response structures, ensuring consistent interface definitions across the ADN-VLSI/adn_apb project.

This file serves as a centralized header for generating standardized APB interface structures. By utilizing parameterized macros, it allows hardware designers to instantiate custom-width APB request and response types dynamically, reducing boilerplate code and ensuring strict adherence to the APB protocol specifications across the design hierarchy.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_apb
Copyright (c) __YEAR__ ADN-VLSI
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`ifndef __GUARD_APB_TYPEDEF_SVH__
`define __GUARD_APB_TYPEDEF_SVH__ 0

// Macro: APB_REQ_T
// Purpose: Generates a packed struct for an APB request interface.
// Usecase: Use this to define the master-to-slave request signals with configurable address and data widths.
`define APB_REQ_T(__NM__, __AW__, __DW__)        \
  typedef struct packed {                        \
    logic                    psel;               \
    logic                    penable;            \
    logic [  ``__AW__``-1:0] paddr;              \
    logic [             2:0] pprot;              \
    logic                    pwrite;             \
    logic [  ``__DW__``-1:0] pwdata;             \
    logic [``__DW__``/8-1:0] pstrb;              \
} ``__NM__``_req_t;                              \
`define APB_RESP_T(__NM__, __DW__)               \
  typedef struct packed {                        \
    logic                    pready;             \
    logic [  ``__DW__``-1:0] prdata;             \
    logic                    pslverr;            \
} ``__NM__``_resp_t;                             \


// Macro: APB_T
// Purpose: Generates both request and response packed structs for an APB interface.
// Usecase: Use this to instantiate a complete APB interface pair (req/resp) with a single macro call, ensuring consistency across the design.
`define APB_T(__NM__, __AW__, __DW__)            \
  `APB_REQ_T(``__NM__``, ``__AW__``, ``__DW__``) \
  `APB_RESP_T(``__NM__``, ``__DW__``)            \


`endif
