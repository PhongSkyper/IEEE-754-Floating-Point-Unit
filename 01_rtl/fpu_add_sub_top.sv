`timescale 1ns/1ps
module fpu_add_sub_top (
    input  logic [31:0] i_a,
    input  logic [31:0] i_b,
    input  logic        i_add_sub,
    output logic [31:0] o_z,
    output logic        o_overflow,
    output logic        o_underflow,
    output logic        o_zero
);
    logic        sign_a, sign_b;
    logic [7:0]  exp_a_raw, exp_b_raw;
    logic [22:0] frac_a, frac_b;
    logic        is_zero_a, is_zero_b;
    logic        is_inf_a,  is_inf_b;
    logic        is_nan_a,  is_nan_b;
    logic        is_subn_a, is_subn_b;
    
    fpu_unpack_pretest u_unpack (
        .raw_a      (i_a),
        .raw_b      (i_b),
        .sign_a     (sign_a),
        .sign_b     (sign_b),
        .exp_a      (exp_a_raw),
        .exp_b      (exp_b_raw),
        .frac_a     (frac_a),
        .frac_b     (frac_b),
        .is_zero_a  (is_zero_a),
        .is_zero_b  (is_zero_b),
        .is_inf_a   (is_inf_a),
        .is_inf_b   (is_inf_b),
        .is_nan_a   (is_nan_a),
        .is_nan_b   (is_nan_b),
        .is_subn_a  (is_subn_a),
        .is_subn_b  (is_subn_b)
    );

    logic sign_b_eff;
    xor_gate_2 u_xor_b (
        .a (sign_b),
        .b (i_add_sub),
        .y (sign_b_eff)
    );

    logic        special_valid;
    logic [31:0] special_res;
    fpu_special_case u_special (
        .sign_a       (sign_a),
        .sign_b_eff   (sign_b_eff),
        .exp_a        (exp_a_raw),
        .exp_b        (exp_b_raw),
        .frac_a       (frac_a),
        .frac_b       (frac_b),
        .is_zero_a    (is_zero_a),
        .is_zero_b    (is_zero_b),
        .is_inf_a     (is_inf_a),
        .is_inf_b     (is_inf_b),
        .is_nan_a     (is_nan_a),
        .is_nan_b     (is_nan_b),
        .special_valid(special_valid),
        .special_res  (special_res)
    );

    logic [7:0]  exp_a_eff, exp_b_eff;
    logic [23:0] sig_a, sig_b;
    
    assign sig_a = {(~is_subn_a), frac_a};
    assign sig_b = {(~is_subn_b), frac_b};
    assign exp_a_eff = is_subn_a ? 8'd1 : exp_a_raw;
    assign exp_b_eff = is_subn_b ? 8'd1 : exp_b_raw;

    logic [7:0] exp_max, exp_min;
    logic [4:0] exp_diff;
    logic       a_ge_b_exp;
    logic       ex_eq;
    
    fpu_exponent_subtractor u_exp_sub (
        .exp_a   (exp_a_eff),
        .exp_b   (exp_b_eff),
        .exp_max (exp_max),
        .exp_min (exp_min),
        .exp_diff(exp_diff),
        .a_ge_b  (a_ge_b_exp),
        .ex_eq   (ex_eq)
    );

    logic [7:0]  exp_big, exp_small;
    logic [23:0] sig_big, sig_small;
    logic        a_is_big_mag;
    
    fpu_swap_operands #(.SIG_W(24)) u_swap (
        .exp_a       (exp_a_eff),
        .exp_b       (exp_b_eff),
        .sig_a       (sig_a),
        .sig_b       (sig_b),
        .a_ge_b_exp  (a_ge_b_exp),
        .ex_eq       (ex_eq),
        .exp_big     (exp_big),
        .exp_small   (exp_small),
        .sig_big     (sig_big),
        .sig_small   (sig_small),
        .a_is_big_mag(a_is_big_mag)
    );

    logic sign_big, sign_small;
    logic add_path;
    
    fpu_sign_computation u_sign_comp (
        .sign_a     (sign_a),
        .sign_b_eff (sign_b_eff),
        .a_is_big   (a_is_big_mag),
        .sign_big   (sign_big),
        .sign_small (sign_small),
        .add_path   (add_path)
    );

    logic [26:0] sig_small_align;
    logic        guard_bit, round_bit, sticky_bit;
    
    fpu_align_shift_right #(.SIG_W(24)) u_align (
        .sig_small_in (sig_small),
        .shift_amt    (exp_diff),
        .sig_small_out(sig_small_align),
        .guard        (guard_bit),
        .round        (round_bit),
        .sticky       (sticky_bit)
    );

    logic [26:0] mant_big, mant_small;
    logic [26:0] mant_res;
    logic        carry_addsub;
    
    assign mant_big   = {sig_big, 3'b000};
    assign mant_small = sig_small_align;
    
    fpu_sig_add_sub u_sig_addsub (
        .mant_big  (mant_big),
        .mant_small(mant_small),
        .add_path  (add_path),
        .mant_res  (mant_res),
        .carry_out (carry_addsub)
    );

    logic [7:0]  exp_norm;
    logic [22:0] frac_norm;
    logic        ovf_norm, unf_norm;
    logic        is_zero_norm;
    
    fpu_normalization u_norm_final (
        .is_add_path (add_path),
        .carry_in    (carry_addsub),
        .mant_in     (mant_res),
        .exp_in      (exp_big),
        .exp_out     (exp_norm),
        .frac_out    (frac_norm),
        .overflow    (ovf_norm),
        .underflow   (unf_norm),
        .is_zero     (is_zero_norm)
    );

    logic sign_z_normal;
    logic [31:0] normal_res;
    
    mux2 #(.N(1)) u_mux_sign_zero (
        .d0 (sign_big),
        .d1 (1'b0),
        .sel(is_zero_norm),
        .y  (sign_z_normal)
    );
    
    assign normal_res = {sign_z_normal, exp_norm, frac_norm};

    mux2 #(.N(32)) u_mux_result (
        .d0 (normal_res),
        .d1 (special_res),
        .sel(special_valid),
        .y  (o_z)
    );

    assign o_overflow  = (~special_valid) & ovf_norm;
    assign o_underflow = (~special_valid) & unf_norm;
    
    logic zero_norm_total;
    logic zero_special_exp, zero_special_frac, zero_special;
    
    assign zero_norm_total = is_zero_norm;
    assign zero_special_exp  = ~(|special_res[30:23]);
    assign zero_special_frac = ~(|special_res[22:0]);
    assign zero_special      = zero_special_exp & zero_special_frac;
    
    mux2 #(.N(1)) u_mux_zero (
        .d0 (zero_norm_total),
        .d1 (zero_special),
        .sel(special_valid),
        .y  (o_zero)
    );
endmodule