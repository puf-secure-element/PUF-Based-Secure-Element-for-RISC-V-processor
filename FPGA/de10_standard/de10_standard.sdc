create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# Ring oscillators are intentional asynchronous measurement clocks. They are
# counted in their own clock domains and must not be timed as CLOCK_50 logic.
# NOTE: plain get_nets only searches the current (top-level) scope; ro_clk
# only exists as a net deep inside ro_puf_core/ro_bank's hierarchy, so
# without -hierarchical these filters silently matched nothing ("Ignored
# filter ... could not be matched with a net") and never actually took
# effect.
set_false_path -from [get_nets -hierarchical *ro_clk*]
set_false_path -to [get_nets -hierarchical *ro_clk*]