module decode_mem(
    input[6:0]  opcode,
    input[6:0]  func7,
    input[2:0]  func3,

    output[1:0] mem_type,
    output      mem_signed,
    output      mem_wr_en,
    output      mem_rd_en
);

    reg mem_wr_en;
    reg mem_rd_en;

    always @(*) begin
        mem_wr_en = 0;
        mem_rd_en = 0;
        case(opcode)
            3:      mem_rd_en = 1;  // Load instructions
            35:     mem_wr_en = 1;  // Store instructions
        endcase
    end

    reg[1:0] mem_type;
    wire     mem_signed;

    always @(*) begin
        mem_type    = `MEM_WORD;
        case(opcode)
            3: case(func3)
                3'b000: mem_type = `MEM_BYTE;
                3'b001: mem_type = `MEM_HALFWORD;
                3'b010: mem_type = `MEM_WORD;
                3'b100: mem_type = `MEM_BYTE;
                3'b101: mem_type = `MEM_HALFWORD;
            endcase
            35: case(func3)
                3'b000: mem_type = `MEM_BYTE;
                3'b001: mem_type = `MEM_HALFWORD;
                3'b010: mem_type = `MEM_WORD;
            endcase
        endcase
    end

    assign mem_signed = ~(opcode == 3 && (func3 == 3'b100 | func3 == 3'b101));

endmodule
