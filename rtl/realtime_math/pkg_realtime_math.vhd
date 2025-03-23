library ieee;
	use ieee.math_real.all;

package realtime_math is
	subtype clock_t is natural;

	type get_clock_divider_result_t is record
		divider_int : natural;
		divider_fract : real;
	end record;

	type clock_minmax_t is record
		min_hz : clock_t;
		max_hz : clock_t;
	end record;

	--Clock math
	function clock_period(frequency : clock_t) return real;
	function clock_error_period_ui(frequency : clock_t; ui : real) return real;
	function clock_error_period_ps(frequency : clock_t; ps : real) return real;
	function clock_minmax_frequency_ui(frequency : clock_t; ui : real) return clock_minmax_t;
	function clock_minmax_frequency_ps(frequency : clock_t; ps : real) return clock_minmax_t;

	--Clock division helpers
	function get_clock_divider(input_clock, desired_clock : clock_t) return get_clock_divider_result_t;
	function get_clock_divider_int(input_clock, desired_clock : clock_t) return natural;
	function get_clock_divider_error(input_clock, desired_clock : clock_t) return real;
	--TODO: Fractional dividers

	--Worst-case time helpers
	function cycles_ui_to_no_more_than(frequency : clock_t; ui : real; realtime : real) return natural;
	function cycles_ui_to_no_less_than(frequency : clock_t; ui : real; realtime : real) return natural;

end package;

package body realtime_math is
	--Get clock period from frequency
	function clock_period(frequency : clock_t) return real is
	begin
		return 1.0 / real(frequency);
	end function;

	--Get period with +/- UI error
	function clock_error_period_ui(frequency : clock_t; ui : real) return real is
	begin
		return clock_period(frequency) * (1.0 + ui);
	end function;

	--Get period with +/- picosecond error
	function clock_error_period_ps(frequency : clock_t; ps : real) return real is
	begin
		return clock_period(frequency) + (ps / 1.0e12);
	end function;

	--Get min/max uncertain frequency given nominal frequency and UI error
	function clock_minmax_frequency_ui(frequency : clock_t; ui : real) return clock_minmax_t is
	begin
		return clock_minmax_t'(
			min_hz => clock_t(1.0 / clock_error_period_ui(frequency, abs(ui))),
			max_hz => clock_t(1.0 / clock_error_period_ui(frequency, -abs(ui))));
	end function;

	--Get min/max uncertain frequency given nominal frequency and picosecond error
	function clock_minmax_frequency_ps(frequency : clock_t; ps : real) return clock_minmax_t is
	begin
		return clock_minmax_t'(
			min_hz => clock_t(1.0 / clock_error_period_ps(frequency, abs(ps))),
			max_hz => clock_t(1.0 / clock_error_period_ps(frequency, -abs(ps))));
	end function;

	--Get nearest clock divider and remainder from input and desired output clocks
	function get_clock_divider(input_clock, desired_clock : clock_t) return get_clock_divider_result_t is
		variable input_real, desired_real, real_divider, divider_fract : real;
		variable divider_int : natural;
	begin
		input_real := real(input_clock);
		desired_real := real(desired_clock);

		real_divider := input_real / desired_real;

		divider_fract := real_divider - round(real_divider);
		divider_int := natural(real_divider - divider_fract);

		return get_clock_divider_result_t'(
			divider_int => divider_int, 
			divider_fract => divider_fract);
	end function;

	--Get integer part of nearest clock divider value
	function get_clock_divider_int(input_clock, desired_clock : clock_t) return natural is
		variable result : get_clock_divider_result_t;
	begin
		result := get_clock_divider(input_clock, desired_clock);

		report "Clock divider error " & clock_t'image(input_clock) & " -> " & clock_t'image(desired_clock) & " : " & 
			real'image(get_clock_divider_error(input_clock, desired_clock) * 100.0) & "%" severity note;

		return result.divider_int;
	end function;

	--Get error of nearest integer clock divider
	function get_clock_divider_error(input_clock, desired_clock : clock_t) return real is
		variable result : get_clock_divider_result_t;
		variable actual_clock : real;
	begin
		result := get_clock_divider(input_clock, desired_clock);

		actual_clock := real(input_clock) / real(result.divider_int);

		return abs((actual_clock - real(desired_clock)) / actual_clock);
	end function;

	--Get number of clock cycles that takes no more than specified time under worst case uncertainty in UI
	function cycles_ui_to_no_more_than(frequency : clock_t; ui : real; realtime : real) return natural is
		variable max_per : real;
	begin
		max_per := clock_period(clock_minmax_frequency_ui(frequency, ui).min_hz);

		return natural(floor(realtime / max_per));
	end function;

	--Get number of clock cycles that takes no less than specified time under worst case uncertainty in UI
	function cycles_ui_to_no_less_than(frequency : clock_t; ui : real; realtime : real) return natural is
		variable min_per : real;
	begin
		min_per := clock_period(clock_minmax_frequency_ui(frequency, ui).max_hz);

		return natural(ceil(realtime / min_per));
	end function;
end package body;
