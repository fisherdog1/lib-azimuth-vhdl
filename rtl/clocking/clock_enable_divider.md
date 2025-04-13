# Clock Enable Divider
Provides modular counting for generating baud rates and other periodic signals.

## Ports
### clk
A source clock
### rst
A synchronous active-high reset. The device will not count while reset is asserted, and the clkdiv_en output will be deasserted.
### clkdiv_en
Divider output. High whenever the counter is at its maximum value and reset is deasserted.
### divider
Counter top value. The counter has a period equal to the value of divider. If changed while counting, the behavior depends on the generic CHANGE_DIVIDER_IMMEDIATELY. The value zero has unspecified behavior.
### counter
Present value of internal counter. Counts from one to the value of divider inclusive.

## Generic Parameters
### FIRST_CYCLE
When true, the counter starts at its top value out of reset, so that clkdiv_en is asserted during the first cycle.
### CHANGE_DIVIDER_IMMEDIATELY
When true, changes to the divider take effect after one clock cycle. Otherwise, they take effect at the end of the current count-up, I.e. after the next time clkdiv_en is asserted.
