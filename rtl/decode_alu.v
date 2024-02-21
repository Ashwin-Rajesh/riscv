`include "defines.v"

module decode_alu(
    input[6:0]  opcode,
    input[6:0]  func7,
    input[2:0]  func3,

    output[2:0]  alu_mode,
    output[1:0]  eval_mode,
    output       sign_ext,

    output[1:0]  in1_sel,
    output[1:0]  in2_sel,
    output       out_sel
);

    reg[2:0]    alu_mode;
    reg[1:0]    eval_mode;
    reg         sign_ext;

    reg[1:0]    in1_sel;
    reg[1:0]    in2_sel;
    reg         out_sel;

    reg         branch_sel;

    // ALU mode
    always @(*) begin
        alu_mode = 3'bxxx;
        case(opcode)
            3:      alu_mode = `ALU_ADD;  // Load instructions
            19:                           // I type
                case(func3)
                    3'b000: alu_mode = `ALU_ADD;
                    3'b001: alu_mode = `ALU_SLL;
                    3'b010: alu_mode = `ALU_SUB;
                    3'b011: alu_mode = `ALU_SUB;
                    3'b100: alu_mode = `ALU_XOR;
                    3'b101: alu_mode = (func7 == 0) ? `ALU_SRL : `ALU_SRA;
                    3'b110: alu_mode = `ALU_OR;
                    3'b111: alu_mode = `ALU_AND;
                endcase
            23:     alu_mode = `ALU_ADD;  // AUIPC
            35:     alu_mode = `ALU_ADD;  // Store instructions
            51:                           // R type
                case(func3)
                    3'b000: alu_mode = (func7 == 0) ? `ALU_ADD : `ALU_SUB;
                    3'b001: alu_mode = `ALU_SLL;
                    3'b010: alu_mode = `ALU_SUB;
                    3'b011: alu_mode = `ALU_SUB;
                    3'b100: alu_mode = `ALU_XOR;
                    3'b101: alu_mode = (func7 == 0) ? `ALU_SRL : `ALU_SRA;
                    3'b110: alu_mode = `ALU_OR;
                    3'b111: alu_mode = `ALU_AND;
                endcase
            55:     alu_mode = `ALU_ADD;  // LUI instruction
            99:     alu_mode = `ALU_SUB;  // Branch instructions
            103:    alu_mode = `ALU_ADD;  // JALR
            111:    alu_mode = `ALU_ADD;  // JAL
        endcase
    end

    // 33rd bit Sign extension (for unsigned comparisons)
    always @(*) begin
        sign_ext = 1;

        // Check conditions were sign extension is not needed (unsigned comparison instructions)
        case(opcode)
            19:     sign_ext = ~(func3 == 3'b011);     // SLTIU instruction
            51:     sign_ext = ~(func3 == 3'b011);     // SLTU instruction
            99:     sign_ext = ~(func3 == 3'b110 || func3 == 3'b111);    // BLTU, BGEU instructions
        endcase
    end

    // Evaluation mode (for comparison instructions)
    always @(*) begin
        eval_mode = `EVAL_EQ;

        case(opcode)
            19:     // I type instructions 
                case(func3)
                    3'b010: eval_mode = `EVAL_LT;   // SLTI
                    3'b011: eval_mode = `EVAL_LT;   // SLTIU
                endcase
            51:     // R type instructions           
                case(func3)
                    3'b010: eval_mode = `EVAL_LT;   // SLT
                    3'b011: eval_mode = `EVAL_LT;   // SLTU
                endcase
            99:     // Branch instructions
                case(func3)
                    3'b000: eval_mode = `EVAL_EQ;
                    3'b001: eval_mode = `EVAL_NEQ;
                    3'b100: eval_mode = `EVAL_LT;
                    3'b101: eval_mode = `EVAL_GE;
                    3'b110: eval_mode = `EVAL_LT;
                    3'b111: eval_mode = `EVAL_GE;
                endcase
        endcase
    end

    always @(*) begin
        in1_sel = `ALU_IN1_RS1;
        in2_sel = `ALU_IN2_RS2;
        out_sel = `ALU_OUT_ALU;

        case(opcode)
            3:begin // Load instructions
                in1_sel = `ALU_IN1_RS1;
                in2_sel = `ALU_IN2_IMM;
                out_sel = `ALU_OUT_ALU;
            end
            19:begin    // I type instructions
                in1_sel = `ALU_IN1_RS1;
                in2_sel = `ALU_IN2_IMM;
                // Special conditions for SLTI and SLTIU instructions
                out_sel = (func3 == 3'b010 || func3 == 3'b011) ? `ALU_OUT_EVAL : `ALU_OUT_ALU;
            end
            23:begin    // AUIPC
                in1_sel = `ALU_IN1_PC;
                in2_sel = `ALU_IN2_IMM;
                out_sel = `ALU_OUT_ALU;
            end
            35:begin    // Store instructions
                in1_sel = `ALU_IN1_RS1;
                in2_sel = `ALU_IN2_IMM;
                out_sel = `ALU_OUT_ALU;
            end
            51:begin    // R type instructions
                in1_sel = `ALU_IN1_RS1;
                in2_sel = `ALU_IN2_RS2;
                // Special conditions for SLT and SLTU instructions
                out_sel = (func3 == 3'b010 || func3 == 3'b011) ? `ALU_OUT_EVAL : `ALU_OUT_ALU;
            end
            55:begin    // LUI instruction
                in1_sel = `ALU_IN1_0;
                in2_sel = `ALU_IN2_IMM;
                out_sel = `ALU_OUT_ALU;
            end
            99:begin    // Branch instructions
                in1_sel = `ALU_IN1_RS1;
                in2_sel = `ALU_IN2_RS2;
                out_sel = `ALU_OUT_ALU;
            end
            103:begin   // JALR instruction
                in1_sel = `ALU_IN1_PC;
                in2_sel = `ALU_IN2_4;
                out_sel = `ALU_OUT_ALU;
            end
            111:begin   // JAL instruction
                in1_sel = `ALU_IN1_PC;
                in2_sel = `ALU_IN2_4;
                out_sel = `ALU_OUT_ALU;
            end
        endcase
    end

endmodule
