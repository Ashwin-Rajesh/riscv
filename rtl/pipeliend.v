 module rv32i (
    input clk,
    input rstn,
    input stall
);

    parameter ADDR_WIDTH    = 16;
    parameter MEM_DEPTH     = 1024;

    // Writeback data
    wire [31:0]     wb_rd_data;

    //-------------------------------------------------------------------------
    //                                  Stall signals

    wire fe_bubble;
    wire de_bubble;
    wire ex_bubble;
    wire mem_bubble;

    wire fe_stall;
    wire de_stall;
    wire ex_stall;
    wire mem_stall;
    wire wb_stall;
    
    wire full_stall;

    //-------------------------------------------------------------------------
    //                                  Fetch Stage

    reg [31:0]      fe_de_pc    = 32'd0 - 32'd4;
    reg             fe_de_valid = 0;
    reg [31:0]      fe_de_instn = 0;

    // Instruction Memory
    wire            fetch_branch_taken;
    wire[31:0]      fetch_branch_tgt;
    wire[31:0]      fetch_addr = fetch_branch_taken ? fetch_branch_tgt : (fe_stall ? fe_de_pc : fe_de_pc + 32'd4);
    wire[31:0]      fetch_instn_out;
    
    reg[31:0] mem_in_pc;
    
    // Interface with the processor
    wire          fetch_hit;
    wire          fetch_proc_busy;

    // Interface with main memory
    wire[31:0]    fetchmem_rd_data;
    wire          fetchmem_rd_valid;
    wire[15:0]    fetchmem_rd_addr;
    wire          fetchmem_rd_en;

    // Instantiate the instn_cache module
    instn_cache #(
        .ADDR_WIDTH (16),
        .DATA_WIDTH (32),
        .LINE_WIDTH (4),
        .ASSOC      (2),
        .NUM_SETS   (16)
    ) icache_inst (
        .clk               ( clk               ),
        .rstn              ( rstn              ),
        .proc_rd_addr      ( fetch_addr[31:2]    ),
        .proc_rd_en        ( 1'b1              ),
        .proc_rd_data      ( fetch_instn_out   ),
        .proc_rd_hit       ( fetch_hit         ),
        .proc_busy         ( fetch_proc_busy   ),
        .mem_rd_data       ( fetchmem_rd_data  ),
        .mem_rd_valid      ( fetchmem_rd_valid ),
        .mem_rd_addr       ( fetchmem_rd_addr  ),
        .mem_rd_en         ( fetchmem_rd_en    )
    );
  
    reg[15:0]     fetchmem_rd_addr2 = 0;
    always @(posedge clk) begin
        if(~rstn)
            fetchmem_rd_addr2 <= 0;
        else
            fetchmem_rd_addr2 <= fetchmem_rd_addr;
    end

    always @(posedge clk) begin
        if(~rstn) begin
            fe_de_pc    <= 32'd0 - 32'd4;
            fe_de_valid <= 1'b0;
            fe_de_instn <= 32'b0;
        end else if(~fe_stall) begin
            if(fe_bubble) begin
                fe_de_valid <= 1'b0;
            end else begin
                fe_de_pc    <= fetch_addr;
                fe_de_valid <= 1'b1;
                fe_de_instn <= fetch_instn_out;
            end
        end
    end
    
    // assign fe_de_instn = fetch_instn_out;
    
    //-------------------------------------------------------------------------
    //                                  Decode Stage    

    // Decode Stage
    wire [6:0]      decode_opcode;
    wire [6:0]      decode_func7;
    wire [2:0]      decode_func3;
    wire [2:0]      decode_format;
    
    wire [4:0]      decode_rs1_addr;
    wire [4:0]      decode_rs2_addr;
    wire [4:0]      decode_rd_addr;
    wire            decode_reg_wr_en;

    wire [31:0]     decode_rs1_data;
    wire [31:0]     decode_rs2_data;
    wire [31:0]     decode_imm;

    wire [2:0]      decode_alu_mode;
    wire [1:0]      decode_eval_mode;
    wire            decode_sign_ext;
    
    wire [1:0]      decode_in1_sel;
    wire [1:0]      decode_in2_sel;
    wire            decode_out_sel;

    wire            decode_branch_en;
    wire            decode_branch_cond;
    wire            decode_branch_base_sel;

    wire            decode_mem_wr_en;
    wire            decode_mem_rd_en;
    wire[1:0]       decode_mem_type;
    wire            decode_mem_signed;

    wire [31:0]     reg_wr_data;
    wire [4:0]      reg_wr_addr;
    wire            reg_wr_en;

    // Instruction decode
    decode_instn decode_instn_inst (
        .inst       (fe_de_instn),
        .opcode     (decode_opcode),
        .func7      (decode_func7),
        .func3      (decode_func3),
        .format     (decode_format)
    );

    // Decode register signals
    decode_regs decode_regs_inst (
        .inst       (fe_de_instn),
        .opcode     (decode_opcode),
        .rs1        (decode_rs1_addr),
        .rs2        (decode_rs2_addr),
        .rd         (decode_rd_addr),
        .reg_wr_en  (decode_reg_wr_en)
    );

    // Register file
    regfile #(
        .REG_ADDR_WIDTH(5),
        .REG_WIDTH(32),
        .REGFILE_DEPTH(32)
    ) reg_file (
        .clk        (clk),
        .rstn       (rstn),

        .rs1_addr   (decode_rs1_addr),
        .rs2_addr   (decode_rs2_addr),
        .rd_addr    (reg_wr_addr),

        .rs1_out    (decode_rs1_data),
        .rs2_out    (decode_rs2_data),
        .rd_inp     (reg_wr_data),

        .write_en   (reg_wr_en)
    );

    // ALU control and select decode
    decode_alu decode_alu_inst (
        .opcode     (decode_opcode),
        .func7      (decode_func7),
        .func3      (decode_func3),

        .alu_mode   (decode_alu_mode),
        .eval_mode  (decode_eval_mode),
        .sign_ext   (decode_sign_ext),

        .in1_sel    (decode_in1_sel),
        .in2_sel    (decode_in2_sel),
        .out_sel    (decode_out_sel)
    );

    // Decode Branch
    decode_branch decode_branch (
        .opcode         (decode_opcode),
        .func7          (decode_func7),
        .func3          (decode_func3),

        .branch_en      (decode_branch_en),
        .branch_cond    (decode_branch_cond),
        .branch_base_sel(decode_branch_base_sel)
    );

    // Decode Immediate
    decode_imm decode_imm_inst (
        .inst           (fe_de_instn),
        .inst_format    (decode_format),
        .immediate      (decode_imm)
    );

    // Decode memory signals
    decode_mem decode_mem_inst (
        .opcode     (decode_opcode),
        .func7      (decode_func7),
        .func3      (decode_func3),
        .mem_type   (decode_mem_type),
        .mem_signed (decode_mem_signed),
        .mem_wr_en  (decode_mem_wr_en),
        .mem_rd_en  (decode_mem_rd_en)
    );
    
    // Decode - Execute pipeline
    reg [31:0]      de_ex_pc        = 0;
    reg [6:0]       de_ex_opcode    = 0;
    // reg [6:0]       de_ex_func7;
    // reg [2:0]       de_ex_func3;
    // reg [2:0]       de_ex_format;
    reg [4:0]       de_ex_rs1_addr          = 0;
    reg [4:0]       de_ex_rs2_addr          = 0;
    reg [4:0]       de_ex_rd_addr           = 0;
    reg             de_ex_reg_wr_en         = 0;
    reg [31:0]      de_ex_rs1_data          = 0;
    reg [31:0]      de_ex_rs2_data          = 0;
    reg [31:0]      de_ex_imm               = 0;
    reg [2:0]       de_ex_alu_mode          = 0;
    reg [1:0]       de_ex_eval_mode         = 0;
    reg             de_ex_sign_ext          = 0;    
    reg [1:0]       de_ex_in1_sel           = 0;
    reg [1:0]       de_ex_in2_sel           = 0;
    reg             de_ex_out_sel           = 0;
    reg             de_ex_branch_en         = 0;
    reg             de_ex_branch_cond       = 0;
    reg             de_ex_branch_base_sel   = 0;
    reg             de_ex_mem_wr_en         = 0;
    reg             de_ex_mem_rd_en         = 0;
    reg [1:0]       de_ex_mem_type          = 0;
    reg             de_ex_mem_signed        = 0;

    always @(posedge clk) begin
        if(~rstn) begin
            de_ex_pc                <= 0;
            de_ex_opcode            <= 0;
            // de_ex_func7             <= 0;
            // de_ex_func3             <= 0;
            // de_ex_format            <= 0;
            de_ex_rs1_addr          <= 0;
            de_ex_rs2_addr          <= 0;
            de_ex_rd_addr           <= 0;
            de_ex_reg_wr_en         <= 0;
            de_ex_rs1_data          <= 0;
            de_ex_rs2_data          <= 0;
            de_ex_imm               <= 0;
            de_ex_alu_mode          <= 0;
            de_ex_eval_mode         <= 0;
            de_ex_sign_ext          <= 0;    
            de_ex_in1_sel           <= 0;
            de_ex_in2_sel           <= 0;
            de_ex_out_sel           <= 0;
            de_ex_branch_en         <= 0;
            de_ex_branch_cond       <= 0;
            de_ex_branch_base_sel   <= 0;
            de_ex_mem_wr_en         <= 0;
            de_ex_mem_rd_en         <= 0;
            de_ex_mem_type          <= 0;
            de_ex_mem_signed        <= 0;
        end else if(~de_stall) begin
            if(de_bubble | ~fe_de_valid) begin
                // To insert a bubble, turn of all signals that may cause a change in processor state
                de_ex_mem_wr_en         <= 0;
                de_ex_mem_rd_en         <= 0;
                de_ex_reg_wr_en         <= 0;
                de_ex_branch_en         <= 0;
            end else begin
                de_ex_pc                <= fe_de_pc;
                de_ex_opcode            <= decode_opcode;
                // de_ex_func7             <= decode_func7;
                // de_ex_func3             <= decode_func3;
                // de_ex_format            <= decode_format;
                de_ex_rs1_addr          <= decode_rs1_addr;
                de_ex_rs2_addr          <= decode_rs2_addr;
                de_ex_rd_addr           <= decode_rd_addr;
                de_ex_reg_wr_en         <= decode_reg_wr_en;
                de_ex_rs1_data          <= decode_rs1_data;
                de_ex_rs2_data          <= decode_rs2_data;
                de_ex_imm               <= decode_imm;
                de_ex_alu_mode          <= decode_alu_mode;
                de_ex_eval_mode         <= decode_eval_mode;
                de_ex_sign_ext          <= decode_sign_ext;    
                de_ex_in1_sel           <= decode_in1_sel;
                de_ex_in2_sel           <= decode_in2_sel;
                de_ex_out_sel           <= decode_out_sel;
                de_ex_branch_en         <= decode_branch_en;
                de_ex_branch_cond       <= decode_branch_cond;
                de_ex_branch_base_sel   <= decode_branch_base_sel;
                de_ex_mem_wr_en         <= decode_mem_wr_en;
                de_ex_mem_rd_en         <= decode_mem_rd_en;
                de_ex_mem_type          <= decode_mem_type;
                de_ex_mem_signed        <= decode_mem_signed;
            end
        end
    end

    //-------------------------------------------------------------------------
    //                                  Execute Stage
    
    reg [31:0]      exec_rs1_fwd;
    reg [31:0]      exec_rs2_fwd;

    // ALU inputs
    reg  [31:0]     exec_alu_in1;
    reg  [31:0]     exec_alu_in2;

    // ALU outputs
    wire [31:0]     exec_alu_out;
    wire            exec_eval_out;
    reg  [31:0]     exec_out;

    // Branching
    reg  [31:0]     exec_branch_base;
    reg             exec_branch_taken;
    wire [31:0]     exec_branch_tgt     = exec_branch_base + de_ex_imm;

    // ALU input 1 and 2 multiplexers
    always @(*) begin
        exec_alu_in1    = 32'hx;
        case(de_ex_in1_sel)
            `ALU_IN1_0:     exec_alu_in1    = 32'd0;
            `ALU_IN1_PC:    exec_alu_in1    = de_ex_pc;
            `ALU_IN1_RS1:   exec_alu_in1    = exec_rs1_fwd;
        endcase
    end
    always @(*) begin
        exec_alu_in2    = 32'hx;
        case(de_ex_in2_sel)
            `ALU_IN2_4:     exec_alu_in2    = 32'd4;
            `ALU_IN2_IMM:   exec_alu_in2    = de_ex_imm;
            `ALU_IN2_RS2:   exec_alu_in2    = exec_rs2_fwd;
        endcase
    end

    // ALU output multiplxer (for SLT, SLTU instructions)
    always @(*) begin
        exec_out = 32'hx;
        case(de_ex_out_sel)
            `ALU_OUT_ALU:   exec_out    = exec_alu_out;
            `ALU_OUT_EVAL:  exec_out    = {31'd0, exec_eval_out};
        endcase
    end

    // ALU
    alu alu (
        .in1        (exec_alu_in1),
        .in2        (exec_alu_in2),

        .alu_mode   (de_ex_alu_mode),
        .eval_mode  (de_ex_eval_mode),
        .sign_ext   (de_ex_sign_ext),

        .out        (exec_alu_out),
        .eval_out   (exec_eval_out)
    );

    // Branch base
    always @(*) begin
        exec_branch_base = de_ex_pc;
        case(de_ex_branch_base_sel)
            `BRANCH_BASE_PC:    exec_branch_base = de_ex_pc;
            `BRANCH_BASE_RS1:   exec_branch_base = exec_rs1_fwd;
        endcase
    end
    // Branch taken or not taken
    always @(*) begin
        if(de_ex_branch_en)
            if(de_ex_branch_cond)
                exec_branch_taken = exec_eval_out;
            else
                exec_branch_taken = 1;
        else
            exec_branch_taken = 0;
    end

    // Execute - Memory pipeline
    reg [31:0]      ex_mem_out          = 0;
    reg [31:0]      ex_mem_rs2_data     = 0;
    reg [5:0]       ex_mem_rd_addr      = 0;
    reg             ex_mem_branch_taken = 0;
    reg [31:0]      ex_mem_branch_tgt   = 0;
    reg             ex_mem_reg_wr_en    = 0;
    reg             ex_mem_mem_wr_en    = 0;
    reg             ex_mem_mem_rd_en    = 0;
    reg [1:0]       ex_mem_mem_type     = 0;
    reg             ex_mem_mem_signed   = 0;

    always @(posedge clk) begin
        if(~rstn) begin
            ex_mem_out          <= 0;
            ex_mem_rs2_data     <= 0;
            ex_mem_rd_addr      <= 0;
            ex_mem_branch_taken <= 0;
            ex_mem_branch_tgt   <= 0;
            ex_mem_reg_wr_en    <= 0;
            ex_mem_mem_wr_en    <= 0;
            ex_mem_mem_rd_en    <= 0;
            ex_mem_mem_type     <= 0;
            ex_mem_mem_signed   <= 0;
        end else if(~ex_stall) begin
            if(ex_bubble) begin
                ex_mem_reg_wr_en    <= 0;
                ex_mem_branch_taken <= 0;
                ex_mem_mem_wr_en    <= 0;
                ex_mem_mem_rd_en    <= 0;
            end else begin
                ex_mem_out          <= exec_out;
                ex_mem_rs2_data     <= exec_rs2_fwd;
                ex_mem_rd_addr      <= de_ex_rd_addr;
                ex_mem_branch_taken <= exec_branch_taken;
                ex_mem_branch_tgt   <= exec_branch_tgt;
                ex_mem_reg_wr_en    <= de_ex_reg_wr_en;
                ex_mem_mem_wr_en    <= de_ex_mem_wr_en;
                ex_mem_mem_rd_en    <= de_ex_mem_rd_en;
                ex_mem_mem_type     <= de_ex_mem_type;
                ex_mem_mem_signed   <= de_ex_mem_signed;
            end
        end
    end

    assign fetch_branch_taken = ex_mem_branch_taken;
    assign fetch_branch_tgt   = ex_mem_branch_tgt;
    
    //-------------------------------------------------------------------------
    //                                  Memory Stage
    
    wire[7:0]   mem_rd_data[3:0];
    reg [7:0]   mem_wr_data[3:0];
    reg [3:0]   mem_wr_en;

    wire[31:0]  mem_cache_out;
    wire[31:0]  mem_cache_in = {mem_wr_data[3], mem_wr_data[2], mem_wr_data[1], mem_wr_data[0]};

    assign mem_rd_data[0] = mem_cache_out[7:0];
    assign mem_rd_data[1] = mem_cache_out[15:8];
    assign mem_rd_data[2] = mem_cache_out[23:16];
    assign mem_rd_data[3] = mem_cache_out[31:24];

    wire mem_read_hit;
    wire mem_write_hit;
    wire mem_cache_busy;

    // Read interface with main memory
    wire[31:0]  datamem_rd_data;
    wire        datamem_rd_valid;// = 1'b1;
    wire[15:0]  datamem_rd_addr;
    wire        datamem_rd_en;

    // Write interface with main memory
    wire        datamem_wr_rdy = 1'b1;
    wire[31:0]  datamem_wr_data;
    wire[15:0]  datamem_wr_addr;
    wire        datamem_wr_en;

    data_cache #(
        .ADDR_WIDTH (16),
        .DATA_WIDTH (32),
        .LINE_WIDTH (4),
        .ASSOC      (1),
        .NUM_SETS   (16)
    ) dcache_inst (
        .clk                ( clk               ),
        .rstn               ( rstn              ),
        
        .proc_rd_addr       ( ex_mem_out[31:2]  ),
        .proc_rd_en         ( ex_mem_mem_rd_en  ),
        .proc_rd_data       ( mem_cache_out     ),
        .proc_rd_hit        ( mem_read_hit      ),
        
        .proc_wr_addr       ( ex_mem_out[31:2]  ),
        .proc_wr_en         ( ex_mem_mem_wr_en  ),
        .proc_wr_data       ( mem_cache_in      ),
        .proc_wr_sel        ( mem_wr_en         ),
        .proc_wr_hit        ( mem_write_hit     ), 
        .proc_busy          ( mem_cache_busy    ),

        .mem_rd_data        ( datamem_rd_data  ),
        .mem_rd_valid       ( datamem_rd_valid ),
        .mem_rd_addr        ( datamem_rd_addr  ),
        .mem_rd_en          ( datamem_rd_en    ),

        .mem_wr_rdy         ( datamem_wr_rdy   ),
        .mem_wr_data        ( datamem_wr_data  ),
        .mem_wr_addr        ( datamem_wr_addr  ),
        .mem_wr_en          ( datamem_wr_en    )
    );

    // Write data alignment

    always @(*) begin
        mem_wr_en = 4'b1111;
        mem_wr_data[0]  = ex_mem_rs2_data[7 :0];
        mem_wr_data[1]  = ex_mem_rs2_data[15:8];
        mem_wr_data[2]  = ex_mem_rs2_data[23:16];
        mem_wr_data[3]  = ex_mem_rs2_data[31:24];

        case(ex_mem_mem_type)
            `MEM_WORD:  begin
                mem_wr_data[0]  = ex_mem_rs2_data[7 :0];
                mem_wr_data[1]  = ex_mem_rs2_data[15:8];
                mem_wr_data[2]  = ex_mem_rs2_data[23:16];
                mem_wr_data[3]  = ex_mem_rs2_data[31:24];
                mem_wr_en = 4'b1111;
            end
            `MEM_HALFWORD: begin
                mem_wr_data[0]  = ex_mem_rs2_data[7 :0];
                mem_wr_data[1]  = ex_mem_rs2_data[15:8];
                mem_wr_data[2]  = ex_mem_rs2_data[7 :0];
                mem_wr_data[3]  = ex_mem_rs2_data[15:8];
                if(ex_mem_out[1])
                    mem_wr_en = 4'b1100;
                else
                    mem_wr_en = 4'b0011;
            end
            `MEM_BYTE: begin
                mem_wr_data[0]  = ex_mem_rs2_data[7 :0];
                mem_wr_data[1]  = ex_mem_rs2_data[7 :0];
                mem_wr_data[2]  = ex_mem_rs2_data[7 :0];
                mem_wr_data[3]  = ex_mem_rs2_data[7 :0];
                case(ex_mem_out[1:0])
                    0:  mem_wr_en = 4'b0001;
                    1:  mem_wr_en = 4'b0010;
                    2:  mem_wr_en = 4'b0100;
                    3:  mem_wr_en = 4'b1000;
                endcase
            end
        endcase
    end

    // Read data alignment
    reg[31:0]   mem_rd_data_aligned;
    
    always @(*) begin
         case(ex_mem_mem_type)
            `MEM_WORD:
                mem_rd_data_aligned = {mem_rd_data[3], mem_rd_data[2], mem_rd_data[1], mem_rd_data[0]};
            `MEM_HALFWORD:
                if(ex_mem_mem_signed)
                    if(ex_mem_out[1])
                        mem_rd_data_aligned = {{16{mem_rd_data[3][7]}}, mem_rd_data[3], mem_rd_data[2]};
                    else
                        mem_rd_data_aligned = {{16{mem_rd_data[1][7]}}, mem_rd_data[1], mem_rd_data[0]};
                else 
                    if(ex_mem_out[1])
                        mem_rd_data_aligned = {16'd0,                   mem_rd_data[3], mem_rd_data[2]};
                    else
                        mem_rd_data_aligned = {16'd0,                   mem_rd_data[1], mem_rd_data[0]};
            `MEM_BYTE:
                if(ex_mem_mem_signed)
                    case(ex_mem_out[1:0])
                        0:  mem_rd_data_aligned = {{24{mem_rd_data[0][7]}}, mem_rd_data[0]};
                        1:  mem_rd_data_aligned = {{24{mem_rd_data[1][7]}}, mem_rd_data[1]};
                        2:  mem_rd_data_aligned = {{24{mem_rd_data[2][7]}}, mem_rd_data[2]};
                        3:  mem_rd_data_aligned = {{24{mem_rd_data[3][7]}}, mem_rd_data[3]};
                    endcase
                else
                    case(ex_mem_out[1:0])
                        0:  mem_rd_data_aligned = {24'd0, mem_rd_data[0]};
                        1:  mem_rd_data_aligned = {24'd0, mem_rd_data[1]};
                        2:  mem_rd_data_aligned = {24'd0, mem_rd_data[2]};
                        3:  mem_rd_data_aligned = {24'd0, mem_rd_data[3]};
                    endcase
            default:
                mem_rd_data_aligned = {mem_rd_data[3], mem_rd_data[2], mem_rd_data[1], mem_rd_data[0]};
        endcase
    end

    // Memory - Writeback pipeline
    reg [31:0]      mem_wb_out          = 0;
    reg [4:0]       mem_wb_rd_addr      = 0;
    reg             mem_wb_reg_wr_en    = 0;
    
    always @(posedge clk) begin
        if(~rstn) begin
            mem_wb_out          <= 0;
            mem_wb_rd_addr      <= 0;
            mem_wb_reg_wr_en    <= 0;
        end else if(~mem_stall) begin
            if(mem_bubble) begin
                mem_wb_reg_wr_en    <= 0;
            end else begin
                mem_wb_out          <= ex_mem_mem_rd_en ? mem_rd_data_aligned : ex_mem_out;
                mem_wb_rd_addr      <= ex_mem_rd_addr;
                mem_wb_reg_wr_en    <= ex_mem_reg_wr_en;
            end
        end 
    end

    //-------------------------------------------------------------------------
    //                                  Writeback stage

    assign reg_wr_addr = mem_wb_rd_addr;
    assign reg_wr_data = mem_wb_out;
    assign reg_wr_en   = mem_wb_reg_wr_en;

    // Writeback pipeline
    reg [31:0]      wb_out          = 0;
    reg [4:0]       wb_rd_addr      = 0;
    reg             wb_reg_wr_en    = 0;

    always @(posedge clk) begin
        if(~rstn) begin
            wb_out              <= 0;
            wb_rd_addr          <= 0;
            wb_reg_wr_en        <= 0;
        end else if(~wb_stall) begin
            wb_out              <= mem_wb_out;
            wb_rd_addr          <= mem_wb_rd_addr;
            wb_reg_wr_en        <= mem_wb_reg_wr_en;
        end 
    end

    //-------------------------------------------------------------------------
    //                                  Forward logic

    reg [1:0]       exec_rs1_src;
    reg [1:0]       exec_rs2_src;

    // Forward path detection
    always @(*) begin
        exec_rs1_src = `FWD_NONE;
        if(de_ex_rs1_addr == ex_mem_rd_addr && ex_mem_reg_wr_en)
            exec_rs1_src = `FWD_EXEC;
        else if(de_ex_rs1_addr == mem_wb_rd_addr && mem_wb_reg_wr_en)
            exec_rs1_src = `FWD_MEM;
        else if(de_ex_rs1_addr == wb_rd_addr && wb_reg_wr_en)
            exec_rs1_src = `FWD_WB;
    end
    always @(*) begin
        exec_rs2_src = `FWD_NONE;
        if(de_ex_rs2_addr == ex_mem_rd_addr && ex_mem_reg_wr_en)
            exec_rs2_src = `FWD_EXEC;
        else if(de_ex_rs2_addr == mem_wb_rd_addr && mem_wb_reg_wr_en)
            exec_rs2_src = `FWD_MEM;
        else if(de_ex_rs2_addr == wb_rd_addr && wb_reg_wr_en)
            exec_rs2_src = `FWD_WB;
    end

    // Forward multiplexing
    always @(*) begin
        exec_rs1_fwd = 32'hx;
        case(exec_rs1_src)
            `FWD_NONE:  exec_rs1_fwd = de_ex_rs1_data;
            `FWD_EXEC:  exec_rs1_fwd = ex_mem_out;
            `FWD_MEM:   exec_rs1_fwd = mem_wb_out;
            `FWD_WB:    exec_rs1_fwd = wb_out;
        endcase
    end
    always @(*) begin
        exec_rs2_fwd = 32'hx;
        case(exec_rs2_src)
            `FWD_NONE:  exec_rs2_fwd = de_ex_rs2_data;
            `FWD_EXEC:  exec_rs2_fwd = ex_mem_out;
            `FWD_MEM:   exec_rs2_fwd = mem_wb_out;
            `FWD_WB:    exec_rs2_fwd = wb_out;
        endcase
    end

    //-------------------------------------------------------------------------
    //                                  Stall logic

    // Bubble at fetch when a branch/jump instruction is in decode or execute stages or when fetch stage misses
    assign fe_bubble = (decode_branch_en && fe_de_valid) | de_ex_branch_en | (~fetch_hit);
    // No need to bubble at decode
    assign de_bubble = 1'b0;
    // Bubble at execute when load is followed by another instruction using loaded value
    assign ex_bubble = ex_mem_mem_rd_en & ex_mem_reg_wr_en & 
        (((ex_mem_rd_addr == de_ex_rs1_addr) & (de_ex_in1_sel == `ALU_IN1_RS1)) | 
        ((ex_mem_rd_addr == de_ex_rs2_addr) & (de_ex_in2_sel == `ALU_IN2_RS2)));
    // Bubble at mem if there is a read miss or write miss
    assign mem_bubble = 1'b0;
    
    assign full_stall = (ex_mem_mem_rd_en && ~mem_read_hit) | (ex_mem_mem_wr_en && ~mem_write_hit);

    assign fe_stall   = de_stall | de_bubble;     // Stall FE if bubble inserted in EX or DE
    assign de_stall   = ex_stall | ex_bubble;     // Stall DE if bubble inserted in EX
    assign ex_stall   = mem_stall | mem_bubble;
    assign mem_stall  = wb_stall;
    assign wb_stall   = stall | full_stall;

    //-------------------------------------------------------------------------
    //                                  Main memory


    wire[15:0] mainmem_rd_addr = (mem_nextstate == mem_DCACHE) ? datamem_rd_addr : fetchmem_rd_addr;
    wire[31:0] mainmem_rd_data;

    localparam mem_ICACHE = 0;
    localparam mem_DCACHE = 1;

    reg mem_state = mem_DCACHE;
    reg mem_nextstate;

    always @(*) begin
        mem_nextstate = mem_DCACHE;

        case(mem_state)
            mem_ICACHE:
                mem_nextstate = fetchmem_rd_en ? mem_ICACHE : mem_DCACHE;
            mem_DCACHE:
                mem_nextstate = datamem_rd_en  ? mem_DCACHE : ((fetchmem_rd_en) ? mem_ICACHE : mem_DCACHE);
        endcase
    end

    always @(posedge clk)
        if(~rstn)
            mem_state <= mem_DCACHE;
        else
            mem_state <= mem_nextstate;

    block_mem #(
        .ADDR_WIDTH (16),
        .DATA_WIDTH (32),
        .MEM_DEPTH  (2048)
    ) mem_inst (
        .clk(clk),
        .rstn(rstn),

        .rd_addr    (mainmem_rd_addr),
        .rd_data    (mainmem_rd_data),

        .wr_addr    (datamem_wr_addr),
        .wr_data    (datamem_wr_data),
        .wr_en      (datamem_wr_en)
    );

    assign fetchmem_rd_data = mainmem_rd_data;
    assign datamem_rd_data  = mainmem_rd_data;

    assign fetchmem_rd_valid = (mem_state == mem_ICACHE);
    assign datamem_rd_valid  = (mem_state == mem_DCACHE);

endmodule
