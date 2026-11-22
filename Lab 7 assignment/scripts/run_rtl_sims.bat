@echo off
rem ---------------------------------------------------------------------------
rem run_rtl_sims.bat -- behavioural simulations of Task 2 with the Vivado
rem simulator (xsim). Run from the "Lab7 assignment" folder:
rem     scripts\run_rtl_sims.bat
rem Logs go to results\sim_tb_bram*.log and results\sim_tb_bram_top.log
rem Set VIVADO_BIN if Vivado is installed somewhere else.
rem ---------------------------------------------------------------------------
setlocal
if "%VIVADO_BIN%"=="" set VIVADO_BIN=D:\Xilinix\Vivado\2018.2\bin
set ROOT=%~dp0..
set RUN=%ROOT%\build\sim_rtl
if not exist "%RUN%" mkdir "%RUN%"
copy /Y "%ROOT%\mem\*.mem" "%RUN%" >nul
pushd "%RUN%"

call "%VIVADO_BIN%\xvlog.bat" "%ROOT%\rtl\bram.v" "%ROOT%\rtl\lfsr.v" "%ROOT%\rtl\ddr_ctrl.v" ^
     "%ROOT%\rtl\seg7_hex.v" "%ROOT%\rtl\board_status.v" "%ROOT%\rtl\bram_top.v" ^
     "%ROOT%\sim\tb_bram.v" "%ROOT%\sim\tb_bram_top.v" || goto :fail

rem 1) tb_bram, 4096 x 32 (the BRAM of the board design)
call "%VIVADO_BIN%\xelab.bat" tb_bram -s tb_bram_32 -debug typical || goto :fail
call "%VIVADO_BIN%\xsim.bat" tb_bram_32 -runall -log "%ROOT%\results\sim_tb_bram_32x4096.log" || goto :fail

rem 2) tb_bram, 4096 x 16 (the tutorial's BRAM_top size)
call "%VIVADO_BIN%\xelab.bat" tb_bram -s tb_bram_16 -generic_top "DATA_W=16" -generic_top "INIT_FILE=bram16_init.mem" || goto :fail
call "%VIVADO_BIN%\xsim.bat" tb_bram_16 -runall -log "%ROOT%\results\sim_tb_bram_16x4096.log" || goto :fail

rem 3) tb_bram_top: controller sweep of the BRAM, cycles and bandwidth
call "%VIVADO_BIN%\xelab.bat" tb_bram_top -s tb_bram_top || goto :fail
call "%VIVADO_BIN%\xsim.bat" tb_bram_top -runall -log "%ROOT%\results\sim_tb_bram_top.log" || goto :fail

popd
echo.
echo All simulations finished. See results\sim_*.log
exit /b 0

:fail
popd
echo SIMULATION FLOW FAILED
exit /b 1
