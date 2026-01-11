`timescale 1ns/1ps

module not_gate (input logic a, output logic y); assign y = ~a; endmodule
module and_gate_2 (input logic a,b, output logic y); assign y = a & b; endmodule
module or_gate_2 (input logic a,b, output logic y); assign y = a | b; endmodule
module xor_gate_2 (input logic a,b, output logic y); assign y = a ^ b; endmodule
module and_gate_3 (input logic a,b,c, output logic y); assign y = a & b & c; endmodule
module or_gate_3 (input logic a,b,c, output logic y); assign y = a | b | c; endmodule

module mux2 #(parameter int N = 1) (
    input  logic [N-1:0] d0, d1,
    input  logic         sel,
    output logic [N-1:0] y
);
    assign y = sel ? d1 : d0; 
endmodule

module zero_detect #(parameter int N = 8) (input logic [N-1:0] a, output logic is_zero);
    assign is_zero = ~(|a);
endmodule

module or_reduction_8  (input logic [7:0] a, output logic y); assign y = |a; endmodule
module or_reduction_23 (input logic [22:0] a, output logic y); assign y = |a; endmodule
module and_reduction_8 (input logic [7:0] a, output logic y); assign y = &a; endmodule


module comp_1bit_structural (
    input  logic a, b,
    output logic a_gt_b, a_lt_b, a_eq_b
);
    logic not_a, not_b;
    assign not_a = ~a;
    assign not_b = ~b;
    assign a_gt_b = a & not_b;
    assign a_lt_b = not_a & b;
    assign a_eq_b = (a & b) | (not_a & not_b);
endmodule

module comp_cell_4bit_structural (
    input  logic [3:0] a, b,
    output logic       group_gt, group_lt, group_eq
);
    logic [3:0] G, L, E;
    comp_1bit_structural u_b3 (.a(a[3]), .b(b[3]), .a_gt_b(G[3]), .a_lt_b(L[3]), .a_eq_b(E[3]));
    comp_1bit_structural u_b2 (.a(a[2]), .b(b[2]), .a_gt_b(G[2]), .a_lt_b(L[2]), .a_eq_b(E[2]));
    comp_1bit_structural u_b1 (.a(a[1]), .b(b[1]), .a_gt_b(G[1]), .a_lt_b(L[1]), .a_eq_b(E[1]));
    comp_1bit_structural u_b0 (.a(a[0]), .b(b[0]), .a_gt_b(G[0]), .a_lt_b(L[0]), .a_eq_b(E[0]));

    logic e32, e10;
    assign e32 = E[3] & E[2];
    assign e10 = E[1] & E[0];
    assign group_eq = e32 & e10;

    // Group Greater Logic
    logic t_g2, t_g1, t_g0;
    assign t_g2 = E[3] & G[2];
    assign t_g1 = e32 & G[1]; 
    assign t_g0 = e32 & E[1] & G[0];
    assign group_gt = G[3] | t_g2 | t_g1 | t_g0;
    
    // Group Less Logic
    logic t_l2, t_l1, t_l0;
    assign t_l2 = E[3] & L[2];
    assign t_l1 = e32 & L[1]; 
    assign t_l0 = e32 & E[1] & L[0];
    assign group_lt = L[3] | t_l2 | t_l1 | t_l0; 
endmodule

module comparator_28bit_optimized (
    input  logic [27:0] a, b,
    output logic        a_ge_b
);
    logic [6:0] G, E;
    // 7 parallel blocks
    comp_cell_4bit_structural u_grp0 (.a(a[3:0]),   .b(b[3:0]),   .group_gt(G[0]), .group_eq(E[0]), .group_lt());
    comp_cell_4bit_structural u_grp1 (.a(a[7:4]),   .b(b[7:4]),   .group_gt(G[1]), .group_eq(E[1]), .group_lt());
    comp_cell_4bit_structural u_grp2 (.a(a[11:8]),  .b(b[11:8]),  .group_gt(G[2]), .group_eq(E[2]), .group_lt());
    comp_cell_4bit_structural u_grp3 (.a(a[15:12]), .b(b[15:12]), .group_gt(G[3]), .group_eq(E[3]), .group_lt());
    comp_cell_4bit_structural u_grp4 (.a(a[19:16]), .b(b[19:16]), .group_gt(G[4]), .group_eq(E[4]), .group_lt());
    comp_cell_4bit_structural u_grp5 (.a(a[23:20]), .b(b[23:20]), .group_gt(G[5]), .group_eq(E[5]), .group_lt());
    comp_cell_4bit_structural u_grp6 (.a(a[27:24]), .b(b[27:24]), .group_gt(G[6]), .group_eq(E[6]), .group_lt());

    // Propagate Logic (FLATTENED for Speed - No Ripple)
    logic [5:0] P;
    assign P[5] = E[6];
    assign P[4] = E[6] & E[5];
    assign P[3] = E[6] & E[5] & E[4];
    assign P[2] = E[6] & E[5] & E[4] & E[3];
    assign P[1] = E[6] & E[5] & E[4] & E[3] & E[2];
    assign P[0] = E[6] & E[5] & E[4] & E[3] & E[2] & E[1];

    logic a_gt_b, a_eq_b;
    // Greater: G6 | (P5&G5) | (P4&G4) ...
    assign a_gt_b = G[6] | (P[5]&G[5]) | (P[4]&G[4]) | (P[3]&G[3]) | (P[2]&G[2]) | (P[1]&G[1]) | (P[0]&G[0]);
    assign a_eq_b = P[0] & E[0]; // All groups equal

    assign a_ge_b = a_gt_b | a_eq_b;
endmodule

module inc_cell_4bit (
    input  logic [3:0] a,
    input  logic       cin,
    output logic [3:0] sum,
    output logic       group_propagate
);
    logic [3:0] c;
    assign sum[0] = a[0] ^ cin;  assign c[0] = a[0] & cin;
    assign sum[1] = a[1] ^ c[0]; assign c[1] = a[1] & c[0];
    assign sum[2] = a[2] ^ c[1]; assign c[2] = a[2] & c[1];
    assign sum[3] = a[3] ^ c[2];
    assign group_propagate = &a; 
endmodule

module lcu_6group_incrementer (
    input  logic [5:0] p,
    input  logic       cin_global,
    output logic [5:0] c_group
);
    // FLATTENED LOGIC: Tính toán song song, không chờ đợi (ripple)
    assign c_group[0] = cin_global;
    assign c_group[1] = cin_global & p[0];
    assign c_group[2] = cin_global & p[0] & p[1];
    assign c_group[3] = cin_global & p[0] & p[1] & p[2];
    assign c_group[4] = cin_global & p[0] & p[1] & p[2] & p[3];
    assign c_group[5] = cin_global & p[0] & p[1] & p[2] & p[3] & p[4];
endmodule

module incrementer_24bit_optimized (
    input  logic [23:0] A,
    output logic [23:0] S,
    output logic        Cout
);
    logic [5:0] p_grp, c_grp;
    // LCU tính carry cho tất cả các nhóm cùng lúc
    lcu_6group_incrementer u_lcu (.p(p_grp), .cin_global(1'b1), .c_group(c_grp));

    inc_cell_4bit u0 (.a(A[3:0]),   .cin(c_grp[0]), .sum(S[3:0]),   .group_propagate(p_grp[0]));
    inc_cell_4bit u1 (.a(A[7:4]),   .cin(c_grp[1]), .sum(S[7:4]),   .group_propagate(p_grp[1]));
    inc_cell_4bit u2 (.a(A[11:8]),  .cin(c_grp[2]), .sum(S[11:8]),  .group_propagate(p_grp[2]));
    inc_cell_4bit u3 (.a(A[15:12]), .cin(c_grp[3]), .sum(S[15:12]), .group_propagate(p_grp[3]));
    inc_cell_4bit u4 (.a(A[19:16]), .cin(c_grp[4]), .sum(S[19:16]), .group_propagate(p_grp[4]));
    inc_cell_4bit u5 (.a(A[23:20]), .cin(c_grp[5]), .sum(S[23:20]), .group_propagate(p_grp[5]));
    
    assign Cout = c_grp[5] & p_grp[5];
endmodule

// WRAPPER: Compatible with fpu_normalization
module incrementer_23bit (input [22:0] A, output [22:0] S);
    logic [23:0] A_pad, S_pad;
    assign A_pad = {1'b0, A};
    incrementer_24bit_optimized u_core (.A(A_pad), .S(S_pad), .Cout());
    assign S = S_pad[22:0];
endmodule

// WRAPPER: Compatible with fpu_normalization
// UPDATED: Use 4-bit cells for better structure and timing
module incrementer_8bit (input [7:0] A, output [7:0] S, output Cout);
    logic p_low, c_mid, p_high;
    
    // Nhóm thấp
    inc_cell_4bit u_lo (.a(A[3:0]), .cin(1'b1), .sum(S[3:0]), .group_propagate(p_low));
    
    assign c_mid = p_low; // Carry chuyển sang nhóm cao
    
    // Nhóm cao
    inc_cell_4bit u_hi (.a(A[7:4]), .cin(c_mid), .sum(S[7:4]), .group_propagate(p_high));
    
    assign Cout = p_low & p_high;
endmodule


// Block 4-bit báo cáo P/G
module cla_4bit_super (
    input  logic [3:0] a, b, cin,
    output logic [3:0] sum,
    output logic       group_p, group_g
);
    logic [3:0] p, g, c;
    assign p = a ^ b; 
    assign g = a & b;
    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c[0]);
    assign sum  = p ^ c;

    assign group_p = &p; // All propagate
    assign group_g = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);
endmodule

// Lookahead Carry Unit (LCU) cho 7 nhóm (Already optimized)
module lcu_7group_adder (
    input  logic [6:0] P, G,
    input  logic       cin_global,
    output logic [6:0] C
);
    assign C[0] = cin_global;
    assign C[1] = G[0] | (P[0] & cin_global);
    assign C[2] = G[1] | (P[1] & G[0]) | (P[1] & P[0] & cin_global);
    assign C[3] = G[2] | (P[2] & G[1]) | (P[2] & P[1] & G[0]) | (P[2] & P[1] & P[0] & cin_global);
    assign C[4] = G[3] | (P[3] & C[3]); 
    assign C[5] = G[4] | (P[4] & G[3]) | (P[4] & P[3] & C[3]);
    assign C[6] = G[5] | (P[5] & C[5]);
endmodule

// WRAPPER: Compatible with fpu_sig_add_sub (REPLACES OLD MANUAL ADDER)
(* flatten *)
module cla_adder_28bit_manual (
    input  logic [27:0] a, b, cin,
    output logic [27:0] sum,
    output logic        cout
);
    logic [6:0] P_grp, G_grp, C_grp;
    
    // Central LCU
    lcu_7group_adder u_lcu (.P(P_grp), .G(G_grp), .cin_global(cin), .C(C_grp));

    // Parallel Blocks
    cla_4bit_super u0 (.a(a[3:0]),   .b(b[3:0]),   .cin(C_grp[0]), .sum(sum[3:0]),   .group_p(P_grp[0]), .group_g(G_grp[0]));
    cla_4bit_super u1 (.a(a[7:4]),   .b(b[7:4]),   .cin(C_grp[1]), .sum(sum[7:4]),   .group_p(P_grp[1]), .group_g(G_grp[1]));
    cla_4bit_super u2 (.a(a[11:8]),  .b(b[11:8]),  .cin(C_grp[2]), .sum(sum[11:8]),  .group_p(P_grp[2]), .group_g(G_grp[2]));
    cla_4bit_super u3 (.a(a[15:12]), .b(b[15:12]), .cin(C_grp[3]), .sum(sum[15:12]), .group_p(P_grp[3]), .group_g(G_grp[3]));
    cla_4bit_super u4 (.a(a[19:16]), .b(b[19:16]), .cin(C_grp[4]), .sum(sum[19:16]), .group_p(P_grp[4]), .group_g(G_grp[4]));
    cla_4bit_super u5 (.a(a[23:20]), .b(b[23:20]), .cin(C_grp[5]), .sum(sum[23:20]), .group_p(P_grp[5]), .group_g(G_grp[5]));
    cla_4bit_super u6 (.a(a[27:24]), .b(b[27:24]), .cin(C_grp[6]), .sum(sum[27:24]), .group_p(P_grp[6]), .group_g(G_grp[6]));

    assign cout = G_grp[6] | (P_grp[6] & C_grp[6]);
endmodule

// WRAPPER: Compatible with fpu_exponent_subtractor
module adder_8bit_manual (
    input  logic [7:0] a, b, cin,
    output logic [7:0] sum,
    output logic       cout
);
    // Logic ripple giữa 2 block 4-bit là chấp nhận được cho 8-bit
    logic c_mid;
    logic [3:0] g0, p0; 
    assign p0 = a[3:0] ^ b[3:0]; assign g0 = a[3:0] & b[3:0];
    assign c_mid = g0[3] | (p0[3] & g0[2]) | (p0[3] & p0[2] & g0[1]) | (p0[3] & p0[2] & p0[1] & g0[0]) | (p0[3] & p0[2] & p0[1] & p0[0] & cin);

    cla_4bit_super u0 (.a(a[3:0]), .b(b[3:0]), .cin(cin),   .sum(sum[3:0]), .group_p(), .group_g());
    cla_4bit_super u1 (.a(a[7:4]), .b(b[7:4]), .cin(c_mid), .sum(sum[7:4]), .group_p(), .group_g());
    
    // Cout calculation
    logic [3:0] g1, p1;
    assign p1 = a[7:4] ^ b[7:4]; assign g1 = a[7:4] & b[7:4];
    assign cout = g1[3] | (p1[3] & g1[2]) | (p1[3] & p1[2] & g1[1]) | (p1[3] & p1[2] & p1[1] & g1[0]) | (p1[3] & p1[2] & p1[1] & p1[0] & c_mid);
endmodule


module barrel_shifter_right_27 (
    input  logic [26:0] in_data,
    input  logic [4:0]  shift_amt,
    output logic [54:0] out_data
);
    logic [54:0] s0, s1, s2, s3, s4, pad_in;
    assign pad_in = {in_data, 28'd0};
    assign s0 = shift_amt[0] ? {1'b0,     pad_in[54:1]} : pad_in;
    assign s1 = shift_amt[1] ? {2'b00,    s0[54:2]}     : s0;
    assign s2 = shift_amt[2] ? {4'h0,     s1[54:4]}     : s1;
    assign s3 = shift_amt[3] ? {8'h00,    s2[54:8]}     : s2;
    assign s4 = shift_amt[4] ? {16'h0000, s3[54:16]}    : s3;
    assign out_data = s4;
endmodule


module barrel_shifter_left_manual (
    input  logic [26:0] in_data,
    input  logic [4:0]  shift_amt,
    output logic [26:0] out_data
);
    logic [26:0] s0, s1, s2, s3, s4;
    assign s0 = shift_amt[0] ? {in_data[25:0], 1'b0} : in_data;
    assign s1 = shift_amt[1] ? {s0[24:0], 2'b00}     : s0;
    assign s2 = shift_amt[2] ? {s1[22:0], 4'h0}      : s1;
    assign s3 = shift_amt[3] ? {s2[18:0], 8'h00}     : s2;
    assign s4 = shift_amt[4] ? {s3[10:0], 16'h0000}  : s3;
    assign out_data = s4;
endmodule

module lzc_cell_2 (input logic [1:0] in, output logic v, p);
    assign v = in[1] | in[0];
    assign p = in[1];
endmodule

module lzc_cell_4 (input logic [3:0] in, output logic v, output logic [1:0] p);
    logic v_hi, v_lo, p_hi, p_lo;
    lzc_cell_2 u_hi (.in(in[3:2]), .v(v_hi), .p(p_hi));
    lzc_cell_2 u_lo (.in(in[1:0]), .v(v_lo), .p(p_lo));
    assign v = v_hi | v_lo;
    assign p[1] = v_hi;
    assign p[0] = v_hi ? p_hi : p_lo;
endmodule

module lzc_cell_8 (input logic [7:0] in, output logic v, output logic [2:0] p);
    logic v_hi, v_lo; logic [1:0] p_hi, p_lo;
    lzc_cell_4 u_hi (.in(in[7:4]), .v(v_hi), .p(p_hi));
    lzc_cell_4 u_lo (.in(in[3:0]), .v(v_lo), .p(p_lo));
    assign v = v_hi | v_lo;
    assign p[2]   = v_hi;
    assign p[1:0] = v_hi ? p_hi : p_lo;
endmodule

module lzc_cell_16 (input logic [15:0] in, output logic v, output logic [3:0] p);
    logic v_hi, v_lo; logic [2:0] p_hi, p_lo;
    lzc_cell_8 u_hi (.in(in[15:8]), .v(v_hi), .p(p_hi));
    lzc_cell_8 u_lo (.in(in[7:0]),  .v(v_lo), .p(p_lo));
    assign v = v_hi | v_lo;
    assign p[3]   = v_hi;
    assign p[2:0] = v_hi ? p_hi : p_lo;
endmodule

module lzc_32_tree (input logic [31:0] in, output logic [4:0] count);
    logic v_hi, v_lo, v_total; logic [3:0] p_hi, p_lo; logic [4:0] pos;
    lzc_cell_16 u_hi (.in(in[31:16]), .v(v_hi), .p(p_hi));
    lzc_cell_16 u_lo (.in(in[15:0]),  .v(v_lo), .p(p_lo));
    assign v_total = v_hi | v_lo;
    assign pos[4]   = v_hi;
    assign pos[3:0] = v_hi ? p_hi : p_lo;
    assign count = v_total ? (~pos) : 5'b11000;
endmodule