# Realtime Math Package
Math utilities for converting between clock cycles and real units of time.

## Types
### clock_t
natural, used to represent whole clock frequencies. This package also works if clock_t is defined as real.
### clock_minmax_t
Min/max range of clock_t returned by some functions.
### get_clock_divider_result_t
Separate integer and fractional part results returned from get_clock_divider.

## Functions
### clock_period(frequency : clock_t) return real
Returns the period in (real) seconds of a given frequency.
### clock_error_period_ui(frequency : clock_t; ui : real) return real
Returns a period as above, but with a variation specified in UI.
### clock_error_period_ps(frequency : clock_t; ps : real) return real
Returns a period as above, but with a variation specified in picoseconds.
### clock_minmax_frequency_ui(frequency : clock_t; ui : real) return clock_minmax_t
Returns a range of possible clock frequencies given a nominal frequency and variation in either direction specified in UI.
### clock_minmax_frequency_ps(frequency : clock_t; ps : real) return clock_minmax_t
Returns a range of possible clock frequencies given a nominal frequency and period variation in either direction specified in picoseconds.
### clock_divider(input_clock, desired_clock : clock_t) return get_clock_divider_result_t
Returns the integer and fractional parts of the divisor required to convert one frequency to another.
### clock_divider_int(input_clock, desired_clock : clock_t) return natural
Calls get_clock_divider and returns only the integer part
### clock_divider_error(input_clock, desired_clock : clock_t) return real
Calls get_clock_divider and returns the factor of error if division is performed using only the integer part.
### cycles_ui_to_no_more_than(frequency : clock_t; ui : real; realtime : real) return natural
Returns the number of cycles at a given frequency which will be closest to the specified (real) time in seconds, but will not be any greater under the worst case variation specified in UI.
### cycles_ui_to_no_less_than(frequency : clock_t; ui : real; realtime : real) return natural
Returns the number of cycles at a given frequency which will be closest to the specified (real) time in seconds, but will not be any lesser under the worst case variation specified in UI.
