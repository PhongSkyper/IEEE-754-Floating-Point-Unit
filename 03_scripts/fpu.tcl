set_db init_lib_search_path {/home/yellow/ee3213_03/fpu_synth/gpdk045_lib} 
set_db init_hdl_search_path {../00_src}

read_libs slow_vdd1v0_basicCells_hvt.lib
#set_db library slow_vdd1v0_basicCells_hvt.lib

read_hdl -sv { \ 
    fpu_basic_lib.sv \
    fpu_unpack_pretest.sv \
    fpu_special_case.sv \
    fpu_exponent_subtractor.sv \
    fpu_swap_operands.sv \
    fpu_align_shift_right.sv \
    fpu_sig_add_sub.sv \
    fpu_sign_computation.sv \
    fpu_normalization.sv \
    fpu_add_sub_top.sv \
}

elaborate fpu_add_sub_top

set_db syn_generic_effort medium
set_db syn_map_effort medium
#set_db syn_opt_effort medium

syn_generic
syn_map
#syn_opt 

report_timing > ../02_reports/timing.rpt
report_power  > ../02_reports/power.rpt
report_area   > ../02_reports/area.rpt
report_qor    > ../02_reports/qor.rpt

write_hdl > ../03_outputs/fpu_add_sub_netlist.v

write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > ../03_outputs/fpu_delay.sdf
