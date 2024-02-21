`include "defines.v"

module decode_instn(
    input[31:0]         inst,

    output[6:0]         opcode,
    output[6:0]         func7,
    output[2:0]         func3,
    output[2:0]         format
);
    assign opcode = inst[6:0];
    assign func3  = inst[14:12];
    assign func7  = inst[31:25];

    reg[2:0]            format;

    always @(*) begin
        format    = `UNDEF_TYPE;
        case(opcode)
            3:      format    = `I_TYPE; // Load instructions
            19:     format    = `I_TYPE; // I type instructions
            23:     format    = `U_TYPE; // AUIPC
            35:     format    = `S_TYPE; // Store instructions
            51:     format    = `R_TYPE; // R type instructions
            55:     format    = `U_TYPE; // LUI instruction
            99:     format    = `B_TYPE; // Branch instructions
            103:    format    = `I_TYPE; // JALR
            111:    format    = `J_TYPE; // JAL
        endcase
    end

endmodule
