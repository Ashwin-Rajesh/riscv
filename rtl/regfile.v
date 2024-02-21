module regfile #(
    parameter REG_ADDR_WIDTH    = 5,
    parameter REG_WIDTH         = 32,
    parameter REGFILE_DEPTH     = 32
) (
    input clk,
    input rstn,                 // Synchronous reset

    input[REG_ADDR_WIDTH-1:0] 
        rs1_addr,
        rs2_addr,
        rd_addr,

    output[REG_WIDTH-1:0]       // Asynchronous reads   
        rs1_out,
        rs2_out,
    input[REG_WIDTH-1:0]    
        rd_inp,

    input write_en              // Write to dest register
);

    // Regfile memory
    reg[REG_WIDTH-1:0]      memory[REGFILE_DEPTH-1:1];

    integer i;

    // Intialize registers to 0
    initial begin
        for(i = 1; i < REGFILE_DEPTH; i = i + 1)
            memory[i]   = 0;
    end

    // Asynchronous read
    assign rs1_out = (rs1_addr == 0) ? 0 : memory[rs1_addr];
    assign rs2_out = (rs2_addr == 0) ? 0 : memory[rs2_addr];

    // Reset and rd write
    always @(posedge clk) begin
        if(~rstn) begin
            for(i = 1; i < REGFILE_DEPTH; i = i + 1)
                memory[i]           <= 0;
        end else begin 
            // Synchronous write
            if(write_en)
                if(rd_addr != 0)
                    memory[rd_addr]     <= rd_inp;
        end 
    end
endmodule
