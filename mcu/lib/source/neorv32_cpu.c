// #################################################################################################
// # << NEORV32: neorv32_cpu.c - CPU Core Functions HW Driver >>                                   #
// # ********************************************************************************************* #
// # BSD 3-Clause License                                                                          #
// #                                                                                               #
// # Copyright (c) 2020, Stephan Nolting. All rights reserved.                                     #
// #                                                                                               #
// # Redistribution and use in source and binary forms, with or without modification, are          #
// # permitted provided that the following conditions are met:                                     #
// #                                                                                               #
// # 1. Redistributions of source code must retain the above copyright notice, this list of        #
// #    conditions and the following disclaimer.                                                   #
// #                                                                                               #
// # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
// #    conditions and the following disclaimer in the documentation and/or other materials        #
// #    provided with the distribution.                                                            #
// #                                                                                               #
// # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
// #    endorse or promote products derived from this software without specific prior written      #
// #    permission.                                                                                #
// #                                                                                               #
// # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
// # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
// # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
// # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
// # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
// # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
// # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
// # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
// # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
// # ********************************************************************************************* #
// # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
// #################################################################################################


/**********************************************************************//**
 * @file neorv32_cpu.c
 * @author Stephan Nolting
 * @brief CPU Core Functions HW driver source file.
 **************************************************************************/

#include "neorv32.h"
#include "neorv32_cpu.h"


/**********************************************************************//**
 * Enable specific CPU interrupt.
 *
 * @note Interrupts have to be globally enabled via neorv32_cpu_eint(void), too.
 *
 * @param[in] irq_sel CPU interrupt select. See #NEORV32_CPU_MIE_enum.
 * @return 0 if success, 1 if error (invalid irq_sel).
 **************************************************************************/
int neorv32_cpu_irq_enable(uint8_t irq_sel) {

  if ((irq_sel != CPU_MIE_MSIE) && (irq_sel != CPU_MIE_MTIE) && (irq_sel != CPU_MIE_MEIE) &&
      (irq_sel != CPU_MIE_FIRQ0E) && (irq_sel != CPU_MIE_FIRQ1E) && (irq_sel != CPU_MIE_FIRQ2E) && (irq_sel != CPU_MIE_FIRQ3E)) {
    return 1;
  }

  register uint32_t mask = (uint32_t)(1 << irq_sel);
  asm volatile ("csrrs zero, mie, %0" : : "r" (mask));
  return 0;
}


/**********************************************************************//**
 * Disable specific CPU interrupt.
 *
 * @param[in] irq_sel CPU interrupt select. See #NEORV32_CPU_MIE_enum.
 * @return 0 if success, 1 if error (invalid irq_sel).
 **************************************************************************/
int neorv32_cpu_irq_disable(uint8_t irq_sel) {

  if ((irq_sel != CPU_MIE_MSIE) && (irq_sel != CPU_MIE_MTIE) && (irq_sel != CPU_MIE_MEIE) &&
      (irq_sel != CPU_MIE_FIRQ0E) && (irq_sel != CPU_MIE_FIRQ1E) && (irq_sel != CPU_MIE_FIRQ2E) && (irq_sel != CPU_MIE_FIRQ3E)) {
    return 1;
  }

  register uint32_t mask = (uint32_t)(1 << irq_sel);
  asm volatile ("csrrc zero, mie, %0" : : "r" (mask));
  return 0;
}


/**********************************************************************//**
 * Get cycle count from cycle[h].
 *
 * @note The cycle[h] CSR is shadowed copy of the mcycle[h] CSR.
 *
 * @return Current cycle counter (64 bit).
 **************************************************************************/
uint64_t neorv32_cpu_get_cycle(void) {

  union {
    uint64_t uint64;
    uint32_t uint32[sizeof(uint64_t)/2];
  } cycles;

  uint32_t tmp1, tmp2, tmp3;
  while(1) {
    tmp1 = neorv32_cpu_csr_read(CSR_CYCLEH);
    tmp2 = neorv32_cpu_csr_read(CSR_CYCLE);
    tmp3 = neorv32_cpu_csr_read(CSR_CYCLEH);
    if (tmp1 == tmp3) {
      break;
    }
  }

  cycles.uint32[0] = tmp2;
  cycles.uint32[1] = tmp3;

  return cycles.uint64;
}


/**********************************************************************//**
 * Set mcycle[h] counter.
 *
 * @param[in] value New value for mcycle[h] CSR (64-bit).
 **************************************************************************/
void neorv32_cpu_set_mcycle(uint64_t value) {

  union {
    uint64_t uint64;
    uint32_t uint32[sizeof(uint64_t)/2];
  } cycles;

  cycles.uint64 = value;

  neorv32_cpu_csr_write(CSR_MCYCLE,  0);
  neorv32_cpu_csr_write(CSR_MCYCLEH, cycles.uint32[1]);
  neorv32_cpu_csr_write(CSR_MCYCLE,  cycles.uint32[0]);
}


/**********************************************************************//**
 * Get retired instructions counter from instret[h].
 *
 * @note The instret[h] CSR is shadowed copy of the instret[h] CSR.
 *
 * @return Current instructions counter (64 bit).
 **************************************************************************/
uint64_t neorv32_cpu_get_instret(void) {

  union {
    uint64_t uint64;
    uint32_t uint32[sizeof(uint64_t)/2];
  } cycles;

  uint32_t tmp1, tmp2, tmp3;
  while(1) {
    tmp1 = neorv32_cpu_csr_read(CSR_INSTRETH);
    tmp2 = neorv32_cpu_csr_read(CSR_INSTRET);
    tmp3 = neorv32_cpu_csr_read(CSR_INSTRETH);
    if (tmp1 == tmp3) {
      break;
    }
  }

  cycles.uint32[0] = tmp2;
  cycles.uint32[1] = tmp3;

  return cycles.uint64;
}


/**********************************************************************//**
 * Set retired instructions counter minstret[h].
 *
 * @param[in] value New value for mcycle[h] CSR (64-bit).
 **************************************************************************/
void neorv32_cpu_set_minstret(uint64_t value) {

  union {
    uint64_t uint64;
    uint32_t uint32[sizeof(uint64_t)/2];
  } cycles;

  cycles.uint64 = value;

  neorv32_cpu_csr_write(CSR_MINSTRET,  0);
  neorv32_cpu_csr_write(CSR_MINSTRETH, cycles.uint32[1]);
  neorv32_cpu_csr_write(CSR_MINSTRET,  cycles.uint32[0]);
}


/**********************************************************************//**
 * Get current system time from time[h] CSR.
 *
 * @note This function requires the MTIME system timer to be implemented.
 *
 * @return Current system time (64 bit).
 **************************************************************************/
uint64_t neorv32_cpu_get_systime(void) {

  union {
    uint64_t uint64;
    uint32_t uint32[sizeof(uint64_t)/2];
  } cycles;

  uint32_t tmp1, tmp2, tmp3;
  while(1) {
    tmp1 = neorv32_cpu_csr_read(CSR_TIMEH);
    tmp2 = neorv32_cpu_csr_read(CSR_TIME);
    tmp3 = neorv32_cpu_csr_read(CSR_TIMEH);
    if (tmp1 == tmp3) {
      break;
    }
  }

  cycles.uint32[0] = tmp2;
  cycles.uint32[1] = tmp3;

  return cycles.uint64;
}


/**********************************************************************//**
 * Simple delay function using busy wait.
 *
 * @warning This function requires the cycle CSR(s). Hence, the Zicsr extension is mandatory.
 *
 * @param[in] time_ms Time in ms to wait.
 **************************************************************************/
void neorv32_cpu_delay_ms(uint32_t time_ms) {

  uint64_t time_resume = neorv32_cpu_get_cycle();

  uint32_t clock = SYSINFO_CLK; // clock ticks per second
  clock = clock / 1000; // clock ticks per ms

  uint64_t wait_cycles = ((uint64_t)clock) * ((uint64_t)time_ms);
  time_resume += wait_cycles;

  while(1) {
    if (neorv32_cpu_get_cycle() >= time_resume) {
      break;
    }
  }
}


/**********************************************************************//**
 * Switch from privilege mode MACHINE to privilege mode USER.
 *
 * @warning This function requires the U extension to be implemented.
 **************************************************************************/
void __attribute__((naked)) neorv32_cpu_goto_user_mode(void) {

  // make sure to use NO registers in here! -> naked

  asm volatile ("csrw mepc, ra           \n\t" // move return address to mepc so we can return using "mret". also, we can now use ra as general purpose register in here
                "li ra, %[input_imm]     \n\t" // bit mask to clear the two MPP bits
                "csrrc zero, mstatus, ra \n\t" // clear MPP bits -> MPP=u-mode
                "mret                    \n\t" // return and switch to user mode
                :  : [input_imm] "i" ((1<<CPU_MSTATUS_MPP_H) | (1<<CPU_MSTATUS_MPP_L)));
}


/**********************************************************************//**
 * Atomic compare-and-swap operation (for implemeneting semaphores and mutexes).
 *
 * @warning This function requires the A (atomic) CPU extension.
 *
 * @param[in] addr Address of memory location.
 * @param[in] expected Expected value (for comparison).
 * @param[in] desired Desired value (new value).
 * @return Returns 0 on success, 1 on failure.
 **************************************************************************/
int __attribute__ ((noinline)) neorv32_cpu_atomic_cas(uint32_t addr, uint32_t expected, uint32_t desired) {
#ifdef __riscv_atomic

  register uint32_t addr_reg = addr;
  register uint32_t des_reg = desired;
  register uint32_t tmp_reg;

  // load original value + reservation (lock)
  asm volatile ("lr.w %[result], (%[input])" : [result] "=r" (tmp_reg) : [input] "r" (addr_reg));

  if (tmp_reg != expected) {
    asm volatile ("lw x0, 0(%[input])" : : [input] "r" (addr_reg)); // clear reservation lock
    return 1;
  }

  // store-conditional
  asm volatile ("sc.w %[result], %[input_i], (%[input_j])" : [result] "=r" (tmp_reg) : [input_i] "r" (des_reg), [input_j] "r" (addr_reg));

  if (tmp_reg) {
    return 1;
  }

  return 0;
#else
  return 1; // A extension not implemented -Y always fail
#endif
}
