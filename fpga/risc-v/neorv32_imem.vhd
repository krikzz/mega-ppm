-- #################################################################################################
-- # << NEORV32 - Processor-internal instruction memory (IMEM) >>                                  #
-- # ********************************************************************************************* #
-- # This memory includes the in-place executable image of the application. See the                #
-- # processor's documentary to get more information.                                              #
-- # Note: IMEM is split up into four 8-bit memories - some EDA tools have problems to synthesize  #
-- # a pre-initialized 32-bit memory with byte-enable signals.                                     #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2020, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;
use neorv32.neorv32_application_image.all; -- this file is generated by the image generator

entity neorv32_imem is
  generic (
    IMEM_BASE      : std_ulogic_vector(31 downto 0) := x"00000000"; -- memory base address
    IMEM_SIZE      : natural := 4*1024; -- processor-internal instruction memory size in bytes
    IMEM_AS_ROM    : boolean := false;  -- implement IMEM as read-only memory?
    BOOTLOADER_USE : boolean := true    -- implement and use bootloader?
  );
  port (
    clk_i  : in  std_ulogic; -- global clock line
    rden_i : in  std_ulogic; -- read enable
    wren_i : in  std_ulogic; -- write enable
    ben_i  : in  std_ulogic_vector(03 downto 0); -- byte write enable
    addr_i : in  std_ulogic_vector(31 downto 0); -- address
    data_i : in  std_ulogic_vector(31 downto 0); -- data in
    data_o : out std_ulogic_vector(31 downto 0); -- data out
    ack_o  : out std_ulogic  -- transfer acknowledge
  );
end neorv32_imem;

architecture neorv32_imem_rtl of neorv32_imem is

  -- IO space: module base address --
  constant hi_abb_c : natural := 31; -- high address boundary bit
  constant lo_abb_c : natural := index_size_f(IMEM_SIZE); -- low address boundary bit

  -- ROM types --
  type imem_file8_t is array (0 to IMEM_SIZE/4-1) of std_ulogic_vector(07 downto 0);

  -- init function and split 1x32-bit memory into 4x8-bit memories --
  -- impure function: returns NOT the same result every time it is evaluated with the same arguments since the source file might have changed
  impure function init_imem(byte : natural; init : application_init_image_t) return imem_file8_t is
    variable mem_v : imem_file8_t;
  begin
    mem_v := (others => (others => '0'));
    for i in 0 to init'length-1 loop -- init only in range of source data array
        mem_v(i) := init(i)(byte*8+7 downto byte*8+0);
    end loop; -- i
    return mem_v;
  end function init_imem;

  -- local signals --
  signal acc_en : std_ulogic;
  signal rdata  : std_ulogic_vector(31 downto 0);
  signal rden   : std_ulogic;
  signal addr   : std_ulogic_vector(index_size_f(IMEM_SIZE/4)-1 downto 0);

  -- The memory is built from 4x byte-wide memories defined as unique signals, since many synthesis tools
  -- have problems with 32-bit memories with byte-enable signals or with multi-dimensional arrays.

  -- internal "RAM" type - implemented if bootloader is used and IMEM is RAM and initialized with app code --
  signal imem_file_init_ram_ll : imem_file8_t := init_imem(0, application_init_image);
  signal imem_file_init_ram_lh : imem_file8_t := init_imem(1, application_init_image);
  signal imem_file_init_ram_hl : imem_file8_t := init_imem(2, application_init_image);
  signal imem_file_init_ram_hh : imem_file8_t := init_imem(3, application_init_image);

  -- internal "ROM" type - implemented if bootloader is NOT used; always initialize with app code --
  constant imem_file_rom_ll : imem_file8_t := init_imem(0, application_init_image);
  constant imem_file_rom_lh : imem_file8_t := init_imem(1, application_init_image);
  constant imem_file_rom_hl : imem_file8_t := init_imem(2, application_init_image);
  constant imem_file_rom_hh : imem_file8_t := init_imem(3, application_init_image);

  -- internal "RAM" type - implemented if bootloader is used and IMEM is RAM --
  signal imem_file_ram_ll : imem_file8_t;
  signal imem_file_ram_lh : imem_file8_t;
  signal imem_file_ram_hl : imem_file8_t;
  signal imem_file_ram_hh : imem_file8_t;


  -- -------------------------------------------------------------------------------- --
  -- attributes - these are *NOT mandatory*; just for footprint / timing optimization --
  -- -------------------------------------------------------------------------------- --

  -- lattice radiant --
  attribute syn_ramstyle : string;
  attribute syn_ramstyle of imem_file_ram_ll : signal is "no_rw_check";
  attribute syn_ramstyle of imem_file_ram_lh : signal is "no_rw_check";
  attribute syn_ramstyle of imem_file_ram_hl : signal is "no_rw_check";
  attribute syn_ramstyle of imem_file_ram_hh : signal is "no_rw_check";
  attribute syn_ramstyle of imem_file_init_ram_ll : signal is "no_rw_check";
  attribute syn_ramstyle of imem_file_init_ram_lh : signal is "no_rw_check";
  attribute syn_ramstyle of imem_file_init_ram_hl : signal is "no_rw_check";
  attribute syn_ramstyle of imem_file_init_ram_hh : signal is "no_rw_check";

  -- intel quartus prime --
  attribute ramstyle : string;
  attribute ramstyle of imem_file_ram_ll : signal is "no_rw_check";
  attribute ramstyle of imem_file_ram_lh : signal is "no_rw_check";
  attribute ramstyle of imem_file_ram_hl : signal is "no_rw_check";
  attribute ramstyle of imem_file_ram_hh : signal is "no_rw_check";
  attribute ramstyle of imem_file_init_ram_ll : signal is "no_rw_check";
  attribute ramstyle of imem_file_init_ram_lh : signal is "no_rw_check";
  attribute ramstyle of imem_file_init_ram_hl : signal is "no_rw_check";
  attribute ramstyle of imem_file_init_ram_hh : signal is "no_rw_check";

begin

  -- Access Control -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  acc_en <= '1' when (addr_i(hi_abb_c downto lo_abb_c) = IMEM_BASE(hi_abb_c downto lo_abb_c)) else '0';
  addr   <= addr_i(index_size_f(IMEM_SIZE/4)+1 downto 2); -- word aligned


  -- Memory Access --------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  imem_file_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      rden <= acc_en and rden_i;
      if (IMEM_AS_ROM = true) then
        ack_o <= acc_en and rden_i;
      else
        ack_o <= acc_en and (rden_i or wren_i);
      end if;
      if (acc_en = '1') then -- reduce switching activity when not accessed
        if (IMEM_AS_ROM = true) then -- implement IMEM as true ROM (initialized of course)
          rdata(07 downto 00) <= imem_file_rom_ll(to_integer(unsigned(addr)));
          rdata(15 downto 08) <= imem_file_rom_lh(to_integer(unsigned(addr)));
          rdata(23 downto 16) <= imem_file_rom_hl(to_integer(unsigned(addr)));
          rdata(31 downto 24) <= imem_file_rom_hh(to_integer(unsigned(addr)));

        elsif (BOOTLOADER_USE = true) then -- implement IMEM as non-initialized RAM
          if (wren_i = '1') then
            if (ben_i(0) = '1') then
              imem_file_ram_ll(to_integer(unsigned(addr))) <= data_i(07 downto 00);
            end if;
            if (ben_i(1) = '1') then
              imem_file_ram_lh(to_integer(unsigned(addr))) <= data_i(15 downto 08);
            end if;
            if (ben_i(2) = '1') then
              imem_file_ram_hl(to_integer(unsigned(addr))) <= data_i(23 downto 16);
            end if;
            if (ben_i(3) = '1') then
              imem_file_ram_hh(to_integer(unsigned(addr))) <= data_i(31 downto 24);
            end if;
          end if;
          rdata(07 downto 00) <= imem_file_ram_ll(to_integer(unsigned(addr)));
          rdata(15 downto 08) <= imem_file_ram_lh(to_integer(unsigned(addr)));
          rdata(23 downto 16) <= imem_file_ram_hl(to_integer(unsigned(addr)));
          rdata(31 downto 24) <= imem_file_ram_hh(to_integer(unsigned(addr)));

        else -- implement IMEM as PRE-INITIALIZED RAM
          if (wren_i = '1') then
            if (ben_i(0) = '1') then
              imem_file_init_ram_ll(to_integer(unsigned(addr))) <= data_i(07 downto 00);
            end if;
            if (ben_i(1) = '1') then
              imem_file_init_ram_lh(to_integer(unsigned(addr))) <= data_i(15 downto 08);
            end if;
            if (ben_i(2) = '1') then
              imem_file_init_ram_hl(to_integer(unsigned(addr))) <= data_i(23 downto 16);
            end if;
            if (ben_i(3) = '1') then
              imem_file_init_ram_hh(to_integer(unsigned(addr))) <= data_i(31 downto 24);
            end if;
          end if;
          rdata(07 downto 00) <= imem_file_init_ram_ll(to_integer(unsigned(addr)));
          rdata(15 downto 08) <= imem_file_init_ram_lh(to_integer(unsigned(addr)));
          rdata(23 downto 16) <= imem_file_init_ram_hl(to_integer(unsigned(addr)));
          rdata(31 downto 24) <= imem_file_init_ram_hh(to_integer(unsigned(addr)));
        end if;
      end if;
    end if;
  end process imem_file_access;

  -- output gate --
  data_o <= rdata when (rden = '1') else (others => '0');


end neorv32_imem_rtl;
