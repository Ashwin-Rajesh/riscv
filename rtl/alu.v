`include "defines.v"

module alu(
    input signed[31:0]  in1,
    input signed[31:0]  in2,

    input[2:0]          alu_mode,
    input[1:0]          eval_mode,
    input               sign_ext,

    output reg[31:0]    out,

    output reg          eval_out
);

    wire[31:0]  add_in2 = (alu_mode == `ALU_SUB) ? ~in2 : in2;

    wire[32:0] add_out = 
        {(sign_ext ? in1[31]     : 1'b0), in1} + 
        {(sign_ext ? add_in2[31] : 1'b0), add_in2} + 
        (alu_mode == `ALU_SUB ? 1'b1 : 1'b0);

    wire zero = (add_out == 0);
    wire neg  = add_out[32];

    always @(*) begin
        out = 0;
        case(alu_mode)
            `ALU_ADD:
                out = add_out[31:0];
            `ALU_SUB:
                out = add_out[31:0];
            `ALU_AND:
                out = in1 & in2;
            `ALU_OR:
                out = in1 | in2;
            `ALU_XOR:
                out = in1 ^ in2;
            `ALU_SLL:
                out = in1 << in2[4:0];
            `ALU_SRL:
                out = in1 >> in2[4:0];
            `ALU_SRA:
                out = in1 >>> in2[4:0];
        endcase        
    end

    always @(*) begin
        eval_out = 0;

        case(eval_mode)
            `EVAL_EQ:
                eval_out = zero;
            `EVAL_NEQ:
                eval_out = ~zero;
            `EVAL_LT:
                eval_out = neg;
            `EVAL_GE:
                eval_out = ~neg;
        endcase
    end

endmodule
