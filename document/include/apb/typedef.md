# apb/typedef.svh  (include)

### Author: Foez Ahmed (foez.official@gmail.com)

### Source: typedef.svh

## Parameters

_None_


## Include Guard

__GUARD_APB_TYPEDEF_SVH__


## Macros

|Name|Args|Description|Preview|
|-|-|-|-|
|APB_REQ_T|__NM__, __AW__, __DW__|Macro: APB_REQ_T Purpose: Generates a packed struct for an APB request interface. Usecase: Use this to define the master-to-slave request signals with configurable address and data widths.|`define APB_REQ_T(__NM__, __AW__, __DW__)         typedef struct packed {                         logic                    psel;                logic|
|APB_RSP_T|__NM__, __DW__|Macro: APB_RSP_T Purpose: Generates a packed struct for an APB response interface. Usecase: Use this to define the slave-to-master response signals with configurable data width.|`define APB_RSP_T(__NM__, __DW__)                typedef struct packed {                         logic                    pready;              logic [  ``__DW__|
|APB_T|__NM__, __AW__, __DW__|Macro: APB_T Purpose: Generates both request and response packed structs for an APB interface. Usecase: Use this to instantiate a complete APB interface pair (req/rsp) with a single macro call, ensuring consistency across the design.|`define APB_T(__NM__, __AW__, __DW__)             `APB_REQ_T(``__NM__``, ``__AW__``, ``__DW__``)  `APB_RSP_T(``__NM__``, ``__DW__``)|


## Description

# apb/typedef.svh 
This file defines SystemVerilog macros for generating APB (Advanced Peripheral Bus) request and response structures, ensuring consistent interface definitions across the ADN-VLSI/adn_apb project.

This file serves as a centralized header for generating standardized APB interface structures. By utilizing parameterized macros, it allows hardware designers to instantiate custom-width APB request and response types dynamically, reducing boilerplate code and ensuring strict adherence to the APB protocol specifications across the design hierarchy.

| REVISION | DATE       | AUTHOR          | DESCRIPTION                                            |
|----------|------------|-----------------|--------------------------------------------------------|
| 0.1      | 2026-08-04 | Foez Ahmed      | Initial version                                        |

Author : Foez Ahmed (foez.official@gmail.com)
