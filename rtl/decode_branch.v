`include "defines.v"

module decode_branch(
    input[6:0]  opcode,
    input[6:0]  func7,
    input[2:0]  func3,

    output      branch_en,      // Is the instruction a branch?
    output      branch_cond,    // Is the branch conditional?
    output      branch_base_sel // Branch target base select
);

    reg branch_en;
    reg branch_cond;
    reg branch_base_sel;

    // Identifying branch instructions
    always @(*) begin
        branch_en = 0;
        case(opcode)
            99:     branch_en = 1;  // Branch instructions
            103:    branch_en = 1;  // JALR
            111:    branch_en = 1;  // JAL
        endcase
    end

    // Identifying conditional branch instructions
    always @(*) begin
        branch_cond = 0;
        case(opcode)
            99:     branch_cond = 1;  // Branch instructions
        endcase
    end

    // Where to select branch target base? (offset is from immediate field, but base could be PC or RS1)
    always @(*) begin
        branch_base_sel = `BRANCH_BASE_PC;
        case(opcode)
            103:    branch_base_sel = `BRANCH_BASE_RS1;   // JALR
        endcase
    end

endmodule
