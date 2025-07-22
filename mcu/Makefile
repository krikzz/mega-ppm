# *****************************************************************************
# USER CONFIGURATION
# *****************************************************************************
# User's application sources (*.c, *.cpp, *.s, *.S); add additional files here
APP_SRC ?= $(wildcard ./*.c) $(wildcard ./*.s) $(wildcard ./*.cpp) $(wildcard ./*.S)

# User's application include folders (don't forget the '-I' before each entry)
APP_INC ?= -I .
# User's application include folders - for assembly files only (don't forget the '-I' before each entry)
ASM_INC ?= -I .

# Optimization
EFFORT ?= -O2

# Compiler toolchain
RISCV_TOOLCHAIN ?= riscv64-unknown-elf

# CPU architecture and ABI
MARCH ?= -march=rv32im
MABI  ?= -mabi=ilp32

# User flags for additional configuration (will be added to compiler flags)
USER_FLAGS ?= -Wno-pointer-sign

# Relative or absolute path to the NEORV32 home folder
NEORV32_HOME = ../neorv32
LIBHME	     = lib
#E:/wspace/risc-v/neorv32
# *****************************************************************************

# -----------------------------------------------------------------------------
# NEORV32 framework
# -----------------------------------------------------------------------------
# Path to NEORV32 linker script and startup file
NEORV32_COM_PATH = $(LIBHME)/common
# Path to main NEORV32 library include files
NEORV32_INC_PATH = $(LIBHME)/include
# Path to main NEORV32 library source files
NEORV32_SRC_PATH = $(LIBHME)/source
# Path to NEORV32 executable generator
NEORV32_EXG_PATH = tools
# Marker file to check for NEORV32 home folder
NEORV32_HOME_MARKER = $(NEORV32_INC_PATH)/neorv32.h

# Core libraries (peripheral and CPU drivers)
CORE_SRC  = $(wildcard $(NEORV32_SRC_PATH)/*.c)
# Application start-up code
CORE_SRC += $(NEORV32_COM_PATH)/crt0.S

# Linker script
LD_SCRIPT = $(NEORV32_COM_PATH)/neorv32.ld

# Main output files
APP_EXE  = neorv32_exe.bin
APP_ASM  = main.asm
APP_IMG  = neorv32_application_image.vhd
BOOT_IMG = neorv32_bootloader_image.vhd


# -----------------------------------------------------------------------------
# Sources and objects
# -----------------------------------------------------------------------------
# Define all sources
SRC  = $(APP_SRC)
SRC += $(CORE_SRC)

# Define all object files
OBJ = $(SRC:%=%.o)


# -----------------------------------------------------------------------------
# Tools and flags
# -----------------------------------------------------------------------------
# Compiler tools
CC      = $(RISCV_TOOLCHAIN)-gcc
OBJDUMP = $(RISCV_TOOLCHAIN)-objdump
OBJCOPY = $(RISCV_TOOLCHAIN)-objcopy
SIZE    = $(RISCV_TOOLCHAIN)-size


# NEORV32 executable image generator
IMAGE_GEN = $(NEORV32_EXG_PATH)/image_gen

# Compiler & linker flags
CC_OPTS  = $(MARCH) $(MABI) $(EFFORT) -Wall -ffunction-sections -fdata-sections -nostartfiles
CC_OPTS += -Wl,--gc-sections -lm -lc -lgcc -lc
# This accelerates instruction fetch after branches when C extension is enabled (irrelevant when C extension is disabled)
CC_OPTS += -falign-functions=4 -falign-labels=4 -falign-loops=4 -falign-jumps=4
CC_OPTS += $(USER_FLAGS)


# -----------------------------------------------------------------------------
# Application output definitions
# -----------------------------------------------------------------------------
all:      $(APP_ASM) $(APP_EXE) clean 


# -----------------------------------------------------------------------------
# General targets: Assemble, compile, link, dump
# -----------------------------------------------------------------------------
# Compile app *.s sources (assembly)
%.s.o: %.s
	$(CC) -c $(CC_OPTS) -I $(NEORV32_INC_PATH) $(ASM_INC) $< -o $@

# Compile app *.S sources (assembly + C pre-processor)
%.S.o: %.S
	$(CC) -c $(CC_OPTS) -I $(NEORV32_INC_PATH) $(ASM_INC) $< -o $@

# Compile app *.c sources
%.c.o: %.c
	$(CC) -c $(CC_OPTS) -I $(NEORV32_INC_PATH) $(APP_INC) $< -o $@

# Compile app *.cpp sources
%.cpp.o: %.cpp
	$(CC) -c $(CC_OPTS) -I $(NEORV32_INC_PATH) $(APP_INC) $< -o $@

# Link object files and show memory utilization
main.elf: $(OBJ)
	$(CC) $(CC_OPTS) -T $(LD_SCRIPT) $(OBJ) -o $@
	@echo "Memory utilization:"
	@$(SIZE) main.elf

# Assembly listing file (for debugging)
$(APP_ASM): main.elf
	$(OBJDUMP) -d -S -z  $< > $@

# Generate final executable from .text + .rodata + .data (in THIS order!)
mcu.bin: main.elf $(APP_ASM)
	$(OBJCOPY) -I elf32-little $< -j .text   -O binary text.bin
	$(OBJCOPY) -I elf32-little $< -j .rodata -O binary rodata.bin
	$(OBJCOPY) -I elf32-little $< -j .data   -O binary data.bin
	cat text.bin rodata.bin data.bin -save=$@
	rm -f text.bin rodata.bin data.bin
	../tools/bin_to_verilog.exe wsize=4 make=mcu.bin
# -----------------------------------------------------------------------------
# Application targets: Generate binary executable, install (as VHDL file)
# -----------------------------------------------------------------------------
# Generate NEORV32 executable image for upload via bootloader
$(APP_EXE): mcu.bin
	set -e
#	$(IMAGE_GEN) -app_bin main.bin $@
	

# -----------------------------------------------------------------------------
# Clean up
# -----------------------------------------------------------------------------
clean:
	@rm -f *.elf *.o *.out *.asm *.vhd

clean_all: clean
	@rm -f $(OBJ) $(IMAGE_GEN)
