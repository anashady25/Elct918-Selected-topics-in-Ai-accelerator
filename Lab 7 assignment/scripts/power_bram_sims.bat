@echo off
rem ---------------------------------------------------------------------------
rem power_bram_sims.bat -- Task 3, BRAM: one post-implementation functional
rem simulation per (operation, pattern) case, each recording a SAIF file.
rem Needs build/netlist/bram_top_funcsim.v (scripts/build_bram.tcl).
rem Run from the "Lab7 assignment" folder:   scripts\power_bram_sims.bat
rem Output: build/saif/bram_<op>_<pattern>.saif   (op = write/read)
rem ---------------------------------------------------------------------------
setlocal enabledelayedexpansion
if "%VIVADO_BIN%"=="" set VIVADO_BIN=D:\Xilinix\Vivado\2018.2\bin
set ROOT=%~dp0..
set RUN=%ROOT%\build\sim_power
if not exist "%RUN%" mkdir "%RUN%"
if not exist "%ROOT%\build\saif" mkdir "%ROOT%\build\saif"
pushd "%RUN%"

call "%VIVADO_BIN%\xvlog.bat" "%ROOT%\build\netlist\bram_top_funcsim.v" "%ROOT%\sim\tb_power.v" ^
     "%VIVADO_BIN%\..\data\verilog\src\glbl.v" || goto :fail
call "%VIVADO_BIN%\xelab.bat" tb_power glbl -s snap_power -L unisims_ver -L secureip -debug typical || goto :fail

for %%M in (1 2) do (
  if %%M==1 (set OP=write) else (set OP=read)
  for %%P in (1 2 3 4 5) do (
    if %%P==1 set PN=zeros
    if %%P==2 set PN=ones
    if %%P==3 set PN=alt01
    if %%P==4 set PN=5555aaaa
    if %%P==5 set PN=lfsr
    set CASE=bram_!OP!_!PN!
    echo ==== !CASE! ====
    > saif_!CASE!.tcl echo run 140us
    >>saif_!CASE!.tcl echo open_saif {../saif/!CASE!.saif}
    >>saif_!CASE!.tcl echo log_saif [get_objects -r /tb_power/dut/*]
    >>saif_!CASE!.tcl echo run 200us
    >>saif_!CASE!.tcl echo close_saif
    >>saif_!CASE!.tcl echo quit
    call "%VIVADO_BIN%\xsim.bat" snap_power -testplusarg "MODE=%%M" -testplusarg "PAT=%%P" ^
         -tclbatch saif_!CASE!.tcl -log sim_!CASE!.log || goto :fail
  )
)

popd
echo.
echo All SAIF files written to build\saif
exit /b 0

:fail
popd
echo POWER SIMULATION FLOW FAILED
exit /b 1
