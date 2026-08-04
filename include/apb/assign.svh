/*

### Purpose
This file provides a set of SystemVerilog macros designed to simplify the assignment and connection of APB (Advanced Peripheral Bus) interface signals between a master and a slave. It abstracts the repetitive task of mapping individual bus signals, reducing boilerplate code and minimizing the risk of connection errors.

### Use Case
This file is primarily used in testbenches or top-level integration modules where an APB Master interface needs to be connected to an APB Slave interface. By using these macros, developers can avoid manually writing out every signal assignment (psel, penable, paddr, etc.), which is prone to copy-paste errors. It supports different assignment types (combinational, blocking, and non-blocking) to accommodate various simulation and synthesis requirements.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
This file is part of ADN-VLSI/adn_apb
Copyright (c) 2026 ADN-VLSI
Licensed under the MIT License
See LICENSE file in the project root for full license information

*/

`ifndef __GUARD_APB_ASSIGN_SVH__
`define __GUARD_APB_ASSIGN_SVH__ 0


// Purpose: Connects APB Master and Slave signals.
// Usecase: Used as a backend for specific assignment macros to map bus signals.
`define APB_COMMUNICATION(__M__, __S__, __MT__, __AS__)               \
  ``__MT__`` ``__S__``.psel    ``__AS__`` {'0, ``__M__``.psel};       \
  ``__MT__`` ``__S__``.penable ``__AS__`` {'0, ``__M__``.penable};    \
  ``__MT__`` ``__S__``.paddr   ``__AS__`` {'0, ``__M__``.paddr};      \
  ``__MT__`` ``__S__``.pprot   ``__AS__`` {'0, ``__M__``.pprot};      \
  ``__MT__`` ``__S__``.pwrite  ``__AS__`` {'0, ``__M__``.pwrite};     \
  ``__MT__`` ``__S__``.pwdata  ``__AS__`` {'0, ``__M__``.pwdata};     \
  ``__MT__`` ``__S__``.pstrb   ``__AS__`` {'0, ``__M__``.pstrb};      \
  ``__MT__`` ``__M__``.pready  ``__AS__`` {'0, ``__S__``.pready};     \
  ``__MT__`` ``__M__``.prdata  ``__AS__`` {'0, ``__S__``.prdata};     \
  ``__MT__`` ``__M__``.pslverr ``__AS__`` {'0, ``__S__``.pslverr};    \


// Purpose: Performs a combinational assignment for APB signals.
// Usecase: Typically used in continuous assignment contexts where the APB signals need to reflect the current state of the master and slave interfaces without any delay.
`define APB_COMB_ASSIGN(__M__, __S__)                                 \
  `APB_COMMUNICATION(``__M__``, ``__S__``, always_comb, =)            \


// Purpose: Performs a blocking assignment for APB signals.
// Usecase: Typically used within procedural blocks (initial/always) for sequential logic or testbench stimulus where immediate signal updates are required.
`define APB_BLOCKING_ASSIGN(__M__, __S__)                             \
  `APB_COMMUNICATION(``__M__``, ``__S__``, , =)                       \


// Purpose: Performs a non-blocking assignment for APB signals.
// Usecase: Typically used within procedural blocks (always_ff) for sequential logic where signal updates should occur at the end of the time step, allowing for proper simulation of clocked behavior.
`define APB_NONBLOCKING_ASSIGN(__M__, __S__)                          \
  `APB_COMMUNICATION(``__M__``, ``__S__``, , <=)                      \


`endif
