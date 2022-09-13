library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pipeline_reg_DE is
    port(
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        a_in          : in  std_logic_vector(31 downto 0);
        b_in          : in  std_logic_vector(31 downto 0);
        d_imm_in      : in  std_logic_vector(31 downto 0);
        sel_b_in      : in  std_logic;
        op_alu_in     : in  std_logic_vector(5 downto 0);
        read_in       : in  std_logic;
        write_in      : in  std_logic;
        sel_pc_in     : in  std_logic;
        branch_op_in  : in  std_logic;
        sel_mem_in    : in  std_logic;
        rf_wren_in    : in  std_logic;
        mux_in        : in  std_logic_vector(4 downto 0);
        next_addr_in  : in  std_logic_vector(15 downto 0);
        a_out         : out std_logic_vector(31 downto 0);
        b_out         : out std_logic_vector(31 downto 0);
        d_imm_out     : out std_logic_vector(31 downto 0);
        sel_b_out     : out std_logic;
        op_alu_out    : out std_logic_vector(5 downto 0);
        read_out      : out std_logic;
        write_out     : out std_logic;
        sel_pc_out    : out std_logic;
        branch_op_out : out std_logic;
        sel_mem_out   : out std_logic;
        rf_wren_out   : out std_logic;
        mux_out       : out std_logic_vector(4 downto 0);
        next_addr_out : out std_logic_vector(15 downto 0)
    );
end pipeline_reg_DE;

architecture synth of pipeline_reg_DE is
   
begin


end synth;
