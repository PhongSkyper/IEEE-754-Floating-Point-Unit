`timescale 1ns/1ps

module fpu_swap_operands #(
    parameter int unsigned SIG_W = 24
) (
    input  logic [7:0]       exp_a, exp_b,
    input  logic [SIG_W-1:0] sig_a, sig_b,
    input  logic             a_ge_b_exp, // Kết quả so sánh mũ (từ bộ trừ mũ)
    input  logic             ex_eq,      // Cờ báo mũ bằng nhau
    output logic [7:0]       exp_big, exp_small,
    output logic [SIG_W-1:0] sig_big, sig_small,
    output logic             a_is_big_mag
);

    // Logic so sánh phần định trị (Significand)
    logic sig_a_ge_b;

    // =========================================================
    // UPDATE: Dùng Comparator tối ưu thay vì Adder
    // =========================================================
    // Mở rộng input lên 28 bit (pad 4 bit 0 vào MSB) để khớp với module comparator
    // Không cần bù 1, bù 2 hay cin như bộ cộng nữa
    comparator_28bit_optimized u_cmp_sig (
        .a      ({4'd0, sig_a}),
        .b      ({4'd0, sig_b}),
        .a_ge_b (sig_a_ge_b)
    );

    // =========================================================
    // Logic quyết định (Decision Logic)
    // =========================================================
    logic a_big_final;
    
    // Nếu mũ bằng nhau (ex_eq=1) -> Dùng kết quả so sánh sig (sig_a_ge_b)
    // Nếu mũ khác nhau -> Dùng kết quả so sánh mũ đã có từ trước (a_ge_b_exp)
    mux2 #(.N(1)) u_mux_decision (
        .d0 (a_ge_b_exp),
        .d1 (sig_a_ge_b),
        .sel(ex_eq),
        .y  (a_big_final)
    );

    assign a_is_big_mag = a_big_final;

    // =========================================================
    // Mux Swap Output
    // =========================================================
    // Nếu a_big_final = 1 (A >= B) -> Giữ nguyên
    // Nếu a_big_final = 0 (A < B)  -> Tráo đổi (Swap)
    
    mux2 #(.N(8))     u_mux_exp_big   (.d0(exp_b), .d1(exp_a), .sel(a_big_final), .y(exp_big));
    mux2 #(.N(8))     u_mux_exp_small (.d0(exp_a), .d1(exp_b), .sel(a_big_final), .y(exp_small));
    
    mux2 #(.N(SIG_W)) u_mux_sig_big   (.d0(sig_b), .d1(sig_a), .sel(a_big_final), .y(sig_big));
    mux2 #(.N(SIG_W)) u_mux_sig_small (.d0(sig_a), .d1(sig_b), .sel(a_big_final), .y(sig_small));

endmodule