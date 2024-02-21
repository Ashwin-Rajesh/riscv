module decode_regs(
    input[31:0]         inst,
    input[6:0]          opcode,

    output[4:0]         rs1,
    output[4:0]         rs2,
    output[4:0]         rd,

    output              reg_wr_en
);

    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd  = inst[11:7];

    reg instn_reg_wr_en;

    always @(*) begin
        instn_reg_wr_en = 0;
        case(opcode)
            3:      instn_reg_wr_en = 1;  // Load instructions
            19:     instn_reg_wr_en = 1;  // I type instructions
            23:     instn_reg_wr_en = 1;  // AUIPC
            35:     instn_reg_wr_en = 0;  // Store instructions
            51:     instn_reg_wr_en = 1;  // R type instructions
            55:     instn_reg_wr_en = 1;  // LUI instruction
            99:     instn_reg_wr_en = 0;  // Branch instructions
            103:    instn_reg_wr_en = 1;  // JALR
            111:    instn_reg_wr_en = 1;  // JAL
        endcase
    end

    assign reg_wr_en = instn_reg_wr_en & (rd != 0);

endmodule
