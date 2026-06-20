// Spec-compliant, low-power-aware 32-bit counter
// Corrected the blocking assignments (=) to non-blocking assignments (<=) for registers.

module s2c_counter (
    input  wire        enable,
    input  wire        clock,
    input  wire        reset,
    input  wire        power_in,
    input  wire [31:0] max_counter,

    output wire        clock_req,
    output wire        power_req,
    output reg  [31:0] count,
    output reg         overflow_int
);

    // Parameter declaration
    parameter MAX_DAYS = 50;
    localparam [31:0] DEFAULT_MAX = MAX_DAYS * 86400;

    // Internal signal for maximum limit
    wire [31:0] max_value;
    assign max_value = (max_counter != 0) ? max_counter : DEFAULT_MAX;

    // Power & Clock requests
    assign power_req = enable;
    assign clock_req = power_in;

    // Counter & Overflow Logic
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            count        <= 32'd0;
            overflow_int <= 1'b0;
        end
        else if (!enable || !power_in) begin
            count        <= 32'd0;
            overflow_int <= 1'b0;
        end
        else begin
            if (count == max_value) begin
                count        <= count + 1'b1; // Increments to max_value + 1
                overflow_int <= 1'b1;         // Assert overflow interrupt
            end
            else if (count >= max_value + 1) begin
                count        <= 32'd0;        // Reset count to 0 after overflow
                overflow_int <= 1'b0;         // Clear overflow interrupt
            end
            else begin
                count        <= count + 1'b1; // Normal counting
                overflow_int <= 1'b0;
            end
        end
    end

endmodule
