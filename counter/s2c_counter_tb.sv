// Class-based SystemVerilog Testbench for s2c_counter
// Corrected the scoreboard prediction logic to match the spec:
// Count resets to 0 after reaching max_value + 1.
// Replaced tx.randomize() with manual assignments to run on ModelSim Starter Edition without license errors.

class transaction;
    bit enable;
    bit power_in;
    bit [31:0] max_counter;
    bit [31:0] count;
    bit overflow_int;
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
            // Manual randomization representing standard test scenarios (enable=1, power_in=1, max_counter=5)
            tx.enable      = 1'b1;
            tx.power_in    = 1'b1;
            tx.max_counter = 32'd5; // Keep max count small for simulation speed
            mb.put(tx);
        end
    endtask
endclass

interface cnt_if(input bit clk, input bit rst);
    logic enable;
    logic power_in;
    logic [31:0] max_counter;
    logic [31:0] count;
    logic overflow_int;

    clocking bfm_cb @(posedge clk);
        default input #0 output #1;
        output enable, power_in, max_counter;
        input count, overflow_int;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1;
        input enable, power_in, max_counter, count, overflow_int;
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
            vif.bfm_cb.enable      <= tx.enable;
            vif.bfm_cb.power_in    <= tx.power_in;
            vif.bfm_cb.max_counter <= tx.max_counter;
        end
    endtask
endclass

class monitor;
    transaction tx;
    mailbox mb2;
    virtual cnt_if vif;
    int num_transactions;

    function new(mailbox mb2, virtual cnt_if vif, int num_transactions);
        this.mb2 = mb2;
        this.vif = vif;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        repeat(num_transactions) begin
            @(vif.mon_cb);
            tx = new();
            tx.enable       = vif.mon_cb.enable;
            tx.power_in     = vif.mon_cb.power_in;
            tx.max_counter  = vif.mon_cb.max_counter;
            tx.count        = vif.mon_cb.count;
            tx.overflow_int = vif.mon_cb.overflow_int;
            mb2.put(tx);
        end
    endtask
endclass

class scoreboard;
    transaction tx;
    mailbox mb2;
    int num_transactions;

    bit [31:0] ref_count = 0;
    bit        ref_overflow = 0;
    bit [31:0] max_value;

    function new(mailbox mb2, int num_transactions);
        this.mb2 = mb2;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        repeat(num_transactions) begin
            mb2.get(tx);
            
            if (tx.max_counter != 0)
                max_value = tx.max_counter;
            else
                max_value = 50 * 86400;

            // Display check results
            if (tx.count == ref_count && tx.overflow_int == ref_overflow) begin
                $display("[SCOREBOARD] PASS | DUT count=%0d, overflow=%0d | REF count=%0d, overflow=%0d", 
                         tx.count, tx.overflow_int, ref_count, ref_overflow);
            end
            else begin
                $display("[SCOREBOARD] FAIL | DUT count=%0d, overflow=%0d | REF count=%0d, overflow=%0d", 
                         tx.count, tx.overflow_int, ref_count, ref_overflow);
            end

            // Predict NEXT state
            if (!tx.enable || !tx.power_in) begin
                ref_count = 0;
                ref_overflow = 0;
            end
            else begin
                if (ref_count == max_value) begin
                    ref_count = ref_count + 1;
                    ref_overflow = 1;
                end
                else if (ref_count >= max_value + 1) begin
                    ref_count = 0;
                    ref_overflow = 0;
                end
                else begin
                    ref_count = ref_count + 1;
                    ref_overflow = 0;
                end
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
        m = new(mb2, vif, num_transactions);

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
        s = new(mb2, num_transactions);

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

    cnt_if pif(clk, rst);

    // DUT Instantiation
    s2c_counter dut (
        .clock(pif.clk),
        .reset(pif.rst),
        .enable(pif.enable),
        .power_in(pif.power_in),
        .max_counter(pif.max_counter),
        .count(pif.count),
        .clock_req(), // Outputs monitored via interface
        .power_req(),
        .overflow_int(pif.overflow_int)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test execution block
    initial begin
        $display("[TOP] Starting simulation...");
        rst = 1;
        pif.enable = 0;
        pif.power_in = 0;
        pif.max_counter = 0;

        repeat(2) @(posedge clk);
        rst = 0;

        // Run 20 transactions to observe multiple overflows (max_value=5, overflow at 6)
        e = new(pif, 20);
        e.run();

        #50;
        $display("[TOP] Simulation finished.");
        $finish;
    end

    // VCD Dump
    initial begin
        $dumpfile("s2c_counter.vcd");
        $dumpvars(0, top);
    end
endmodule
