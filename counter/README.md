# Counter Designs in Verilog

This folder contains two distinct Verilog counter designs along with their SystemVerilog testbenches, simulation scripts, and visual explainers.

---

## 1. Basic 4-Bit Up/Down Counter (`counter_basic.v`)
A simple 4-bit synchronous counter with support for loading values and counting in both directions.

### Port Interface
* `clk`: Clock input (posedge active)
* `reset`: Synchronous active-high reset (sets count to `4'b0000`)
* `up_down`: Direction control (`1` = Count Up, `0` = Count Down)
* `load`: Active-high load enable
* `data`: 4-bit data input to load
* `count` [reg]: 4-bit output count register

---

## 2. Low-Power 32-Bit Counter (`s2c_counter.v`)
A spec-compliant, low-power-aware 32-bit counter designed to manage clock requests and power handshakes, counting up to a configurable maximum value before asserting an overflow interrupt.

### Features
* **Power Handshake**: Requests power with `power_req` and requires `power_in` before operation.
* **Clock Handshake**: Asks for clock request `clock_req` once `power_in` is verified.
* **Configurable Max Count**: Counts up to `max_counter` (if non-zero) or defaults to `MAX_DAYS` in seconds (`DEFAULT_MAX`).
* **Interrupt Flag**: Asserts `overflow_int` for one clock cycle when the count reaches the maximum limit, resetting back to zero on the next cycle.

### Port Interface
* `enable`: Inputs enable request (mapped to `power_req`)
* `clock`: Active edge clock
* `reset`: Asynchronous active-high reset
* `power_in`: Input power active confirmation (enables `clock_req`)
* `max_counter`: User-defined limit (32-bit)
* `clock_req`: Output clock request line
* `power_req`: Output power request line
* `count` [reg]: Current count output (32-bit)
* `overflow_int` [reg]: Overflow interrupt output active for 1 cycle

---

## Folder Structure
* **[counter_basic.v](counter_basic.v)**: 4-bit Up/Down RTL source.
* **[counter_basic_tb.sv](counter_basic_tb.sv)**: Testbench for the 4-bit counter.
* **[s2c_counter.v](s2c_counter.v)**: 32-bit low-power counter RTL source.
* **[s2c_counter_tb.sv](s2c_counter_tb.sv)**: Testbench for the 32-bit low-power counter.
* **[counter_visual_explainer.html](counter_visual_explainer.html)**: Interactive visual tool explaining counter logic.
* **[run_sim.bat](run_sim.bat)**: Batch script to run simulations using ModelSim.
