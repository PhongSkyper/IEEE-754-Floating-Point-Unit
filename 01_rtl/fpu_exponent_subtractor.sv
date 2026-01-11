`timescale 1ns/1ps
module fpu_exponent_subtractor (
    input  logic [7:0] exp_a,
    input  logic [7:0] exp_b,
    output logic [7:0] exp_max,
    output logic [7:0] exp_min,
    output logic [4:0] exp_diff,   
    output logic       a_ge_b,
    output logic       ex_eq
);
    logic [7:0] diff_ab, diff_ba;
    logic       cout_ab, cout_ba;
    
    // A - B = A + (~B) + 1
    adder_8bit_manual u_sub_ab (.a(exp_a), .b(~exp_b), .cin(1'b1), .sum(diff_ab), .cout(cout_ab));
    adder_8bit_manual u_sub_ba (.a(exp_b), .b(~exp_a), .cin(1'b1), .sum(diff_ba), .cout(cout_ba));
    
    // Nếu cout_ab = 1 nghĩa là A >= B 
    assign a_ge_b = cout_ab;
    
    mux2 #(.N(8)) u_mux_max (.d0(exp_b), .d1(exp_a), .sel(a_ge_b), .y(exp_max));
    mux2 #(.N(8)) u_mux_min (.d0(exp_a), .d1(exp_b), .sel(a_ge_b), .y(exp_min));
    
    logic [7:0] diff_abs;
    mux2 #(.N(8)) u_mux_diff (.d0(diff_ba), .d1(diff_ab), .sel(a_ge_b), .y(diff_abs));
    
    logic high_bits_nonzero;
    or_gate_3 u_check (.a(diff_abs[7]), .b(diff_abs[6]), .c(diff_abs[5]), .y(high_bits_nonzero));
    
    // Saturation logic (giới hạn max shift là 31)
    mux2 #(.N(5)) u_mux_sat (
        .d0 (diff_abs[4:0]),
        .d1 (5'd31),
        .sel(high_bits_nonzero),
        .y  (exp_diff)
    );
    
    logic diff_is_zero;
    zero_detect #(.N(8)) u_zdet (.a(diff_ab), .is_zero(diff_is_zero));
    assign ex_eq = diff_is_zero;
endmodule