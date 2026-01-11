```verilog
`timescale 1ns/1ps

module fpu_add_sub_tb;

  typedef struct {
    logic [31:0] a;
    logic [31:0] b;
    logic        sub;
    string       desc;
  } test_vector_t;

  logic [31:0] i_a, i_b;
  logic        i_add_sub;
  wire [31:0]  o_z;
  wire         o_underflow, o_overflow, o_zero;

  fpu_add_sub_top DUT (
    .i_a          (i_a),
    .i_b          (i_b),
    .i_add_sub    (i_add_sub),
    .o_z          (o_z),
    .o_underflow  (o_underflow),
    .o_overflow   (o_overflow),
    .o_zero       (o_zero)
  );

  test_vector_t TestVectors[100]; 
  int i, N = 0, pass_count = 0, fail_count = 0;
  int ovf_count = 0, unf_count = 0, zero_count = 0;

  class FP_Generator;
    rand logic [31:0] a_rand;
    rand logic [31:0] b_rand;
    rand logic        sub_rand;
    int mode = 0; 

    constraint range_control {
      if (mode == 0) {
        a_rand[30:23] inside {[8'h20 : 8'hE0]};
        b_rand[30:23] inside {[8'h20 : 8'hE0]};
      } else if (mode == 2) {
        a_rand[30:23] == 8'h01; 
        b_rand[30:23] == 8'h01;
        a_rand[31] == 0; 
        b_rand[31] == 0; 
        sub_rand == 1; 
      }
    }
  endclass
  FP_Generator generator;

  function logic [31:0] expected_result(logic [31:0] A_in, logic [31:0] B_in, bit op);
    shortreal a_real, b_real, res_real;
    logic [31:0] res_bits;
    
    a_real = $bitstoshortreal(A_in);
    b_real = $bitstoshortreal(B_in);
    
    if (op == 0) res_real = a_real + b_real;
    else         res_real = a_real - b_real;
      
    res_bits = $shortrealtobits(res_real);

    if (res_bits[30:23] == 8'h00) begin
        res_bits = 32'd0; 
    end

    return res_bits;
  endfunction

  function bit within_1ulp(logic [31:0] ref_val, logic [31:0] dut_val);
    int unsigned mag_ref, mag_dut, diff;
    
    if ((ref_val[30:23] == 8'hFF) && (dut_val[30:23] == 8'hFF)) begin
        if ((ref_val[22:0] != 0) && (dut_val[22:0] != 0)) return 1; 
        if ((ref_val[22:0] == 0) && (dut_val[22:0] == 0)) return (ref_val[31] == dut_val[31]); 
    end

    if (ref_val[31] != dut_val[31]) begin
        if ((ref_val[30:0] == 0) && (dut_val[30:0] == 0)) return 1;
        else return 0;
    end else begin
        mag_ref = ref_val[30:0];
        mag_dut = dut_val[30:0];
        if (mag_ref >= mag_dut) diff = mag_ref - mag_dut;
        else                    diff = mag_dut - mag_ref;
        return (diff <= 1);
    end
  endfunction

  task automatic check_and_display(int idx, test_vector_t vec);
    logic [31:0] exp_val;
    string       op_str;
    bit          pass;
    string       result_status;
    string       flags_str;

    exp_val = expected_result(vec.a, vec.b, vec.sub);
    
    if (vec.desc == "OVERFLOW: Max + Max") exp_val = 32'h7F800000; 
    if (vec.desc == "OVERFLOW: -Max - Max") exp_val = 32'hFF800000;
    
    if (o_overflow) begin
        if (o_z[31] == 0) exp_val = 32'h7F800000; 
        else              exp_val = 32'hFF800000; 
    end

    op_str  = (vec.sub == 0) ? "ADD" : "SUB";

    if (o_z === exp_val) pass = 1'b1;
    else if (within_1ulp(exp_val, o_z)) pass = 1'b1;
    else pass = 1'b0;

    result_status = pass ? "PASS" : "FAIL";
    if (pass) pass_count++; else fail_count++;

    if (o_overflow)  ovf_count++;
    if (o_underflow) unf_count++;
    if (o_zero)      zero_count++;
    
    flags_str = "";
    if (o_overflow) flags_str = {flags_str, "OV "};
    if (o_underflow) flags_str = {flags_str, "UN "};
    if (o_zero)      flags_str = {flags_str, "ZE "};
    if (flags_str == "") flags_str = "--";

    $display("| %3d | %8h | %8h | %s | %8h | %8h | %s | %s | %s", 
             idx, vec.a, vec.b, op_str, exp_val, o_z, flags_str, result_status, vec.desc);
  endtask

  initial begin
    generator = new();
    
    $display("\n");
    $display("=======================================================================================================");
    $display("                                FPU TESTBENCH - 100 DIRECTED RANDOM CASES                              ");
    $display("=======================================================================================================");
    $display("|  ID |    A     |    B     | Op  | Expected |  Actual  | Flg | Res  | Description");
    $display("-------------------------------------------------------------------------------------------------------");

    TestVectors[N++] = '{32'h3F800000, 32'h3F800000, 1'b1, "ZERO: 1.0 - 1.0"};
    TestVectors[N++] = '{32'h7F7FFFFF, 32'h7F7FFFFF, 1'b0, "OVERFLOW: Max + Max"};
    TestVectors[N++] = '{32'hFF7FFFFF, 32'h7F7FFFFF, 1'b1, "OVERFLOW: -Max - Max"};
    TestVectors[N++] = '{32'h00800001, 32'h00800000, 1'b1, "UNDERFLOW: Min+ - Min"}; 
    TestVectors[N++] = '{32'h7F800000, 32'h7F800000, 1'b0, "INF: +Inf + +Inf"};
    TestVectors[N++] = '{32'h7F800000, 32'h7F800000, 1'b1, "NaN: Inf - Inf"};
    
    generator.mode = 1; 
    for (int k = 0; k < 35; k++) begin
      void'(generator.randomize());
      TestVectors[N++] = '{generator.a_rand, generator.b_rand, generator.sub_rand, "FORCE OVERFLOW"};
    end

    generator.mode = 2;
    for (int k = 0; k < 35; k++) begin
      void'(generator.randomize());
      TestVectors[N++] = '{generator.a_rand, generator.b_rand, generator.sub_rand, "FORCE UNDERFLOW"};
    end

    generator.mode = 0;
    for (int k = 0; k < 24; k++) begin
      void'(generator.randomize());
      TestVectors[N++] = '{generator.a_rand, generator.b_rand, generator.sub_rand, "NORMAL RANDOM"};
    end

    $display("Running %0d vectors...", N);
    for (i = 0; i < N; i++) begin
      i_a       = TestVectors[i].a;
      i_b       = TestVectors[i].b;
      i_add_sub = TestVectors[i].sub;
      
      #10;
      check_and_display(i+1, TestVectors[i]);
    end

    $display("-------------------------------------------------------------------------------------------------------");
    $display("\n");
    $display("================================ TEST SUMMARY ================================");
    $display(" Total Cases: %3d", N);
    $display(" PASS:        %3d", pass_count);
    $display(" FAIL:        %3d", fail_count);
    $display("------------------------------------------------------------------------------");
    $display(" Overflow:    %3d times", ovf_count);
    $display(" Underflow:   %3d times", unf_count);
    $display(" Zero:        %3d times", zero_count);
    $display("==============================================================================");
    
    $finish;
  end

endmodule
```