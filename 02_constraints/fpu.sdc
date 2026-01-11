# 1. Tạo xung clock (Ví dụ 50MHz = 20ns)
create_clock -name clk -period 20.0 [get_ports clk]

set_max_delay 35.0 -from [all_inputs] -to [all_outputs]

set_input_delay -clock clk -max 2.0 [all_inputs]
set_output_delay -clock clk -max 2.0 [all_outputs]