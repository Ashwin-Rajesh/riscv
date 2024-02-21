module data_cache_tb;

    localparam ADDR_WIDTH        = 16;       // Width of address (word-wise)
    localparam DATA_WIDTH        = 32;       // Number of bits in each word
    localparam LINE_WIDTH        = 4;        // Number of words in a cache line
    localparam NUM_SETS         = 128;      // Number of lines in the cache
    localparam ASSOC            = 2;

    reg clk;
    reg rstn;

    // Processor read interface
    bit[ADDR_WIDTH-1:0] proc_rd_addr;
    bit proc_rd_en;
    wire[DATA_WIDTH-1:0] proc_rd_data;
    wire proc_rd_hit;

    // Processor write interface
    bit[ADDR_WIDTH-1:0] proc_wr_addr  = -1;
    bit proc_wr_en = 1'b0;
    bit[DATA_WIDTH-1:0] proc_wr_data;
    bit[DATA_WIDTH/8-1:0] proc_wr_sel = 4'b0;
    wire proc_wr_hit;
    wire proc_busy;

    // Read interface with main memory
    bit[DATA_WIDTH-1:0]  mem_rd_data;
    bit mem_rd_valid;
    wire[ADDR_WIDTH-1:0] mem_rd_addr;
    wire mem_rd_en;

    // Write interface with main memory
    wire mem_wr_rdy = 1'b1;
    wire[DATA_WIDTH-1:0] mem_wr_data;
    wire[ADDR_WIDTH-1:0] mem_wr_addr;
    wire mem_wr_en;

    data_cache #(
        .ADDR_WIDTH         ( ADDR_WIDTH        ),
        .DATA_WIDTH         ( DATA_WIDTH        ),
        .LINE_WIDTH         ( LINE_WIDTH        ),
        .ASSOC              ( ASSOC            ),
        .NUM_SETS           ( NUM_SETS         )
    ) dut (
        .clk                ( clk               ),
        .rstn               ( rstn              ),
        
        .proc_rd_addr       ( proc_rd_addr      ),
        .proc_rd_en         ( proc_rd_en        ),
        .proc_rd_data       ( proc_rd_data     ),
        .proc_rd_hit        ( proc_rd_hit        ),
        
        .proc_wr_addr       ( proc_wr_addr      ),
        .proc_wr_en         ( proc_wr_en        ),
        .proc_wr_data       ( proc_wr_data     ),
        .proc_wr_sel        ( proc_wr_sel        ),
        .proc_wr_hit        ( proc_wr_hit        ), 
        .proc_busy          ( proc_busy          ),

        .mem_rd_data        ( mem_rd_data        ),
        .mem_rd_valid       ( mem_rd_valid        ),
        .mem_rd_addr        ( mem_rd_addr      ),
        .mem_rd_en          ( mem_rd_en          ),

        .mem_wr_rdy         ( mem_wr_rdy        ),
        .mem_wr_data        ( mem_wr_data        ),
        .mem_wr_addr        ( mem_wr_addr      ),
        .mem_wr_en          ( mem_wr_en          )
    );
    
    // Simulate main memory
    bit[ADDR_WIDTH-1:0] main_mem[1023:0];
    
    initial begin
        for(int i = 0; i < 1024; i = i + 1)
                main_mem[i] = i ** 2;
    end
    
    always @(posedge clk) begin
        if(mem_wr_en)
                main_mem[mem_wr_addr] = mem_wr_data;
    end
        bit[ADDR_WIDTH-1:0] mem_rd_addr2;
    
    always @(posedge clk) mem_rd_addr2 <= mem_rd_addr;
    always @(posedge clk) mem_rd_data  <= main_mem[mem_rd_addr2];
    
    always @(posedge clk) if(proc_rd_hit) assert(proc_rd_data == main_mem[proc_rd_addr]) else $error("Read not matching memory value!");
        
    always #5 clk = ~clk;
    
    initial begin
        clk     <= 0;
        rstn    <= 0;
        
        @(negedge clk) 
        @(negedge clk) rstn <= 1;

        proc_rd_en   <= 1;
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
         
        proc_rd_addr <= 20;
        proc_wr_addr <= 16;
        proc_wr_data <= 16 * 5;
        proc_rd_en   <= 1'b0;
        proc_wr_en   <= 1'b1;
        
        repeat(20) begin
                @(negedge clk);
                while(~proc_wr_hit || proc_busy) @(negedge clk);
                proc_wr_addr <= proc_wr_addr + 1;
                proc_wr_data <= (proc_wr_addr + 1) * 5;
        end
        
        proc_rd_en   <= 1'b1;
        proc_wr_en   <= 1'b0;
         
        proc_rd_addr <= 16;
        repeat(32) begin
                @(negedge clk);
                while(~proc_rd_hit) @(negedge clk);
                proc_rd_addr <= proc_rd_addr + 1;
        end

         $finish;
    end
    
    initial begin
        mem_rd_valid <= 0;
        
        repeat(10) @(negedge clk);
        mem_rd_valid <= 1;
    end

endmodule