module instn_cache #(
    parameter ADDR_WIDTH        = 16,       // Width of address (word-wise)
    parameter DATA_WIDTH        = 32,       // Number of bits in each word
    parameter LINE_WIDTH        = 4,        // Number of words in a cache line
    parameter ASSOC             = 2,        // Cache associatvity
    parameter NUM_SETS          = 1024      // Number of lines in the cache
) (
    // Clock, reset
    input clk,
    input rstn,

    // Interface with the processor
    input[ADDR_WIDTH-1:0]   proc_rd_addr,
    input                   proc_rd_en,

    output[DATA_WIDTH-1:0]  proc_rd_data,
    output                  proc_rd_hit,
    output                  proc_busy,

    // Interface with main memory
    input[DATA_WIDTH-1:0]   mem_rd_data,
    input                   mem_rd_valid,
    output[ADDR_WIDTH-1:0]  mem_rd_addr,
    output reg              mem_rd_en   
);

    localparam OFFSET_WIDTH         = $clog2(LINE_WIDTH);                       // Width of the offset field
    localparam INDEX_WIDTH          = $clog2(NUM_SETS / ASSOC);                 // Width of the index field
    localparam TAG_WIDTH            = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;  // Width of the tag field

    // Split the read address into offset, index and tag
    wire[OFFSET_WIDTH-1:0]  rd_addr_offset  = proc_rd_addr[OFFSET_WIDTH - 1 : 0];
    wire[INDEX_WIDTH-1:0]   rd_addr_index   = proc_rd_addr[OFFSET_WIDTH + INDEX_WIDTH - 1 : OFFSET_WIDTH];
    wire[TAG_WIDTH-1:0]     rd_addr_tag     = proc_rd_addr[TAG_WIDTH + INDEX_WIDTH + OFFSET_WIDTH - 1 : INDEX_WIDTH + OFFSET_WIDTH];

    // Cache hit and valid signals
    wire[ASSOC-1:0]         cache_rd_hit;
    wire[ASSOC-1:0]         cache_wr_hit;
    wire[ASSOC-1:0]         cache_wr_valid;

    wire[DATA_WIDTH-1:0]    cache_rd_data[ASSOC-1:0];

    // Cache replacement policy
    reg[ASSOC-1:0]          cache_wr_sel;

    localparam ASSOC_LOG2   = $clog2(ASSOC);
    reg[ASSOC_LOG2-1:0]     cache_wr_blk;
    integer i_cachewr;
    always @(*) begin
        cache_wr_blk = 0;
        if(|cache_wr_hit) begin
            // If any of the blocks hit, just use that
            for(i_cachewr = 0; i_cachewr < ASSOC; i_cachewr = i_cachewr + 1)
                if(cache_wr_hit[i_cachewr])
                    cache_wr_blk = i_cachewr;
        end else if(|(~cache_wr_valid)) begin
            // If there are no hits but some invalid (empty) cache blocks, just fill the first one
            for(i_cachewr = 0; i_cachewr < ASSOC; i_cachewr = i_cachewr + 1)
                if(~cache_wr_valid[i_cachewr])
                    cache_wr_blk = i_cachewr;
        end else begin
            // No hits, no invalids (replacement. current policy : replace first block)
            cache_wr_blk = 0;
        end
    end
    integer i_cachepr;
    always @(*) begin
        cache_wr_sel                = 0;
        cache_wr_sel[cache_wr_blk]  = 1'b1;        
    end
    
    assign                  proc_rd_hit     = |cache_rd_hit;
    reg[DATA_WIDTH-1:0]     proc_rd_data;

    // Multiplex cache blocks in same set
    integer i_cacherd;
    always @(*) begin
        proc_rd_data = 0;
        for(i_cacherd = 0; i_cacherd < ASSOC; i_cacherd = i_cacherd + 1)
            if(cache_rd_hit[i_cacherd])
                proc_rd_data = cache_rd_data[i_cacherd];        
    end

    // FSM definition
    localparam 
            s_IDLE = 0,
            s_MISS = 1;
    
    reg[OFFSET_WIDTH:0]     fsm_counter = 0;
    reg                     fsm_state   = s_IDLE;

    reg[OFFSET_WIDTH:0]     fsm_next_count;
    reg                     fsm_next_state;

    wire                    fsm_read_fin = fsm_counter[OFFSET_WIDTH];
    
    // Registers to hold address read from memory    
    reg[INDEX_WIDTH-1:0]   mem_addr_index;
    reg[TAG_WIDTH-1:0]     mem_addr_tag;
    
    wire[OFFSET_WIDTH-1:0] mem_addr_offset      = fsm_next_count;
    wire[OFFSET_WIDTH-1:0] cache_write_offset   = fsm_counter - 1'b1;

    genvar g_cache;
    generate
        for(g_cache = 0; g_cache < ASSOC; g_cache = g_cache + 1) begin: cache
            cache_block #(
                .DATA_WIDTH(DATA_WIDTH),
                .OFFSET_WIDTH(OFFSET_WIDTH),
                .INDEX_WIDTH(INDEX_WIDTH),
                .TAG_WIDTH(TAG_WIDTH)
            ) cache_block_instn (
                .clk(clk),
                .rstn(rstn),

                .rd_index(rd_addr_index),
                .rd_offset(rd_addr_offset),
                .rd_tag(rd_addr_tag),
                .rd_hit(cache_rd_hit[g_cache]),
                .rd_data(cache_rd_data[g_cache]),

                .wr_index(mem_addr_index),
                .wr_offset(cache_write_offset),
                .wr_tag(mem_addr_tag),
                .wr_data(mem_rd_data),
                .wr_sel(4'b1111),        
                .wr_en(cache_wr_sel[g_cache] && proc_busy && mem_rd_valid),
                .wr_new(cache_wr_sel[g_cache] && proc_busy && fsm_read_fin),
                .wr_hit(cache_wr_hit[g_cache]),
                .wr_valid(cache_wr_valid[g_cache])
            );
        end
    endgenerate

    always @(posedge clk) begin
        if(~rstn) begin
            fsm_state       <= s_IDLE;
            fsm_counter     <= 0;
            mem_addr_index  <= 0;
            mem_addr_tag    <= 0;            
        end else begin
            fsm_state       <= fsm_next_state;
            fsm_counter     <= fsm_next_count;
            mem_addr_index  <= ((fsm_state == s_IDLE) && proc_rd_en) ? rd_addr_index : mem_addr_index;
            mem_addr_tag    <= ((fsm_state == s_IDLE) && proc_rd_en) ? rd_addr_tag   : mem_addr_tag;
        end
    end
    
    always @(*) begin
        fsm_next_state = s_IDLE;
        mem_rd_en      = 0;
        fsm_next_count = 0;

        case(fsm_state)
            s_IDLE: begin
                fsm_next_state = (~proc_rd_hit && proc_rd_en) ? s_MISS : s_IDLE;
                mem_rd_en      = (~proc_rd_hit && proc_rd_en) ?  1'b1  :  1'b0 ;
                fsm_next_count = 0;
            end
            s_MISS: begin
                fsm_next_state = fsm_read_fin ? s_IDLE : s_MISS;
                mem_rd_en      = ~fsm_counter[OFFSET_WIDTH];
                fsm_next_count = mem_rd_valid ? fsm_counter + 1'b1 : fsm_counter;
            end
        endcase
    end

    assign proc_busy = (fsm_state != s_IDLE);

    // In idle state, send the proc req addr directly to memory. Else we will need to spend an additional cycle to get it from the mem_addr_tag and mem_addr_index registers
    assign mem_rd_addr = (fsm_state == s_IDLE) ? {proc_rd_addr[ADDR_WIDTH-1:OFFSET_WIDTH],{OFFSET_WIDTH{1'b0}}} : {mem_addr_tag, mem_addr_index, mem_addr_offset};

endmodule
