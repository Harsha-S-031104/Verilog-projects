// RTL Code for 32-bit Multiplier ALU
// File: alu.v

module alu(
    input [31:0] a,
    input [31:0] b,
    output [31:0] c
);

    // Data flow level implementation of multiplier
    assign c = a * b;

endmodule
