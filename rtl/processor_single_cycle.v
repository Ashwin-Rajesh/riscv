module rv32i (
    input clk,
    input rstn
);

    parameter INSTN_DEPTH   = 1024;
    parameter MEM_DEPTH     = 1024;

    // Writeback data
    wire [31:0]     wb_rd_data;

    //-------------------------------------------------------------------------
    //                                  Fetch Stage

    // Instruction Memory
    wire [31:0]     fetch_instn;
    reg  [31:0]     fetch_pc = 0;
    wire [31:0]     exec_next_pc;

    // Instruction Memory
    inst_memory #(
        .MEM_DEPTH(INSTN_DEPTH),
        .MEM_INSTN_WIDTH(32),
        .MEM_ADDR_WIDTH(32)
    ) inst_mem (
        .clk        (clk),
        .addr       (exec_next_pc),
        .instn_out  (fetch_instn)
    );

    always @(posedge clk) begin
        if(~rstn)
            fetch_pc  <= 32'd0 - 32'd4;
        else
            fetch_pc  <= exec_next_pc;
    end
    
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

    // Instruction decode
    decode_instn decode_instn_inst (
        .inst       (fetch_instn),
        .opcode     (decode_opcode),
        .func7      (decode_func7),
        .func3      (decode_func3),
        .format     (decode_format)
    );

    // Decode register signals
    decode_regs decode_regs_inst (
        .inst       (fetch_instn),
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
        .rd_addr    (decode_rd_addr),

        .rs1_out    (decode_rs1_data),
        .rs2_out    (decode_rs2_data),
        .rd_inp     (wb_rd_data),

        .write_en   (decode_reg_wr_en)
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
        .inst           (fetch_instn),
        .inst_format    (decode_format),
        .immediate      (decode_imm)
    );

    // Decode memory signals
    decode_mem decode_mem_inst (
        .opcode     (decode_opcode),
        .func7      (decode_func7),
        .func3      (decode_func3),
        .mem_wr_en  (decode_mem_wr_en),
        .mem_rd_en  (decode_mem_rd_en)
    );
    
    //-------------------------------------------------------------------------
    //                                  Execute Stage
    
    // ALU
    reg  [31:0]     exec_alu_in1;
    reg  [31:0]     exec_alu_in2;
    wire [31:0]     exec_alu_out;

    wire [31:0]     exec_alu_out;
    wire            exec_eval_out;
    reg  [31:0]     exec_out;
    reg  [31:0]     exec_branch_base;
    reg             exec_branch_taken;

    // ALU input 1 and 2 multiplexers
    always @(*) begin
        exec_alu_in1    = 32'hx;
        case(decode_in1_sel)
            `ALU_IN1_0:     exec_alu_in1    = 32'd0;
            `ALU_IN1_PC:    exec_alu_in1    = fetch_pc;
            `ALU_IN1_RS1:   exec_alu_in1    = decode_rs1_data;
        endcase
    end
    always @(*) begin
        exec_alu_in2    = 32'hx;
        case(decode_in2_sel)
            `ALU_IN2_4:     exec_alu_in2    = 32'd4;
            `ALU_IN2_IMM:   exec_alu_in2    = decode_imm;
            `ALU_IN2_RS2:   exec_alu_in2    = decode_rs2_data;
        endcase
    end

    // ALU output multiplxer (for SLT, SLTU instructions)
    always @(*) begin
        exec_out = 32'hx;
        case(decode_out_sel)
            `ALU_OUT_ALU:   exec_out    = exec_alu_out;
            `ALU_OUT_EVAL:  exec_out    = {31'd0, exec_eval_out};
        endcase
    end

    // ALU
    alu alu (
        .in1        (exec_alu_in1),
        .in2        (exec_alu_in2),

        .alu_mode   (decode_alu_mode),
        .eval_mode  (decode_eval_mode),
        .sign_ext   (decode_sign_ext),

        .out        (exec_alu_out),
        .eval_out   (exec_eval_out)
    );

    // Branch base
    always @(*) begin
        exec_branch_base = fetch_pc;
        case(decode_branch_base_sel)
            `BRANCH_BASE_PC:    exec_branch_base = fetch_pc;
            `BRANCH_BASE_RS1:   exec_branch_base = decode_rs1_data;
        endcase
    end
    // Branch taken or not taken
    always @(*) begin
        if(decode_branch_en)
            if(decode_branch_cond)
                exec_branch_taken = exec_eval_out;
            else
                exec_branch_taken = 1;
        else
            exec_branch_taken = 0;
    end
    // Next PC
    assign exec_next_pc = exec_branch_taken ? exec_branch_base + decode_imm : fetch_pc + 32'd4;

    //-------------------------------------------------------------------------
    //                                  Memory Stage
    
    wire[31:0]  mem_rd_data;

    // Data Memory
    data_memory #(
        .MEM_DEPTH(MEM_DEPTH),
        .MEM_DATA_WIDTH(32),
        .MEM_ADDR_WIDTH(32)
    ) data_mem (
        .clk        (clk),
        .addr       ({2'b0, exec_out[31:2]}),
        .data_in    (decode_rs2_data),
        .write_en   (decode_mem_wr_en),
        .data_out   (mem_rd_data)
    );

    //-------------------------------------------------------------------------
    //                                  Writeback stage

    assign wb_rd_data = decode_mem_rd_en ? mem_rd_data : exec_out;

endmodule
