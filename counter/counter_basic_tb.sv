// Class-based SystemVerilog Testbench for Basic Counter
// Fixed the synchronization mismatch and reset timing issues present in the original notes.
// Replaced tx.randomize() with $urandom_range to run on ModelSim Starter Edition without license errors.

class transaction;
    bit rst;
    bit up_down;
    bit load;
    bit [3:0] data;
    bit [3:0] count;

    function void display(string name);
        $display("[%s] rst=%b load=%b up_down=%b data=%0d -> count=%0d", name, rst, load, up_down, data, count);
    endfunction
endclass

class generator;
    transaction tx;
    mailbox mb;
    int num_transactions;

    function new(mailbox mb, int num_transactions);
        this.mb = mb;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        repeat(num_transactions) begin
            tx = new();
            tx.load    = $urandom_range(0, 1);
            tx.up_down = $urandom_range(0, 1);
            tx.data    = $urandom_range(0, 15);
            mb.put(tx);
        end
    endtask
endclass

interface cnt_if(input bit clk, input bit rst);
    logic up_down = 0;
    logic load = 0;
    logic [3:0] data = 0;
    logic [3:0] count;

    clocking bfm_cb @(posedge clk);
        default input #0 output #1;
        output load, up_down, data;
        input count;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1;
        input rst, load, up_down, data, count; // Added rst to clocking block for race-free sampling
    endclocking
endinterface

class bfm;
    transaction tx;
    mailbox mb;
    virtual cnt_if vif;
    int num_transactions;

    function new(mailbox mb, virtual cnt_if vif, int num_transactions);
        this.mb = mb;
        this.vif = vif;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        repeat(num_transactions) begin
            mb.get(tx);
            @(vif.bfm_cb);
            vif.bfm_cb.load    <= tx.load;
            vif.bfm_cb.up_down <= tx.up_down;
            vif.bfm_cb.data    <= tx.data;
            
            // Wait for next clock cycle to deassert signals
            @(vif.bfm_cb);
            vif.bfm_cb.load    <= 0;
            vif.bfm_cb.up_down <= 0;
            vif.bfm_cb.data    <= 0;
        end
    endtask
endclass

class monitor;
    transaction tx;
    mailbox mb2;
    virtual cnt_if vif;
    int num_cycles;

    function new(mailbox mb2, virtual cnt_if vif, int num_cycles);
        this.mb2 = mb2;
        this.vif = vif;
        this.num_cycles = num_cycles;
    endfunction

    task run();
        repeat(num_cycles) begin
            @(vif.mon_cb);
            tx = new();
            tx.rst     = vif.mon_cb.rst; // Sample reset race-free from the clocking block
            tx.load    = vif.mon_cb.load;
            tx.up_down = vif.mon_cb.up_down;
            tx.data    = vif.mon_cb.data;
            tx.count   = vif.mon_cb.count;
            mb2.put(tx);
        end
    endtask
endclass

class scoreboard;
    transaction tx;
    mailbox mb2;
    bit [3:0] expected_count = 0; // expected count for the current transaction
    bit valid = 0;                // expected count is valid only after first transaction
    int num_cycles;

    function new(mailbox mb2, int num_cycles);
        this.mb2 = mb2;
        this.num_cycles = num_cycles;
    endfunction

    task run();
        repeat(num_cycles) begin
            mb2.get(tx);

            if (valid) begin
                if (expected_count == tx.count) begin
                    $display("[SCOREBOARD] PASS | DUT count=%0d, Expected count=%0d", tx.count, expected_count);
                end else begin
                    $display("[SCOREBOARD] FAIL | DUT count=%0d, Expected count=%0d", tx.count, expected_count);
                end
            end else begin
                // The first transaction has the initial count (after reset, count=0)
                if (tx.count == 0) begin
                    $display("[SCOREBOARD] PASS (Initial) | DUT count=%0d, Expected count=0", tx.count);
                end else begin
                    $display("[SCOREBOARD] FAIL (Initial) | DUT count=%0d, Expected count=0", tx.count);
                end
                valid = 1;
            end

            // Predict the count for the next transaction (cycle N+1) based on the inputs of cycle N
            if (tx.rst) begin
                expected_count = 4'd0; // If reset was active at cycle N, next cycle count will be 0
            end else if (tx.load) begin
                expected_count = tx.data;
            end else begin
                if (tx.up_down)
                    expected_count = tx.count + 1'b1;
                else
                    expected_count = tx.count - 1'b1;
            end
        end
    endtask
endclass

class agent;
    generator g;
    bfm b;
    monitor m;
    mailbox mb;
    mailbox mb2;
    virtual cnt_if vif;
    int num_transactions;

    function new(mailbox mb, mailbox mb2, virtual cnt_if vif, int num_transactions);
        this.mb = mb;
        this.mb2 = mb2;
        this.vif = vif;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        g = new(mb, num_transactions);
        b = new(mb, vif, num_transactions);
        m = new(mb2, vif, num_transactions * 2);
        
        fork
            g.run();
            b.run();
            m.run();
        join
    endtask
endclass

class environment;
    agent a;
    scoreboard s;
    mailbox mb;
    mailbox mb2;
    virtual cnt_if vif;
    int num_transactions;

    function new(virtual cnt_if vif, int num_transactions);
        this.vif = vif;
        this.num_transactions = num_transactions;
        this.mb = new();
        this.mb2 = new();
    endfunction

    task run();
        a = new(mb, mb2, vif, num_transactions);
        s = new(mb2, num_transactions * 2);
        
        fork
            a.run();
            s.run();
        join
    endtask
endclass

module top;
    reg clk;
    reg rst;
    environment e;
    
    // Interface instantiation
    cnt_if pif(clk, rst);

    // DUT instantiation
    counter dut (
        .clk(pif.clk),
        .reset(pif.rst),
        .up_down(pif.up_down),
        .load(pif.load),
        .data(pif.data),
        .count(pif.count)
    );

    // Clock generator
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Debug print
    always @(posedge clk) begin
        $display("[DEBUG] Time=%0d | rst=%b | pif.rst=%b | DUT.reset=%b | pif.load=%b | pif.up_down=%b | pif.data=%0d | pif.count=%0d", 
                 $time, rst, pif.rst, dut.reset, pif.load, pif.up_down, pif.data, pif.count);
    end

    // Test execution block
    initial begin
        $display("[TOP] Starting simulation...");
        rst = 1;
        
        repeat(2) @(posedge clk);
        rst <= 0; // release reset with non-blocking assignment
        
        // Run with 5 transactions (10 clock cycles)
        e = new(pif, 5);
        e.run();
        
        #50;
        $display("[TOP] Simulation finished.");
        $finish;
    end

    // VCD Dump
    initial begin
        $dumpfile("counter_basic.vcd");
        $dumpvars(0, top);
    end
endmodule
