// #################################################################################################
// # << NEORV32: neorv32_cpu.h - CPU Core Functions HW Driver >>                                   #
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
 * @file neorv32_cpu.h
 * @author Stephan Nolting
 * @brief CPU Core Functions HW driver header file.
 **************************************************************************/

#ifndef neorv32_cpu_h
#define neorv32_cpu_h

// prototypes
int neorv32_cpu_irq_enable(uint8_t irq_sel);
int neorv32_cpu_irq_disable(uint8_t irq_sel);
uint64_t neorv32_cpu_get_cycle(void);
void neorv32_cpu_set_mcycle(uint64_t value);
uint64_t neorv32_cpu_get_instret(void);
void neorv32_cpu_set_minstret(uint64_t value);
uint64_t neorv32_cpu_get_systime(void);
void neorv32_cpu_delay_ms(uint32_t time_ms);
void __attribute__((naked)) neorv32_cpu_goto_user_mode(void);
int neorv32_cpu_atomic_cas(uint32_t addr, uint32_t expected, uint32_t desired);


/**********************************************************************//**
 * Read data from CPU configuration and status register (CSR).
 *
 * @param[in] csr_id ID of CSR to read. See #NEORV32_CPU_CSRS_enum.
 * @return Read data (uint32_t).
 **************************************************************************/
inline uint32_t __attribute__ ((always_inline)) neorv32_cpu_csr_read(const int csr_id) {

  register uint32_t csr_data;

  asm volatile ("csrr %[result], %[input_i]" : [result] "=r" (csr_data) : [input_i] "i" (csr_id));
  
  return csr_data;
}


/**********************************************************************//**
 * Write data to CPU configuration and status register (CSR).
 *
 * @param[in] csr_id ID of CSR to write. See #NEORV32_CPU_CSRS_enum.
 * @param[in] data Data to write (uint32_t).
 **************************************************************************/
inline void __attribute__ ((always_inline)) neorv32_cpu_csr_write(const int csr_id, uint32_t data) {

  register uint32_t csr_data = data;

  asm volatile ("csrw %[input_i], %[input_j]" :  : [input_i] "i" (csr_id), [input_j] "r" (csr_data));
}


/**********************************************************************//**
 * Put CPU into "sleep" mode.
 *
 * @note This function executes the WFI insstruction.
 * The WFI (wait for interrupt) instruction will make the CPU stall until
 * an interupt request is detected. Interrupts have to be globally enabled
 * and at least one external source must be enabled (e.g., the CLIC or the machine
 * timer) to allow the CPU to wake up again. If 'Zicsr' CPU extension is disabled,
 * this will permanently stall the CPU.
 **************************************************************************/
inline void __attribute__ ((always_inline)) neorv32_cpu_sleep(void) {

  asm volatile ("wfi");
}


/**********************************************************************//**
 * Enable global CPU interrupts (via MIE flag in mstatus CSR).
 **************************************************************************/
inline void __attribute__ ((always_inline)) neorv32_cpu_eint(void) {

  asm volatile ("csrrsi zero, mstatus, %0" : : "i" (1 << CPU_MSTATUS_MIE));
}


/**********************************************************************//**
 * Disable global CPU interrupts (via MIE flag in mstatus CSR).
 **************************************************************************/
inline void __attribute__ ((always_inline)) neorv32_cpu_dint(void) {

  asm volatile ("csrrci zero, mstatus, %0" : : "i" (1 << CPU_MSTATUS_MIE));
}


/**********************************************************************//**
 * Trigger breakpoint exception (via EBREAK instruction).
 **************************************************************************/
inline void __attribute__ ((always_inline)) neorv32_cpu_breakpoint(void) {

  asm volatile ("ebreak");
}


/**********************************************************************//**
 * Trigger "environment call" exception (via ECALL instruction).
 **************************************************************************/
inline void __attribute__ ((always_inline)) neorv32_cpu_env_call(void) {

  asm volatile ("ecall");
}


#endif // neorv32_cpu_h
