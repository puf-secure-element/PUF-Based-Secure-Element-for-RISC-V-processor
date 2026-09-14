create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# Ring oscillators are intentional asynchronous measurement clocks. They are
# counted in their own clock domains and must not be timed as CLOCK_50 logic.
# NOTE: get_nets has no -hierarchical option in Quartus (it already searches
# the whole design by default) -- the real problem was the pattern itself:
# "ro_clk" is only a port/wire name pre-synthesis. Post-synthesis the actual
# oscillator net is named net_chain (see the "Found combinational loop"
# fitter warnings, e.g. RO_ARRAY[N].u_ro|net_chain~2|combout), so *ro_clk*
# matched nothing ("Ignored filter ... could not be matched with a net") and
# this exception never actually applied.
# set_false_path -from/-to only accept clock/reg/port/pin/cell endpoints, not
# raw nets ("Argument is a collection that is not of clk, kpr, reg, port,
# pin, cell or partition type") -- -through is the right form for a net
# sitting in the middle of a path rather than at an endpoint.
set_false_path -through [get_nets *net_chain*]