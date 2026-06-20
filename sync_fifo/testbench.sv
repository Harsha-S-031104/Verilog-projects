// =============================================================================
// File Name: testbench.sv
// Description: Clean SystemVerilog testbench for EDA Playground with latency matching.
//              Contains interface, transaction, generator, BFM/driver,
//              monitor, scoreboard, agent, environment, and top module.
//              (Does NOT define design sync_fifo, which is in design.sv).
// =============================================================================

// =============================================================================
// 1. INTERFACE
// =============================================================================
interface sync_fifo_if #(
    parameter DATA_WIDTH = 8
)(
    input wire clk
);
    logic                  rst;
    logic                  wr_en;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  full;
    logic                  empty;
    logic                  almost_full;
    logic                  almost_empty;
    logic                  overflow;
    logic                  underflow;

    clocking drv_cb @(posedge clk);
        default input #1ns output #1ns;
        output wr_en;
        output rd_en;
        output wdata;
        output rst;
        input  rdata;
        input  full;
        input  empty;
        input  almost_full;
        input  almost_empty;
        input  overflow;
        input  underflow;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;
        input rst;
        input wr_en;
        input rd_en;
        input wdata;
        input rdata;
        input full;
        input empty;
        input almost_full;
        input almost_empty;
        input overflow;
        input underflow;
    endclocking

    modport DRIVER  (clocking drv_cb, input clk);
    modport MONITOR (clocking mon_cb, input clk);
endinterface

// Global Mailboxes
mailbox mb  = new();
mailbox mb2 = new();

// =============================================================================
// 2. OOP CLASSES
// =============================================================================
class transaction;
    rand bit       wr_en;
    rand bit       rd_en;
    rand bit [7:0] wdata;
    
    bit [7:0] rdata;
    bit       full;
    bit       empty;
    bit       almost_full;
    bit       almost_empty;
    bit       overflow;
    bit       underflow;

    constraint wr_rd_dist {
        wr_en dist {1 := 60, 0 := 40};
        rd_en dist {1 := 40, 0 := 60};
    }

    function void display(string prefix);
        $display("[%0s] Time=%0t | wr_en=%0b rd_en=%0b wdata=0x%0h | rdata=0x%0h | full=%0b empty=%0b almost_full=%0b almost_empty=%0b overflow=%0b underflow=%0b", prefix, $time, wr_en, rd_en, wdata, rdata, full, empty, almost_full, almost_empty, overflow, underflow);
    endfunction
endclass

class generator;
    transaction tx;
    int num_loops = 50;

    task run();
        $display("[GEN] Starting stimulus generation for %0d loops.", num_loops);
        repeat(num_loops) begin
            tx = new();
            if (!tx.randomize()) begin
                $fatal("Gen: Transaction randomization failed!");
            end
            mb.put(tx);
        end
        $display("[GEN] Stimulus generation finished.");
    endtask
endclass

class bfm;
    transaction tx;
    virtual sync_fifo_if vif;

    function new(virtual sync_fifo_if vif_inst);
        vif = vif_inst;
    endfunction

    task run();
        $display("[BFM] Driver started.");
        vif.drv_cb.rst   <= 1'b1;
        vif.drv_cb.wr_en <= 1'b0;
        vif.drv_cb.rd_en <= 1'b0;
        vif.drv_cb.wdata <= 8'h00;
        repeat(2) @(vif.drv_cb);
        vif.drv_cb.rst   <= 1'b0;
        @(vif.drv_cb);

        forever begin
            mb.get(tx);
            vif.drv_cb.wr_en <= tx.wr_en;
            vif.drv_cb.rd_en <= tx.rd_en;
            vif.drv_cb.wdata <= tx.wdata;
            @(vif.drv_cb);
        end
    endtask
endclass

class monitor;
    transaction tx;
    virtual sync_fifo_if vif;

    function new(virtual sync_fifo_if vif_inst);
        vif = vif_inst;
    endfunction

    task run();
        $display("[MON] Monitor started.");
        wait(vif.rst === 1'b0);
        forever begin
            @(vif.mon_cb);
            tx = new();
            tx.wr_en        = vif.mon_cb.wr_en;
            tx.rd_en        = vif.mon_cb.rd_en;
            tx.wdata        = vif.mon_cb.wdata;
            tx.rdata        = vif.mon_cb.rdata;
            tx.full         = vif.mon_cb.full;
            tx.empty        = vif.mon_cb.empty;
            tx.almost_full  = vif.mon_cb.almost_full;
            tx.almost_empty = vif.mon_cb.almost_empty;
            tx.overflow     = vif.mon_cb.overflow;
            tx.underflow    = vif.mon_cb.underflow;
            tx.display("MON");
            mb2.put(tx);
        end
    endtask
endclass

class scoreboard;
    transaction tx;
    bit [7:0] ideal_fifo[$];
    int match_count = 0;
    int error_count = 0;
    int depth = 16;
    int almost_full_limit = 12;
    int almost_empty_limit = 4;

    task run();
        // Variables declared at top for SystemVerilog compatibility
        bit was_full;
        bit was_empty;
        bit [7:0] expected_data_prev;
        bit read_active_prev;
        bit expected_overflow_prev;
        bit expected_underflow_prev;

        bit expected_empty;
        bit expected_full;
        bit expected_almost_full;
        bit expected_almost_empty;

        read_active_prev = 0;
        expected_overflow_prev = 0;
        expected_underflow_prev = 0;

        $display("[SB] Scoreboard checker active.");
        
        forever begin
            mb2.get(tx);
            
            // -----------------------------------------------------------------
            // 1. Verify Read Data from Previous Cycle Read
            // -----------------------------------------------------------------
            if (read_active_prev) begin
                if (tx.rdata !== expected_data_prev) begin
                    $error("[SB ERROR] Data Mismatch! Expected=0x%0h, Got=0x%0h", expected_data_prev, tx.rdata);
                    error_count++;
                end else begin
                    $display("[SB PASS] Data Match: 0x%0h popped successfully.", tx.rdata);
                    match_count++;
                end
            end

            // -----------------------------------------------------------------
            // 2. Verify Output Flags (represents state BEFORE this cycle's actions)
            // -----------------------------------------------------------------
            expected_empty = (ideal_fifo.size() == 0);
            expected_full  = (ideal_fifo.size() == depth);
            expected_almost_full  = (ideal_fifo.size() >= almost_full_limit);
            expected_almost_empty = (ideal_fifo.size() <= almost_empty_limit && ideal_fifo.size() > 0);

            if (tx.empty !== expected_empty) begin
                $error("[SB ERROR] Empty flag mismatch! Expected=%0b, Got=%0b", expected_empty, tx.empty);
                error_count++;
            end
            if (tx.full !== expected_full) begin
                $error("[SB ERROR] Full flag mismatch! Expected=%0b, Got=%0b", expected_full, tx.full);
                error_count++;
            end
            if (tx.almost_full !== expected_almost_full) begin
                $error("[SB ERROR] Almost Full flag mismatch! Expected=%0b, Got=%0b", expected_almost_full, tx.almost_full);
                error_count++;
            end
            if (tx.almost_empty !== expected_almost_empty) begin
                $error("[SB ERROR] Almost Empty flag mismatch! Expected=%0b, Got=%0b", expected_almost_empty, tx.almost_empty);
                error_count++;
            end

            // -----------------------------------------------------------------
            // 3. Verify Error Status Flags from Previous Cycle
            // -----------------------------------------------------------------
            if (tx.overflow !== expected_overflow_prev) begin
                $error("[SB ERROR] Overflow flag mismatch! Expected=%0b, Got=%0b", expected_overflow_prev, tx.overflow);
                error_count++;
            end
            if (tx.underflow !== expected_underflow_prev) begin
                $error("[SB ERROR] Underflow flag mismatch! Expected=%0b, Got=%0b", expected_underflow_prev, tx.underflow);
                error_count++;
            end

            // -----------------------------------------------------------------
            // 4. Calculate Expected Error Triggers for the NEXT Cycle
            // -----------------------------------------------------------------
            expected_overflow_prev  = (tx.wr_en && expected_full);
            expected_underflow_prev = (tx.rd_en && expected_empty);

            // -----------------------------------------------------------------
            // 5. Update Ideal Queue State for the NEXT Cycle
            // -----------------------------------------------------------------
            was_full  = (ideal_fifo.size() == depth);
            was_empty = (ideal_fifo.size() == 0);

            if (tx.wr_en && !was_full) begin
                ideal_fifo.push_back(tx.wdata);
            end

            if (tx.rd_en && !was_empty) begin
                expected_data_prev = ideal_fifo.pop_front();
                read_active_prev = 1;
            end else begin
                read_active_prev = 0;
            end
        end
    endtask
endclass

class agent;
    generator g;
    bfm       b;
    monitor   m;
    function new(virtual sync_fifo_if vif);
        g = new();
        b = new(vif);
        m = new(vif);
    endfunction
    task run();
        fork
            g.run();
            b.run();
            m.run();
        join_any
    endtask
endclass

class environment;
    agent      a;
    scoreboard s;
    function new(virtual sync_fifo_if vif);
        a = new(vif);
        s = new();
    endfunction
    task run();
        fork
            a.run();
            s.run();
        join_any
        #100;
        $display("\n=============================================");
        $display("          VERIFICATION REPORT SUMMARY        ");
        $display("=============================================");
        $display(" Total Matches: %0d", s.match_count);
        $display(" Total Errors:  %0d", s.error_count);
        if (s.error_count == 0) $display(" STATUS: TEST PASSED Successfully!");
        else                    $display(" STATUS: TEST FAILED with %0d errors.", s.error_count);
        $display("=============================================\n");
        $finish;
    endtask
endclass

// =============================================================================
// 3. TOP MODULE
// =============================================================================
module top;
    reg clk;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    sync_fifo_if pif(clk);

    sync_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(16),
        .ALMOST_FULL_VAL(12),
        .ALMOST_EMPTY_VAL(4)
    ) dut (
        .clk(pif.clk),
        .rst(pif.rst),
        .wr_en(pif.wr_en),
        .rd_en(pif.rd_en),
        .wdata(pif.wdata),
        .rdata(pif.rdata),
        .full(pif.full),
        .empty(pif.empty),
        .almost_full(pif.almost_full),
        .almost_empty(pif.almost_empty),
        .overflow(pif.overflow),
        .underflow(pif.underflow)
    );

    environment e;
    initial begin
        e = new(pif);
        e.run();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top);
    end
endmodule
