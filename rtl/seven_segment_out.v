`timescale 1ns / 1ps

module seven_segment_out #(
    parameter clkdiv_ratio = 100
) (
    input clk,
    input rst,
    input[15:0] inp,
        
    output[3:0] sel,
    output[7:0] data        // P(7), G(6), ... A(0)
);
    
    reg[$clog2(clkdiv_ratio):0] div_count = 0;  // Clock divider count    
    reg[1:0] count                        = 0;  // Digit currently being displayed

    wire[7:0] digits[3:0];
    // Data output multiplexer
    assign data = ~(digits[count]);

    // Select line decoder
    reg[3:0] sel;
    always @(*) begin
        case(count)
            0:      sel <= 4'b1110;
            1:      sel <= 4'b1101;
            2:      sel <= 4'b1011;
            3:      sel <= 4'b0111;
            default:sel <= 4'b0000;
        endcase
    end

    // Counter
    always @(posedge clk) begin
        if(rst) begin
            div_count   <= 0;
            count       <= 0;
        end else if(div_count == clkdiv_ratio) begin
            div_count   <= 0;
            count       <= count + 1;
        end else begin
            div_count   <= div_count + 1;
            count       <= count;
        end
    end

    // Seven segment encoders
    reg[7:0] disp_lut[15:0];
    initial begin
        disp_lut[0]  = 8'h3F;
        disp_lut[1]  = 8'h06;
        disp_lut[2]  = 8'h5B;
        disp_lut[3]  = 8'h4F;
        disp_lut[4]  = 8'h66;
        disp_lut[5]  = 8'h6D;
        disp_lut[6]  = 8'h7D;
        disp_lut[7]  = 8'h07;
        disp_lut[8]  = 8'h7F;
        disp_lut[9]  = 8'h67;
        disp_lut[10] = 8'h77;
        disp_lut[11] = 8'h7C;
        disp_lut[12] = 8'h39;
        disp_lut[13] = 8'h5E;
        disp_lut[14] = 8'h79;
        disp_lut[15] = 8'h71;
    end

    assign digits[0] = disp_lut[inp[3:0]];
    assign digits[1] = disp_lut[inp[7:4]];
    assign digits[2] = disp_lut[inp[11:8]];
    assign digits[3] = disp_lut[inp[15:12]];
    
endmodule
