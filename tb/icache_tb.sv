module instn_cache_tb;

    localparam ADDR_WIDTH        = 16;       // Width of address (word-wise)
    localparam DATA_WIDTH        = 32;       // Number of bits in each word
    localparam LINE_WIDTH        = 4;        // Number of words in a cache line
    localparam NUM_SETS         = 128;      // Number of lines in the cache

    reg clk   = 0;
    reg rstn  = 0;

    // Interface with the processor
    reg[ADDR_WIDTH-1:0] proc_rd_addr  = 0;
    reg proc_rd_en                    = 0;

    wire[DATA_WIDTH-1:0] proc_rd_data;
    wire proc_rd_hit;
    wire proc_busy;

    // Interface with main memory
    reg[DATA_WIDTH-1:0]  mem_rd_data  = 0;
    reg mem_rd_rdy                    = 0;
    wire[ADDR_WIDTH-1:0] mem_rd_addr;
    wire mem_rd_en;

    // Instantiate the instn_cache module
    instn_cache #(
        .ADDR_WIDTH        ( ADDR_WIDTH        ),
        .DATA_WIDTH        ( DATA_WIDTH        ),
        .LINE_WIDTH        ( LINE_WIDTH        ),
        .NUM_SETS         ( NUM_SETS         )
    ) dut (
        .clk               ( clk               ),
        .rstn              ( rstn              ),
        .proc_rd_addr      ( proc_rd_addr      ),
        .proc_rd_en        ( proc_rd_en        ),
        .proc_rd_data     ( proc_rd_data     ),
        .proc_rd_hit        ( proc_rd_hit        ),
        .proc_busy          ( proc_busy          ),
        .mem_rd_data        ( mem_rd_data        ),
        .mem_rd_valid     ( mem_rd_rdy),
        .mem_rd_addr      ( mem_rd_addr      ),
        .mem_rd_en          ( mem_rd_en          )
    );
    
    always #5 clk = ~clk;
    
    
    reg[ADDR_WIDTH-1:0] mem_rd_addr2;
    
    always @(posedge clk) mem_rd_addr2 <= mem_rd_addr;
    always @(posedge clk) mem_rd_data  <= mem_rd_addr2 ** 2;
    
    initial begin
        @(negedge clk)
        proc_rd_en   <= 1;
        
        repeat(10) @(negedge clk);
        mem_rd_rdy <= 1;
    end

    initial begin
        clk  <= 0;
        rstn <= 1;
        proc_rd_addr <= 0;
        
        @(negedge clk)
        rstn <= 0;

        @(negedge clk)
        rstn <= 1;

        // Read 0 to 10    
        repeat(10) begin
                @(negedge clk);
                while(~proc_rd_hit) @(negedge clk);
                proc_rd_addr <= proc_rd_addr + 3;
        end
        
        // Read 512 to 522
        proc_rd_addr <= 512;
        repeat(10) begin
                @(negedge clk);
                while(~proc_rd_hit) @(negedge clk);
                proc_rd_addr <= proc_rd_addr + 3;
        end
        
        // Read 0 to 27
        proc_rd_addr <= 0;
        repeat(28) begin
                @(negedge clk);
                while(~proc_rd_hit) @(negedge clk);
                proc_rd_addr <= proc_rd_addr + 1;
        end

        proc_rd_addr <= 512;
        repeat(30) begin
                @(negedge clk);
                while(~proc_rd_hit) @(negedge clk);
                proc_rd_addr <= proc_rd_addr + 1;
        end
         
         $finish;
    end
    
    always @(posedge clk) begin
        if(proc_rd_hit) assert(proc_rd_data == proc_rd_addr ** 2) else $error("read mismatch!");
    end
    
endmodule
