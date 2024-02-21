`timescale 1ns / 1ps

module testbench;

    reg clk     = 0;
    reg rstn    = 1;
    reg stall   = 0;

    rv32i uut(
        .clk(clk),
        .rstn(rstn),
        .stall(stall)
    );
    
    always #5 clk = ~clk;
    
    always @(negedge clk) stall = $random;
    
    initial begin
        @(posedge clk);
        rstn = 0;
        repeat(5) @(posedge clk);
        rstn = 1;
        
        repeat(1000) @(posedge clk);
        $finish;
    end

endmodule
