module decode_imm(
    input[31:0]         inst,
    input[2:0]          inst_format,

    output reg[31:0]    immediate
);

    always @(*) begin
        immediate = 0;

        case(inst_format)
            `I_TYPE:
                immediate   = {{21{inst[31]}},               inst[30:25],    inst[24:21],    inst[20]};
            `S_TYPE:
                immediate   = {{21{inst[31]}},               inst[30:25],    inst[11:8],     inst[7]};
            `B_TYPE:
                immediate   = {{20{inst[31]}}, inst[7],      inst[30:25],    inst[11:8],     1'b0};
            `U_TYPE:
                immediate   = {inst[31], inst[30:20], inst[19:12], 12'b0};
            `J_TYPE:
                immediate   = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:25], inst[24:21], 1'b0};
        endcase
    end

endmodule
