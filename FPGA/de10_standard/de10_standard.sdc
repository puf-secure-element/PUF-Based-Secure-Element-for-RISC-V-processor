create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
create_generated_clock -name clk_25 -divide_by 2 -source [get_ports {CLOCK_50}] [get_registers clk_25]

# Ring oscillators are intentional asynchronous measurement clocks. They are
# counted in their own clock domains and must not be timed as CLOCK_50 logic.
set_false_path -from [get_nets *ro_clk*]
set_false_path -to [get_nets *ro_clk*]
