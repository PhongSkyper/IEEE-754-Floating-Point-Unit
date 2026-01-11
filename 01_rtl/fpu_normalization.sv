`timescale 1ns/1ps

module fpu_normalization (
    input  logic        is_add_path,
    input  logic        carry_in,
    input  logic [26:0] mant_in,
    input  logic [7:0]  exp_in,
    output logic [7:0]  exp_out,
    output logic [22:0] frac_out,
    output logic        overflow,
    output logic        underflow,
    output logic        is_zero
);

    logic is_overflow_add;
    and_gate_2 u_and_ovf (.a(is_add_path), .b(carry_in), .y(is_overflow_add));

    // Logic làm tròn (Rounding) cho Path A
    logic r_guard, r_round, r_sticky, r_lsb, need_round_right;
    assign r_guard  = mant_in[3];
    assign r_round  = mant_in[2];
    assign r_sticky = mant_in[1] | mant_in[0];
    assign r_lsb    = mant_in[4];
    
    // need_round = G & (R | S | LSB)
    logic round_sticky_lsb;
    assign round_sticky_lsb = r_round | r_sticky | r_lsb;
    and_gate_2 u_round_cond (.a(r_guard), .b(round_sticky_lsb), .y(need_round_right));

    // Tăng mantissa lên 1 (Dùng module incrementer có sẵn)
    logic [22:0] mant_right_rounded;
    incrementer_23bit u_inc_mant (.A(mant_in[26:4]), .S(mant_right_rounded));

    // Tăng exponent lên 1 (Dùng module incrementer)
    logic [7:0] exp_inc;
    logic       exp_inc_ovf;
    incrementer_8bit u_inc_exp (.A(exp_in), .S(exp_inc), .Cout(exp_inc_ovf));

    // Kiểm tra overflow exponent
    logic exp_is_254, ovf_right;
    assign exp_is_254 = &exp_in[7:1] & ~exp_in[0]; // Check if exp == 254
    assign ovf_right  = exp_inc_ovf | (&exp_inc) | exp_is_254; // Check FF or Carry

    logic [7:0] exp_right_res;
    mux2 #(.N(8)) u_mux_exp_r (.d0(exp_inc), .d1(8'hFF), .sel(ovf_right), .y(exp_right_res));

    logic [22:0] mant_r_temp, mant_right_res;
    mux2 #(.N(23)) u_mux_rnd_r (.d0(mant_in[26:4]), .d1(mant_right_rounded), .sel(need_round_right), .y(mant_r_temp));
    mux2 #(.N(23)) u_mux_res_r (.d0(mant_r_temp), .d1(23'd0), .sel(ovf_right), .y(mant_right_res));
    
    // Lấy 24 bit cao để đếm số 0 (bỏ 3 bit GRS thấp)
    logic [23:0] mant_24_raw;
    assign mant_24_raw = mant_in[26:3];

    // TÌM SỐ BIT CẦN DỊCH 
    logic [4:0] shift_amt;
    // Pad thêm 8 bit 0 vào đuôi để đủ 32 bit input cho module LZC
    lzc_32_tree u_fast_lzc (.in({mant_24_raw, 8'h00}), .count(shift_amt));

    //  DỊCH TRÁI 
    logic [26:0] shift_out_full;
    barrel_shifter_left_manual u_shifter_l (
        .in_data(mant_in), 
        .shift_amt(shift_amt), 
        .out_data(shift_out_full)
    );
    
    logic [22:0] mant_left_res;
    assign mant_left_res = shift_out_full[25:3];

    // TRỪ EXPONENT (exp_out = exp_in - shift_amt)
    // Sử dụng phép cộng bù 2: A - B = A + (~B) + 1
    logic [7:0] exp_sub_res;
    logic       exp_sub_cout; // Nếu cout=1 nghĩa là kết quả dương (không underflow)
    logic [7:0] not_shift_amt;
    
    assign not_shift_amt = {3'b111, ~shift_amt}; // Pad 3 bit 1 (sign extend cho số âm)

    adder_8bit_manual u_sub_exp (
        .a(exp_in), 
        .b(not_shift_amt), // ~B 
        .cin(1'b1),        // +1
        .sum(exp_sub_res), 
        .cout(exp_sub_cout)
    );

    logic mant_is_zero;
    zero_detect #(.N(24)) u_check_zero (.a(mant_24_raw), .is_zero(mant_is_zero));

    logic unf_left;
    // Underflow nếu phép trừ bị âm (cout=0) và mantissa không phải zero
    assign unf_left = (~exp_sub_cout) & (~mant_is_zero);

    logic [7:0] exp_left_res;
    mux2 #(.N(8)) u_mux_exp_l (.d0(8'd0), .d1(exp_sub_res), .sel(exp_sub_cout), .y(exp_left_res));


    logic use_right_path;
    // Nếu có overflow từ phép cộng, ưu tiên dùng Path A (Right Shift)
    assign use_right_path = is_overflow_add;

    logic [7:0]  exp_pre_final;
    logic [22:0] frac_pre_final;
    logic        ovf_final, unf_final;

    // Mux chọn giữa Path A và Path B
    mux2 #(.N(8))  u_mux_final_exp  (.d0(exp_left_res),  .d1(exp_right_res),  .sel(use_right_path), .y(exp_pre_final));
    mux2 #(.N(23)) u_mux_final_frac (.d0(mant_left_res), .d1(mant_right_res), .sel(use_right_path), .y(frac_pre_final));
    mux2 #(.N(1))  u_mux_final_ovf  (.d0(1'b0),          .d1(ovf_right),      .sel(use_right_path), .y(ovf_final));
    mux2 #(.N(1))  u_mux_final_unf  (.d0(unf_left),      .d1(1'b0),           .sel(use_right_path), .y(unf_final));

    // Logic kiểm tra Zero/Inf cuối cùng
    logic frac_is_zero, exp_is_zero;
    zero_detect #(.N(23)) u_z1 (.a(frac_pre_final), .is_zero(frac_is_zero));
    zero_detect #(.N(8))  u_z2 (.a(exp_pre_final),  .is_zero(exp_is_zero));

    logic result_cancellation;
    assign result_cancellation = (!use_right_path) & mant_is_zero;

    // Cờ Zero tổng hợp
    assign is_zero = (frac_is_zero & exp_is_zero) | result_cancellation;

    logic real_underflow;
    assign real_underflow = (unf_final | exp_is_zero) & (~is_zero);

    logic result_is_inf;
    and_reduction_8 u_check_inf (.a(exp_pre_final), .y(result_is_inf));

    // Flush to zero logic (Xử lý các trường hợp đặc biệt về 0)
    logic [7:0] exp_final;
    logic [22:0] frac_final;

    mux2 #(.N(8))  u_flush_exp  (.d0(exp_pre_final), .d1(8'd0),  .sel(is_zero | real_underflow), .y(exp_final));
    
    // Nếu Inf -> frac = 0, Nếu Underflow -> frac = 0
    logic force_frac_zero;
    assign force_frac_zero = is_zero | real_underflow | result_is_inf;
    mux2 #(.N(23)) u_flush_frac (.d0(frac_pre_final),.d1(23'd0), .sel(force_frac_zero),          .y(frac_final));

    // Gán output cuối cùng
    assign exp_out   = exp_final;
    assign frac_out  = frac_final;
    assign overflow  = (ovf_final | result_is_inf) & (~is_zero);
    assign underflow = real_underflow;

endmodule