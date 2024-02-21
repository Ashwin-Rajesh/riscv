// Instruction types
`define R_TYPE      0
`define I_TYPE      1
`define S_TYPE      2
`define B_TYPE      3
`define U_TYPE      4
`define J_TYPE      5
`define UNDEF_TYPE  7

// ALU operation select
`define ALU_ADD     0
`define ALU_SUB     1
`define ALU_AND     2
`define ALU_OR      3
`define ALU_XOR     4
`define ALU_SLL     5
`define ALU_SRL     6
`define ALU_SRA     7

// ALU evaluation select
`define EVAL_EQ     0
`define EVAL_NEQ    1
`define EVAL_LT     2
`define EVAL_GE     3

// ALU input 1 select
`define ALU_IN1_RS1 0
`define ALU_IN1_PC  1
`define ALU_IN1_0   2

// ALU input 2 select
`define ALU_IN2_RS2 0
`define ALU_IN2_IMM 1
`define ALU_IN2_4   2

// Execute output select (ALU output or from evaluation output)
`define ALU_OUT_ALU  0
`define ALU_OUT_EVAL 1

// Branch/jump base address selection
`define BRANCH_BASE_PC  0
`define BRANCH_BASE_RS1 1

// Memory load/store width select
`define MEM_WORD        0
`define MEM_HALFWORD    1
`define MEM_BYTE        2

// Forwarding select signals
`define FWD_NONE    0
`define FWD_EXEC    1
`define FWD_MEM     2
`define FWD_WB      3
