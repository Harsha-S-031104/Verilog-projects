@echo off
echo ==============================================
echo  EDA Counter Simulation Runner
echo ==============================================
echo Choose a Simulator:
echo 1. Icarus Verilog (iverilog)
echo 2. ModelSim / QuestaSim (vlog/vsim)
echo ==============================================
set /p choice="Enter choice (1 or 2): "

if "%choice%"=="1" goto iverilog_sim
if "%choice%"=="2" goto modelsim_sim
echo Invalid choice. Exiting...
pause
exit

:iverilog_sim
echo.
echo Running Basic Counter Simulation with Icarus...
iverilog -g2012 -o counter_basic.vvp counter_basic.v counter_basic_tb.sv
if %errorlevel% neq 0 (
    echo Compilation failed!
    pause
    exit /b %errorlevel%
)
vvp counter_basic.vvp
echo.
echo Running s2c_counter Simulation with Icarus...
iverilog -g2012 -o s2c_counter.vvp s2c_counter.v s2c_counter_tb.sv
if %errorlevel% neq 0 (
    echo Compilation failed!
    pause
    exit /b %errorlevel%
)
vvp s2c_counter.vvp
echo.
echo Simulations complete! Generated VCD files: counter_basic.vcd, s2c_counter.vcd.
pause
exit /b 0

:modelsim_sim
echo.
echo Creating ModelSim library...
vlib work
echo.
echo Compiling Basic Counter with ModelSim...
vlog counter_basic.v counter_basic_tb.sv
if %errorlevel% neq 0 (
    echo Compilation failed!
    pause
    exit /b %errorlevel%
)
echo Running Basic Counter Simulation...
vsim -c -do "run -all; quit" top
echo.
echo Compiling s2c_counter with ModelSim...
vlog s2c_counter.v s2c_counter_tb.sv
if %errorlevel% neq 0 (
    echo Compilation failed!
    pause
    exit /b %errorlevel%
)
echo Running s2c_counter Simulation...
vsim -c -do "run -all; quit" top
echo.
echo Simulations complete!
pause
exit /b 0
