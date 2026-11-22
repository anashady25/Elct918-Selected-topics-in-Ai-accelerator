@echo off
rem Builds the DDR2 design (Task 1) and runs its power analysis (Task 3).
rem Double-click this file from Windows Explorer; the MIG generator does not
rem cope with spaces in the path, so the folder is mapped to a free drive letter.
setlocal
set VIVADO=D:\Xilinix\Vivado\2018.2\bin\vivado.bat
set LAB=%~dp0..
if not exist L:\scripts\build_ddr.tcl subst L: "%LAB%"
cd /d L:\
if not exist build mkdir build
call "%VIVADO%" -mode batch -nojournal -log build\build_ddr.log -source scripts\build_ddr.tcl
if errorlevel 1 goto :fail
call "%VIVADO%" -mode batch -nojournal -log build\power_ddr.log -source scripts\power_ddr.tcl -tclargs 15 30
if errorlevel 1 goto :fail
python scripts\collect_results.py
echo DDR2 build and power analysis finished.
goto :end
:fail
echo FAILED - see build\build_ddr.log / build\power_ddr.log
:end
pause
