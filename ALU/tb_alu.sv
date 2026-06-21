// SystemVerilog Class-Based Testbench for 32-bit Multiplier ALU
// File: tb_alu.sv

interface alu_if();
    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] c;
endinterface

class transaction;
    int a; 
    int b;
    int c;

    // Custom pseudo-randomization function to run on ModelSim licenses 
    // that do not support standard verification/randomization features.
    function bit custom_randomize();
        a = $urandom_range(10, 20); // range [10:20]
        b = $urandom_range(5, 15);  // range [5:15]
        return 1;
    endfunction
endclass

class generator;
    transaction tx;
    mailbox mb;

    function new(mailbox mb);
        this.mb = mb;
    endfunction

    task run();
        repeat(5) begin
            tx = new();
            if (!tx.custom_randomize()) begin
                $display("Randomization failed");
            end
            $display("[Generator] Created Transaction: a = %0d, b = %0d", tx.a, tx.b);
            mb.put(tx);
        end
    endtask
endclass

class bfm;
    transaction tx;
    mailbox mb;
    virtual alu_if vif;

    function new(mailbox mb, virtual alu_if vif);
        this.mb = mb;
        this.vif = vif;
    endfunction

    task run();
        repeat(5) begin
            mb.get(tx);
            vif.a = tx.a;
            vif.b = tx.b;
            $display("[BFM] Driving interface pins: a = %0d, b = %0d", vif.a, vif.b);
            #2; // Drive each transaction for 2 time units
        end
    endtask
endclass

class monitor;
    transaction tx;
    mailbox mb2;
    virtual alu_if vif;

    function new(mailbox mb2, virtual alu_if vif);
        this.mb2 = mb2;
        this.vif = vif;
    endfunction

    task run();
        #1; // Offset by 1 time unit to sample in the middle of the BFM driving cycle
        repeat(5) begin
            tx = new();
            tx.a = vif.a;
            tx.b = vif.b;
            tx.c = vif.c;
            $display("[Monitor] Sampled pins: a = %0d, b = %0d, c = %0d", tx.a, tx.b, tx.c);
            mb2.put(tx);
            #2; // Wait 2 time units for the next sample point
        end
    endtask
endclass

class scoreboard;
    transaction tx;
    mailbox mb2;

    function new(mailbox mb2);
        this.mb2 = mb2;
    endfunction

    task run();
        repeat(5) begin
            mb2.get(tx);
            if (tx.a * tx.b == tx.c) begin
                $display("[Scoreboard] Test Passed: %0d * %0d = %0d", tx.a, tx.b, tx.c);
            end else begin
                $display("[Scoreboard] Test Failed: Expected %0d, Got %0d", tx.a * tx.b, tx.c);
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
    virtual alu_if vif;

    function new(mailbox mb, mailbox mb2, virtual alu_if vif);
        this.mb = mb;
        this.mb2 = mb2;
        this.vif = vif;
    endfunction

    task run();
        g = new(mb);
        b = new(mb, vif);
        m = new(mb2, vif);
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
    virtual alu_if vif;

    function new(virtual alu_if vif);
        this.vif = vif;
        mb = new();
        mb2 = new();
    endfunction

    task run();
        a = new(mb, mb2, vif);
        s = new(mb2);
        fork
            a.run();
            s.run();
        join
    endtask
endclass

module top;
    alu_if pif();
    environment e;
    
    // Instantiate DUT (ALU Multiplier)
    alu dut (
        .a(pif.a),
        .b(pif.b),
        .c(pif.c)
    );

    initial begin
        e = new(pif);
        e.run();
    end
endmodule
