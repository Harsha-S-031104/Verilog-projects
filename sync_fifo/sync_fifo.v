// =============================================================================
// Module Name: sync_fifo
// Description: Parameterized Synchronous FIFO with status and error flags.
// =============================================================================

module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ALMOST_FULL_VAL = 12,
    parameter ALMOST_EMPTY_VAL = 4
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    wr_en,
    input  wire                    rd_en,
    input  wire [DATA_WIDTH-1:0]   wdata,
    
    output reg  [DATA_WIDTH-1:0]   rdata,
    output wire                    full,
    output wire                    empty,
    output wire                    almost_full,
    output wire                    almost_empty,
    output reg                     overflow,
    output reg                     underflow
);

    // Address width calculation
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Internal Memory Array
    reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];

    // Pointers: 1 extra bit for wrap-around detection
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    // -------------------------------------------------------------------------
    // Pointer Update Logic
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            // Write Pointer increment
            if (wr_en && !full) begin
                wr_ptr <= wr_ptr + 1'b1;
            end
            
            // Read Pointer increment
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Memory Write & Read Logic
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wdata;
        end
    end

    // Continuous or registered read depending on design preference.
    // Standard synchronous FIFO usually registers the read data output.
    always @(posedge clk) begin
        if (rst) begin
            rdata <= 0;
        end else if (rd_en && !empty) begin
            rdata <= mem[rd_ptr[ADDR_WIDTH-1:0]];
        end
    end

    // -------------------------------------------------------------------------
    // Flag Generation Logic
    // -------------------------------------------------------------------------
    // Empty: when all pointer bits match exactly
    assign empty = (wr_ptr == rd_ptr);

    // Full: address bits match, but wrap-around bit (MSB) differs
    assign full = (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]) && 
                  (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]);

    // Occupancy count calculation (using pointers subtraction)
    wire [ADDR_WIDTH:0] count = wr_ptr - rd_ptr;

    assign almost_full  = (count >= ALMOST_FULL_VAL);
    assign almost_empty = (count <= ALMOST_EMPTY_VAL && count > 0);

    // -------------------------------------------------------------------------
    // Error Flag Generation Logic (Overflow & Underflow)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else begin
            // Overflow: write request when full
            if (wr_en && full) begin
                overflow <= 1'b1;
            end else begin
                overflow <= 1'b0;
            end

            // Underflow: read request when empty
            if (rd_en && empty) begin
                underflow <= 1'b1;
            end else begin
                underflow <= 1'b0;
            end
        end
    end

endmodule
