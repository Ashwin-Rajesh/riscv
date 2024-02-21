`timescale 1ns / 1ps

module debouncer #(
    parameter debounce_cycles = 1000
) (
    input inp,
    input clk,
    input rst,
    output out
    );
    
    localparam state_low        = 0;
    localparam state_counting   = 1;
    localparam state_high       = 2;
    
    reg[1:0] state = state_low;
    
    reg[$clog2(debounce_cycles)+1:0] count;
    
    wire max = (count == debounce_cycles);
    
    assign out = (state == state_high);

    // Counter
    always @(posedge clk) begin
        if(rst)
            count   <= 0;
        else if(state == state_counting)
            count   <= count + 1;
        else
            count   <= 0;
    end
    
    // State transition
    always @(posedge clk) 
    if(rst)
        state <= 0;
    else 
        case(state)
            state_low:
                if(inp)
                    state <= state_counting;
            state_counting:
                if(max)
                    if(inp)
                        state <= state_high;
                    else
                        state <= state_low;
            state_high:
                if(~inp)
                    state <= state_low;
        endcase
endmodule
