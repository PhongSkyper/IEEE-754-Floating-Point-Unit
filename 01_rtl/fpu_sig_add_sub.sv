`timescale 1ns/1ps
module fpu_sig_add_sub (
    input  logic [26:0] mant_big,
    input  logic [26:0] mant_small,
    input  logic        add_path,  
    output logic [26:0] mant_res,
    output logic        carry_out
);
    logic [27:0] sum_add_full, diff_sub_full;
    logic        cout_add, cout_sub;
    
    // ADD PATH: A + B
    // Pad thêm 1 bit 0 vào đầu để khớp với bộ cộng 28 bit
    cla_adder_28bit_manual u_add (
        .a   ({1'b0, mant_big}),
        .b   ({1'b0, mant_small}),
        .cin (1'b0),
        .sum (sum_add_full),
        .cout(cout_add)
    );
    
    // SUB PATH: A - B = A + (~B) + 1
    cla_adder_28bit_manual u_sub (
        .a   ({1'b0, mant_big}),
        .b   ({1'b0, ~mant_small}),
        .cin (1'b1),
        .sum (diff_sub_full),
        .cout(cout_sub) 
    );
    
    logic [26:0] sum_add, diff_sub;
    assign sum_add  = sum_add_full[26:0];
    assign diff_sub = diff_sub_full[26:0];
    
    mux2 #(.N(27)) u_mux_res (
        .d0 (diff_sub),
        .d1 (sum_add),
        .sel(add_path),
        .y  (mant_res)
    );
    
    // Chọn carry out tương ứng
    mux2 #(.N(1)) u_mux_cout (
        .d0 (cout_sub),
        .d1 (sum_add_full[27]),
        .sel(add_path),
        .y  (carry_out)
    );
endmodule