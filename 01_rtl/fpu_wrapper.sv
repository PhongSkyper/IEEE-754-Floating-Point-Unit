`timescale 1ns/1ps
module fpu_wrapper (
    input  logic [17:0] SW,
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG
);
    logic [31:0] i_a, i_b;
    logic        i_add_sub;
    logic [31:0] o_z;
    logic        ov_flag, un_flag, zero_flag;
    
    localparam [31:0] VAL_20_25 = 32'h41A20000;
    localparam [31:0] VAL_MAX   = 32'h7F7FFFFF;
    localparam [31:0] VAL_MIN_1 = 32'h00800001;
    localparam [31:0] VAL_MIN   = 32'h00800000;
    
    always_comb begin
        i_a = 32'd0;
        i_b = VAL_20_25;
        i_add_sub = 1'b0;
        
        case (SW[17:16]) 
            2'b00: begin
                i_a = {SW[8], 4'b1000, SW[7:4], SW[3:0], 19'd0};
                i_b = VAL_20_25;
                i_add_sub = SW[9];
            end
            
            2'b01: begin
                i_a = VAL_MAX; 
                i_b = VAL_MAX;
                i_add_sub = 1'b0;
            end
            
            2'b10: begin
                i_a = VAL_MIN_1; 
                i_b = VAL_MIN;
                i_add_sub = 1'b1;
            end
            
            2'b11: begin
                i_a = VAL_20_25; 
                i_b = VAL_20_25;
                i_add_sub = 1'b1;
            end
        endcase
    end
    
    fpu_add_sub_top u_core (
        .i_a         (i_a),
        .i_b         (i_b),
        .i_add_sub   (i_add_sub),
        .o_z         (o_z),
        .o_overflow  (ov_flag),
        .o_underflow (un_flag),
        .o_zero      (zero_flag)
    );
    
    assign LEDR[9]   = i_add_sub;
    assign LEDR[8]   = o_z[31];
    assign LEDR[7:4] = o_z[26:23];
    assign LEDR[3:0] = o_z[22:19];
    assign LEDR[17:10] = 8'd0;
    
    assign LEDG[2] = ov_flag;
    assign LEDG[1] = un_flag;
    assign LEDG[0] = zero_flag;
    assign LEDG[8:3] = 6'd0;
endmodule