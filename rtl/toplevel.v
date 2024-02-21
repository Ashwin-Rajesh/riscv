`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.10.2023 12:25:35
// Design Name: 
// Module Name: toplevel
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module toplevel(
    input clk,
    input btnC,
    input btnU,
    
    output[6:0] seg,
    output[3:0] an
);

    wire en;
    wire rst;
    wire rstn = ~rst;

    debouncer #(.debounce_cycles(100000)) btnc_dbnc(
        .clk(clk),
        .rst(1'b0),
        .inp(btnC),
        .out(en)
    );
    
    debouncer #(.debounce_cycles(100000)) btnu_dbnc(
        .clk(clk),
        .rst(1'b0),
        .inp(btnU),
        .out(rst)
    );
    
    rv32i proc_inst(
        .clk(clk),
        .rstn(rstn),
        .stall(~en)
    );
    
    seven_segment_out #(.clkdiv_ratio(10000)) seven_seg_out_inst(
        .clk(clk),
        .rst(rst),
        .inp(proc_inst.reg_file.memory[27][15:0]),
        .sel(an),
        .data(seg)
    );
    
//    ila_0 ila_inst(
//        .clk(clk),
//        .probe0(proc_inst.fe_de_pc),
//        .probe1(proc_inst.reg_file.memory[27]),
//        .probe2(rst)
//    );
    
endmodule
