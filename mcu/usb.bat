@echo off
..\tools\megalink.exe -fpga ..\tools\00.rbf -memwr mcu.bin 0x1000000 -fpga ../fpga/output_files/mega-pro.rbf
copy mcu.txt ..\fpga\mcu.txt
