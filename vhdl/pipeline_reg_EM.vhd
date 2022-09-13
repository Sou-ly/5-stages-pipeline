library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pipeline_reg_EM is
    port(
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        mux_1_in    : in  std_logic_vector(31 downto 0);
        sel_mem_in  : in  std_logic;
        rf_wren_in  : in  std_logic;
        mux_2_in    : in  std_logic_vector(4 downto 0);
        mux_1_out   : out std_logic_vector(31 downto 0);
        sel_mem_out : out std_logic;
        rf_wren_out : out std_logic;
        mux_2_out   : out std_logic_vector(4 downto 0)
    );
end pipeline_reg_EM;

architecture synth of pipeline_reg_EM is
begin

   registers: process(reset_n, clk)
   begin
    if (reset_n = '0') then
        mux_1_out <= (others => '0');
        sel_mem_out <= '0';
        rf_wren_out <= '0';
        mux_2_out <= (others => '0');
    elsif (rising_edge(clk)) then
        mux_1_out <= mux_1_in;
        sel_mem_out <= sel_mem_in;
        rf_wren_out <= rf_wren_in;
        mux_2_out <= mux_2_in;
    end if;
   end process;
	
end synth;
