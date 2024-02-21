module block_mem #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH  = 2048
) (
    input clk,
    input rstn,

    input[ADDR_WIDTH-1:0]   rd_addr,
    output[DATA_WIDTH-1:0]  rd_data,

    input[ADDR_WIDTH-1:0]   wr_addr,
    input[DATA_WIDTH-1:0]   wr_data,
    input                   wr_en
);

    reg[ADDR_WIDTH-1:0] rd_addr_reg = 0;
    reg[DATA_WIDTH-1:0] rd_data;

    reg[DATA_WIDTH-1:0] mem[MEM_DEPTH-1:0];

    integer i;
    initial begin
        for(i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 0;

            `ifdef INSTN_INIT_MEM_FILE
                $display("Reading instruction memory file %s", `INSTN_INIT_MEM_FILE);
                $readmemb(`INSTN_INIT_MEM_FILE, mem);    
            `else
                $display("Instruction memory file not defined! Using all 0s!!!");
            `endif
    end

    always @(posedge clk) begin
        if(~rstn) begin
            rd_addr_reg <= 0;        
            rd_data     <= 0;
        end else begin
            rd_addr_reg <= rd_addr;
            rd_data     <= mem[rd_addr_reg];
        end
    end

    always @(posedge clk) if(~rstn && wr_en) mem[wr_addr] <= wr_data;

endmodule
