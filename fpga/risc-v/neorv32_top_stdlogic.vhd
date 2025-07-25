-- #################################################################################################
-- # << NEORV32 - Processor Top Entity with Resolved Port Signals (std_logic/std_logic_vector) >>  #
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

entity neorv32_top_stdlogic is
  generic (
    -- General --
    CLOCK_FREQUENCY              : natural := 50000000;      -- clock frequency of clk_i in Hz
    BOOTLOADER_USE               : boolean := false;   -- implement processor-internal bootloader?
    USER_CODE                    : std_logic_vector(31 downto 0) := x"00000000"; -- custom user code
    HW_THREAD_ID                 : std_logic_vector(31 downto 0) := (others => '0'); -- hardware thread id (hartid)
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_A        : boolean := false;  -- implement atomic extension?
    CPU_EXTENSION_RISCV_C        : boolean := false;  -- implement compressed extension?
    CPU_EXTENSION_RISCV_E        : boolean := false;  -- implement embedded RF extension?
    CPU_EXTENSION_RISCV_M        : boolean := true;  -- implement muld/div extension?
    CPU_EXTENSION_RISCV_U        : boolean := false;  -- implement user mode extension?
    CPU_EXTENSION_RISCV_Zicsr    : boolean := true;   -- implement CSR system?
    CPU_EXTENSION_RISCV_Zifencei : boolean := false;  -- implement instruction stream sync.?
    -- Extension Options --
    FAST_MUL_EN                  : boolean := true; -- use DSPs for M extension's multiplier
    FAST_SHIFT_EN                : boolean := true; -- use barrel shifter for shift operations
    -- Physical Memory Protection (PMP) --
    PMP_USE                      : boolean := false; -- implement PMP?
    PMP_NUM_REGIONS              : natural := 4;     -- number of regions (max 8)
    PMP_GRANULARITY              : natural := 14;    -- minimal region granularity (1=8B, 2=16B, 3=32B, ...) default is 64k
    -- Internal Instruction memory --
    MEM_INT_IMEM_USE             : boolean := false;   -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE            : natural := 16*1024; -- size of processor-internal instruction memory in bytes
    MEM_INT_IMEM_ROM             : boolean := false;  -- implement processor-internal instruction memory as ROM
    -- Internal Data memory --
    MEM_INT_DMEM_USE             : boolean := false;   -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            : natural := 8*1024; -- size of processor-internal data memory in bytes
    -- External memory interface --
    MEM_EXT_USE                  : boolean := true;  -- implement external memory bus interface?
    -- Processor peripherals --
    IO_GPIO_USE                  : boolean := true;   -- implement general purpose input/output port unit (GPIO)?
    IO_MTIME_USE                 : boolean := true;   -- implement machine system timer (MTIME)?
    IO_UART_USE                  : boolean := true;   -- implement universal asynchronous receiver/transmitter (UART)?
    IO_SPI_USE                   : boolean := false;   -- implement serial peripheral interface (SPI)?
    IO_TWI_USE                   : boolean := false;  -- implement two-wire interface (TWI)?
    IO_PWM_USE                   : boolean := false;  -- implement pulse-width modulation unit (PWM)?
    IO_WDT_USE                   : boolean := true;   -- implement watch dog timer (WDT)?
    IO_TRNG_USE                  : boolean := false;  -- implement true random number generator (TRNG)?
    IO_CFU0_USE                  : boolean := false;  -- implement custom functions unit 0 (CFU0)?
    IO_CFU1_USE                  : boolean := false   -- implement custom functions unit 1 (CFU1)?
  );
  port (
    -- Global control --
    clk_i       : in  std_logic := '0'; -- global clock, rising edge
    rstn_i      : in  std_logic := '0'; -- global reset, low-active, async
    -- Wishbone bus interface (available if MEM_EXT_USE = true) --
    wb_tag_o    : out std_logic_vector(2 downto 0); -- tag
    wb_adr_o    : out std_logic_vector(31 downto 0); -- address
    wb_dat_i    : in  std_logic_vector(31 downto 0) := (others => '0'); -- read data
    wb_dat_o    : out std_logic_vector(31 downto 0); -- write data
    wb_we_o     : out std_logic; -- read/write
    wb_sel_o    : out std_logic_vector(03 downto 0); -- byte enable
    wb_stb_o    : out std_logic; -- strobe
    wb_cyc_o    : out std_logic; -- valid cycle
    wb_lock_o   : out std_logic; -- locked/exclusive bus access
    wb_ack_i    : in  std_logic := '0'; -- transfer acknowledge
    wb_err_i    : in  std_logic := '0'; -- transfer error
    -- Advanced memory control signals (available if MEM_EXT_USE = true) --
    fence_o     : out std_logic; -- indicates an executed FENCE operation
    fencei_o    : out std_logic; -- indicates an executed FENCEI operation
    -- GPIO (available if IO_GPIO_USE = true) --
    gpio_o      : out std_logic_vector(31 downto 0); -- parallel output
    gpio_i      : in  std_logic_vector(31 downto 0) := (others => '0'); -- parallel input
    -- UART (available if IO_UART_USE = true) --
    uart_txd_o  : out std_logic; -- UART send data
    uart_rxd_i  : in  std_logic := '0'; -- UART receive data
    -- SPI (available if IO_SPI_USE = true) --
    spi_sck_o   : out std_logic; -- SPI serial clock
    spi_sdo_o   : out std_logic; -- controller data out, peripheral data in
    spi_sdi_i   : in  std_logic := '0'; -- controller data in, peripheral data out
    spi_csn_o   : out std_logic_vector(07 downto 0); -- SPI CS
    -- TWI (available if IO_TWI_USE = true) --
    twi_sda_io  : inout std_logic; -- twi serial data line
    twi_scl_io  : inout std_logic; -- twi serial clock line
    -- PWM (available if IO_PWM_USE = true) --
    pwm_o       : out std_logic_vector(03 downto 0); -- pwm channels
    -- Interrupts --
    mtime_irq_i : in  std_logic := '0'; -- machine timer interrupt, available if IO_MTIME_USE = false
    msw_irq_i   : in  std_logic := '0'; -- machine software interrupt
    mext_irq_i  : in  std_logic := '0'  -- machine external interrupt
  );
end neorv32_top_stdlogic;

architecture neorv32_top_stdlogic_rtl of neorv32_top_stdlogic is

  -- type conversion --
  constant USER_CODE_INT    : std_ulogic_vector(31 downto 0) := std_ulogic_vector(USER_CODE);
  constant HW_THREAD_ID_INT : std_ulogic_vector(31 downto 0) := std_ulogic_vector(HW_THREAD_ID);
  --
  signal clk_i_int       : std_ulogic;
  signal rstn_i_int      : std_ulogic;
  --
  signal wb_tag_o_int    : std_ulogic_vector(2 downto 0);
  signal wb_adr_o_int    : std_ulogic_vector(31 downto 0);
  signal wb_dat_i_int    : std_ulogic_vector(31 downto 0);
  signal wb_dat_o_int    : std_ulogic_vector(31 downto 0);
  signal wb_we_o_int     : std_ulogic;
  signal wb_sel_o_int    : std_ulogic_vector(03 downto 0);
  signal wb_stb_o_int    : std_ulogic;
  signal wb_cyc_o_int    : std_ulogic;
  signal wb_lock_o_int   : std_ulogic;
  signal wb_ack_i_int    : std_ulogic;
  signal wb_err_i_int    : std_ulogic;
  --
  signal fence_o_int     : std_ulogic;
  signal fencei_o_int    : std_ulogic;
  --
  signal gpio_o_int      : std_ulogic_vector(31 downto 0);
  signal gpio_i_int      : std_ulogic_vector(31 downto 0);
  --
  signal uart_txd_o_int  : std_ulogic;
  signal uart_rxd_i_int  : std_ulogic;
  --
  signal spi_sck_o_int   : std_ulogic;
  signal spi_sdo_o_int   : std_ulogic;
  signal spi_sdi_i_int   : std_ulogic;
  signal spi_csn_o_int   : std_ulogic_vector(07 downto 0);
  --
  signal pwm_o_int       : std_ulogic_vector(03 downto 0);
  --
  signal mtime_irq_i_int : std_ulogic;
  signal msw_irq_i_int   : std_ulogic;
  signal mext_irq_i_int  : std_ulogic;

begin

  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => CLOCK_FREQUENCY,    -- clock frequency of clk_i in Hz
    BOOTLOADER_USE               => BOOTLOADER_USE,     -- implement processor-internal bootloader?
    USER_CODE                    => USER_CODE_INT,      -- custom user code
    HW_THREAD_ID                 => HW_THREAD_ID_INT,   -- hardware thread id (hartid)
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_A        => CPU_EXTENSION_RISCV_A,        -- implement atomic extension?
    CPU_EXTENSION_RISCV_C        => CPU_EXTENSION_RISCV_C,        -- implement compressed extension?
    CPU_EXTENSION_RISCV_E        => CPU_EXTENSION_RISCV_E,        -- implement embedded RF extension?
    CPU_EXTENSION_RISCV_M        => CPU_EXTENSION_RISCV_M,        -- implement muld/div extension?
    CPU_EXTENSION_RISCV_U        => CPU_EXTENSION_RISCV_U,        -- implement user mode extension?
    CPU_EXTENSION_RISCV_Zicsr    => CPU_EXTENSION_RISCV_Zicsr,    -- implement CSR system?
    CPU_EXTENSION_RISCV_Zifencei => CPU_EXTENSION_RISCV_Zifencei, -- implement instruction stream sync.?
    -- Extension Options --
    FAST_MUL_EN                  => FAST_MUL_EN,        -- use DSPs for M extension's multiplier
    FAST_SHIFT_EN                => FAST_SHIFT_EN,      -- use barrel shifter for shift operations
    -- Physical Memory Protection (PMP) --
    PMP_USE                      => PMP_USE,            -- implement PMP?
    PMP_NUM_REGIONS              => PMP_NUM_REGIONS,    -- number of regions (max 16)
    PMP_GRANULARITY              => PMP_GRANULARITY,    -- region granularity (1=8B, 2=16B, 3=32B, ...) default is 64k
    -- Internal Instruction memory --
    MEM_INT_IMEM_USE             => MEM_INT_IMEM_USE,   -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE            => MEM_INT_IMEM_SIZE,  -- size of processor-internal instruction memory in bytes
    MEM_INT_IMEM_ROM             => MEM_INT_IMEM_ROM,   -- implement processor-internal instruction memory as ROM
    -- Internal Data memory --
    MEM_INT_DMEM_USE             => MEM_INT_DMEM_USE,   -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            => MEM_INT_DMEM_SIZE,  -- size of processor-internal data memory in bytes
    -- External memory interface --
    MEM_EXT_USE                  => MEM_EXT_USE,        -- implement external memory bus interface?
    -- Processor peripherals --
    IO_GPIO_USE                  => IO_GPIO_USE,        -- implement general purpose input/output port unit (GPIO)?
    IO_MTIME_USE                 => IO_MTIME_USE,       -- implement machine system timer (MTIME)?
    IO_UART_USE                  => IO_UART_USE,        -- implement universal asynchronous receiver/transmitter (UART)?
    IO_SPI_USE                   => IO_SPI_USE,         -- implement serial peripheral interface (SPI)?
    IO_TWI_USE                   => IO_TWI_USE,         -- implement two-wire interface (TWI)?
    IO_PWM_USE                   => IO_PWM_USE,         -- implement pulse-width modulation unit (PWM)?
    IO_WDT_USE                   => IO_WDT_USE,         -- implement watch dog timer (WDT)?
    IO_TRNG_USE                  => IO_TRNG_USE,        -- implement true random number generator (TRNG)?
    IO_CFU0_USE                  => IO_CFU0_USE,        -- implement custom functions unit 0 (CFU0)?
    IO_CFU1_USE                  => IO_CFU1_USE         -- implement custom functions unit 1 (CFU1)?
  )
  port map (
    -- Global control --
    clk_i       => clk_i_int,       -- global clock, rising edge
    rstn_i      => rstn_i_int,      -- global reset, low-active, async
    -- Wishbone bus interface --
    wb_tag_o    => wb_tag_o_int,    -- tag
    wb_adr_o    => wb_adr_o_int,    -- address
    wb_dat_i    => wb_dat_i_int,    -- read data
    wb_dat_o    => wb_dat_o_int,    -- write data
    wb_we_o     => wb_we_o_int,     -- read/write
    wb_sel_o    => wb_sel_o_int,    -- byte enable
    wb_stb_o    => wb_stb_o_int,    -- strobe
    wb_cyc_o    => wb_cyc_o_int,    -- valid cycle
    wb_lock_o   => wb_lock_o_int,   -- locked/exclusive bus access
    wb_ack_i    => wb_ack_i_int,    -- transfer acknowledge
    wb_err_i    => wb_err_i_int,    -- transfer error
    -- Advanced memory control signals --
    fence_o     => fence_o_int,     -- indicates an executed FENCE operation
    fencei_o    => fencei_o_int,    -- indicates an executed FENCEI operation
    -- GPIO --
    gpio_o      => gpio_o_int,      -- parallel output
    gpio_i      => gpio_i_int,      -- parallel input
    -- UART --
    uart_txd_o  => uart_txd_o_int,  -- UART send data
    uart_rxd_i  => uart_rxd_i_int,  -- UART receive data
    -- SPI --
    spi_sck_o   => spi_sck_o_int,   -- SPI serial clock
    spi_sdo_o   => spi_sdo_o_int,   -- controller data out, peripheral data in
    spi_sdi_i   => spi_sdi_i_int,   -- controller data in, peripheral data out
    spi_csn_o   => spi_csn_o_int,   -- SPI CS
    -- TWI --
    twi_sda_io  => twi_sda_io,      -- twi serial data line
    twi_scl_io  => twi_scl_io,      -- twi serial clock line
    -- PWM --
    pwm_o       => pwm_o_int,       -- pwm channels
    -- Interrupts --
    mtime_irq_i => mtime_irq_i_int, -- machine timer interrupt, available if IO_MTIME_USE = false
    msw_irq_i   => msw_irq_i_int,   -- machine software interrupt
    mext_irq_i  => mext_irq_i_int   -- machine external interrupt
  );

  -- type conversion --
  clk_i_int      <= std_ulogic(clk_i);
  rstn_i_int     <= std_ulogic(rstn_i);

  wb_tag_o       <= std_logic_vector(wb_tag_o_int);
  wb_adr_o       <= std_logic_vector(wb_adr_o_int);
  wb_dat_i_int   <= std_ulogic_vector(wb_dat_i);
  wb_dat_o       <= std_logic_vector(wb_dat_o_int);
  wb_we_o        <= std_logic(wb_we_o_int);
  wb_sel_o       <= std_logic_vector(wb_sel_o_int);
  wb_stb_o       <= std_logic(wb_stb_o_int);
  wb_cyc_o       <= std_logic(wb_cyc_o_int);
  wb_lock_o      <= std_logic(wb_lock_o_int);
  wb_ack_i_int   <= std_ulogic(wb_ack_i);
  wb_err_i_int   <= std_ulogic(wb_err_i);

  fence_o        <= std_logic(fence_o_int);
  fencei_o       <= std_logic(fencei_o_int);

  gpio_o         <= std_logic_vector(gpio_o_int);
  gpio_i_int     <= std_ulogic_vector(gpio_i);

  uart_txd_o     <= std_logic(uart_txd_o_int);
  uart_rxd_i_int <= std_ulogic(uart_rxd_i);

  spi_sck_o      <= std_logic(spi_sck_o_int);
  spi_sdo_o      <= std_logic(spi_sdo_o_int);
  spi_sdi_i_int  <= std_ulogic(spi_sdi_i);
  spi_csn_o      <= std_logic_vector(spi_csn_o_int);

  pwm_o          <= std_logic_vector(pwm_o_int);

  msw_irq_i_int  <= std_ulogic(msw_irq_i);
  mext_irq_i_int <= std_ulogic(mext_irq_i);


end neorv32_top_stdlogic_rtl;
