module data_cache #(
    parameter ADDR_WIDTH        = 16,       // Width of address (word-wise)
    parameter DATA_WIDTH        = 32,       // Number of bits in each word
    parameter LINE_WIDTH        = 4,        // Number of words in a cache line
    parameter ASSOC             = 2,        // Cache associatvity
    parameter NUM_SETS          = 1024      // Number of lines in the cache
) (
    // Clock, reset
    input clk,
    input rstn,

    // Processor read interface
    input[ADDR_WIDTH-1:0]   proc_rd_addr,
    input                   proc_rd_en,
    output[DATA_WIDTH-1:0]  proc_rd_data,
    output                  proc_rd_hit,

    // Processor write interface
    input[ADDR_WIDTH-1:0]   proc_wr_addr,
    input                   proc_wr_en,
    input[DATA_WIDTH-1:0]   proc_wr_data,
    input[DATA_WIDTH/8-1:0] proc_wr_sel,
    output                  proc_wr_hit,

    output                  proc_busy,

    // Read interface with main memory
    input[DATA_WIDTH-1:0]   mem_rd_data,
    input                   mem_rd_valid,
    output[ADDR_WIDTH-1:0]  mem_rd_addr,
    output reg              mem_rd_en,

    // Write interface with main memory
    input                   mem_wr_rdy,
    output[DATA_WIDTH-1:0]  mem_wr_data,
    output[ADDR_WIDTH-1:0]  mem_wr_addr,
    output reg              mem_wr_en   
);

    localparam OFFSET_WIDTH         = $clog2(LINE_WIDTH);                       // Width of the offset field
    localparam INDEX_WIDTH          = $clog2(NUM_SETS / ASSOC);                 // Width of the index field
    localparam TAG_WIDTH            = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;  // Width of the tag field
    localparam ASSOC_LOG2           = $clog2(ASSOC);

    //-----------------------------------------------------------------------------------
    //                                  Cache blocks
    //-----------------------------------------------------------------------------------

    // Split the read address into offset, index and tag
    wire[OFFSET_WIDTH-1:0]  rd_addr_offset  = proc_rd_addr[OFFSET_WIDTH - 1 : 0];
    wire[INDEX_WIDTH-1:0]   rd_addr_index   = proc_rd_addr[OFFSET_WIDTH + INDEX_WIDTH - 1 : OFFSET_WIDTH];
    wire[TAG_WIDTH-1:0]     rd_addr_tag     = proc_rd_addr[TAG_WIDTH + INDEX_WIDTH + OFFSET_WIDTH - 1 : INDEX_WIDTH + OFFSET_WIDTH];

    // Split the read address into offset, index and tag
    wire[OFFSET_WIDTH-1:0]  wr_addr_offset  = proc_wr_addr[OFFSET_WIDTH - 1 : 0];
    wire[INDEX_WIDTH-1:0]   wr_addr_index   = proc_wr_addr[OFFSET_WIDTH + INDEX_WIDTH - 1 : OFFSET_WIDTH];
    wire[TAG_WIDTH-1:0]     wr_addr_tag     = proc_wr_addr[TAG_WIDTH + INDEX_WIDTH + OFFSET_WIDTH - 1 : INDEX_WIDTH + OFFSET_WIDTH];

    // Cache hit and valid signals
    wire[ASSOC-1:0]         cache_rd_hit;
    wire[ASSOC-1:0]         cache_wr_hit;
    wire[ASSOC-1:0]         cache_wr_valid;

    assign proc_rd_hit      = |cache_rd_hit;

    // Cache data signals
    wire[DATA_WIDTH-1:0]    cache_rd_data[ASSOC-1:0];
    wire[DATA_WIDTH-1:0]    cache_wr_data;

    // Cache write address signals
    wire[INDEX_WIDTH-1:0]   cache_wr_index;
    wire[OFFSET_WIDTH-1:0]  cache_wr_offset;
    wire[TAG_WIDTH-1:0]     cache_wr_tag;

    // Cache write control signals
    wire                    cache_wr_en;        // Enable writing to cache
    wire                    cache_wr_fin;       // Write tag and valid to cace
    reg[ASSOC-1:0]          cache_wr_blksel;       // Select signals to cache blocks
    reg[ASSOC_LOG2-1:0]     cache_wr_blk;       // Which block to select?
    reg[DATA_WIDTH/8-1:0]   cache_wr_sel = -1;

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

                .wr_index(cache_wr_index),
                .wr_offset(cache_wr_offset),
                .wr_tag(cache_wr_tag),
                .wr_data(cache_wr_data),      
                .wr_sel(cache_wr_sel),
                .wr_en(cache_wr_blksel[g_cache] && cache_wr_en),
                .wr_new(cache_wr_blksel[g_cache] && cache_wr_fin),
                .wr_hit(cache_wr_hit[g_cache]),
                .wr_valid(cache_wr_valid[g_cache])
            );
        end
    endgenerate

    // Processor read from cache
    reg[DATA_WIDTH-1:0]     proc_rd_data;

    // Multiplex reads from cache blocks
    integer i_cacherd;
    always @(*) begin
        proc_rd_data = 0;
        for(i_cacherd = 0; i_cacherd < ASSOC; i_cacherd = i_cacherd + 1)
            if(cache_rd_hit[i_cacherd])
                proc_rd_data = cache_rd_data[i_cacherd];        
    end

    // Cache replacement policy (choose cache_wr_block based on which blocks are hitting and which are valid)
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
    // cache_wr_blksel is encoded version of cache_blk_sel
    integer i_cachepr;
    always @(*) begin
        cache_wr_blksel                = 0;
        cache_wr_blksel[cache_wr_blk]  = 1'b1;        
    end

    //-----------------------------------------------------------------------------------
    //                                      FSM
    //-----------------------------------------------------------------------------------

    reg[1:0]                fsm_state = 0;
    reg[1:0]                fsm_next_state;

    reg[OFFSET_WIDTH:0]     fsm_counter = 0;
    reg[OFFSET_WIDTH:0]     fsm_next_count;

    wire                    fsm_read_fin = fsm_counter[OFFSET_WIDTH];
    
    localparam s_IDLE  = 2'd0;
    localparam s_WRITE = 2'd1;
    localparam s_READ  = 2'd2;

    always @(posedge clk) begin
        if(~rstn) begin
            fsm_state       <= s_IDLE;
            fsm_counter     <= 0;
        end else begin
            fsm_state       <= fsm_next_state;
            fsm_counter     <= fsm_next_count;
        end
    end
    
    // Next state logic
    always @(*) begin
        fsm_next_state = s_IDLE;
        mem_rd_en      = 0;
        mem_wr_en      = 0;
        fsm_next_count = 0;

        case(fsm_state)
            s_IDLE: begin
                if(proc_rd_en) begin
                    // Check for read miss
                    fsm_next_state = proc_rd_hit ? s_IDLE : s_READ ;    // If read miss, start memory read
                    mem_rd_en      = proc_rd_hit ?  1'b0  :  1'b1  ;
                    mem_wr_en      = 1'b0;
                end else if(proc_wr_en) begin
                    // Write to main memory
                    if(mem_wr_rdy)
                        fsm_next_state = proc_wr_hit ? s_IDLE : s_READ; // If write miss and memory is ready to write, read the block next
                    else
                        fsm_next_state = s_WRITE;                       // Wait till memory is ready to write
                    mem_rd_en      = 1'b0;      // No need to read here!
                    mem_wr_en      = 1'b1;      // Write to memory in next cycle
                end else begin
                    fsm_next_state = s_IDLE;
                    mem_rd_en      = 1'b0;
                    mem_wr_en      = 1'b0;
                end
                fsm_next_count = 0;
            end
            s_WRITE: begin
                // Wait for write ready
                if(mem_wr_rdy)
                    fsm_next_state = proc_wr_hit ? s_IDLE : s_READ;     // If write miss, read the block next
                else
                    fsm_next_state = s_WRITE;                           // Wait till memory is ready to write
                mem_rd_en       = 1'b1;
                mem_wr_en       = 1'b1;
                fsm_next_count  = 0;
            end
            s_READ: begin
                // Read all blocks from memory
                fsm_next_state = fsm_read_fin ? s_IDLE : s_READ;                    // Keep reading till 
                mem_rd_en      = ~fsm_read_fin;                                     // Read till the last word is sent
                mem_wr_en      = 1'b0;
                fsm_next_count = mem_rd_valid ? fsm_counter + 1'b1 : fsm_counter;   // Count up the words read
            end
        endcase
    end

    assign proc_busy = (fsm_state != s_IDLE);

    //-----------------------------------------------------------------------------------
    //                                  To / From Memory
    //-----------------------------------------------------------------------------------
    // Registers to hold address read from memory    
    reg[INDEX_WIDTH-1:0]   mem_addr_index;
    reg[TAG_WIDTH-1:0]     mem_addr_tag;
    
    wire[OFFSET_WIDTH-1:0] mem_addr_offset      = fsm_next_count;

    wire cache_wr_src = (fsm_state == s_READ);       // 0 for processor, 1 for memory (for reading cache line into mem)

    assign cache_wr_index   = cache_wr_src ? mem_addr_index  : wr_addr_index;
    assign cache_wr_offset  = cache_wr_src ? fsm_counter-1'b1: wr_addr_offset;
    assign cache_wr_tag     = cache_wr_src ? mem_addr_tag    : wr_addr_tag;
    assign cache_wr_data    = cache_wr_src ? mem_rd_data     : proc_wr_data;

    assign mem_wr_addr = proc_wr_addr;
    assign mem_wr_data = proc_wr_data;      // Todo : Write alignment (byte/short)

    assign cache_wr_en  = cache_wr_src ? mem_rd_valid : proc_wr_en;
    assign cache_wr_fin = cache_wr_src ? fsm_read_fin : 1'b0;
    
    assign proc_wr_hit      = cache_wr_src ? 1'b0 : (|cache_wr_hit);
    
    reg[INDEX_WIDTH-1:0]    next_mem_index;
    reg[TAG_WIDTH-1:0]      next_mem_tag;

    always @(posedge clk) begin
        if(~rstn) begin
            mem_addr_index  <= 0;
            mem_addr_tag    <= 0;            
        end else begin
            mem_addr_index  <= next_mem_index;
            mem_addr_tag    <= next_mem_tag;
        end
    end

    always @(*) begin
        next_mem_index = mem_addr_index;
        next_mem_tag   = mem_addr_tag;

        if(fsm_state == s_IDLE) begin
            if(proc_rd_en && ~proc_rd_hit) begin          // Read miss : Latch read address
                next_mem_index  = rd_addr_index;
                next_mem_tag    = rd_addr_tag;
            end
            else if(proc_wr_en && ~proc_wr_hit) begin     // Write miss : Latch write address
                next_mem_index  = wr_addr_index;
                next_mem_tag    = wr_addr_tag;
            end
        end
    end

    // Send next memory address dire
    assign mem_rd_addr = (fsm_state == s_READ) ? {mem_addr_tag, mem_addr_index, mem_addr_offset} : {next_mem_tag, next_mem_index, {OFFSET_WIDTH{1'b0}}};

endmodule
