module cache_block #(
    parameter DATA_WIDTH        = 32,       // Number of bits in each word
    parameter OFFSET_WIDTH      = 2,        // Number of bits in the word address offset
    parameter INDEX_WIDTH       = 5,        // Number of bits in the cache index
    parameter TAG_WIDTH         = 5         // Number of bits in the cache tag
) (
    input                   clk,
    input                   rstn,

    input[INDEX_WIDTH-1:0]  rd_index,
    input[OFFSET_WIDTH-1:0] rd_offset,
    input[TAG_WIDTH-1:0]    rd_tag,
    output                  rd_hit,
    output[DATA_WIDTH-1:0]  rd_data,

    input[INDEX_WIDTH-1:0]  wr_index,
    input[OFFSET_WIDTH-1:0] wr_offset,
    input[TAG_WIDTH-1:0]    wr_tag,
    input[DATA_WIDTH-1:0]   wr_data,        // Data to write
    input[DATA_WIDTH/8-1:0] wr_sel,         // Which bytes to write?
    input                   wr_en,          // Write data into cache location
    input                   wr_new,         // Writing a new block (for valid and tag bits)
    output                  wr_hit,
    output                  wr_valid
);
    localparam NUM_SETS     = 2 ** INDEX_WIDTH;
    localparam LINE_WIDTH   = 2 ** OFFSET_WIDTH;

    // Cache tag, valid bits and data memories
    reg[TAG_WIDTH-1:0]      cache_tag_mem [NUM_SETS-1:0];
    reg[NUM_SETS-1:0]       cache_valid_mem             = 0;
    reg[DATA_WIDTH-1:0]     cache_data_mem[NUM_SETS-1:0][LINE_WIDTH-1:0];

    // Cache hit signals
    assign rd_hit = (cache_valid_mem[rd_index] && (cache_tag_mem[rd_index] == rd_tag));
    assign wr_hit = (cache_valid_mem[wr_index] && (cache_tag_mem[wr_index] == wr_tag));
    assign wr_valid = (cache_valid_mem[wr_index]);

    // Cache read
    assign rd_data = cache_data_mem[rd_index][rd_offset];

    // Cache data write
    integer i;
    always @(posedge clk)
        if(wr_en)
            for(i = 0; i < DATA_WIDTH/8; i = i + 1)
                if(wr_sel[i])
                    cache_data_mem[wr_index][wr_offset][i*8+:8] = wr_data[i*8+:8];
    // always @(posedge clk)
    //     if(wr_en)
    //         cache_data_mem[wr_index][wr_offset] = wr_data;

    // Cache tag and valid write
    always @(posedge clk)
        if(~rstn)
            cache_valid_mem <= 0;
        else if(wr_en && wr_new) begin
            cache_valid_mem[wr_index]   <= 1'b1;
            cache_tag_mem[wr_index]     <= wr_tag;
        end

endmodule
