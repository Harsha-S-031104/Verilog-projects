module counter(
    input clk,            // Clock input
    input reset,          // Active-high reset
    input up_down,        // 1=up, 0=down
    input load,           // Load enable
    input [3:0] data,     // Data to load
    output reg [3:0] count // 4-bit output
);

    // Evaluated at every positive edge of the clock
    always @(posedge clk) begin
        if (reset)
            count <= 4'b0000;      // Synchronous reset to zero
        else if (load)
            count <= data;         // Load specific value
        else if (up_down)
            count <= count + 1'b1; // Count up
        else
            count <= count - 1'b1; // Count down
    end
endmodule
