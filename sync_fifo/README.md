# Parameterized Synchronous FIFO

This project contains a **Parameterized Synchronous FIFO (First-In, First-Out)** buffer designed in Verilog, along with a comprehensive SystemVerilog testbench.

---

## Architecture & Features
* **Parameterized Design**: Easily configure `DATA_WIDTH`, buffer `DEPTH`, `ALMOST_FULL_VAL`, and `ALMOST_EMPTY_VAL` at instantiation.
* **Synchronous Operation**: Single clock (`clk`) domain for writes and reads.
* **Status Flags**:
  - `full`: Buffer is entirely full.
  - `empty`: Buffer is empty.
  - `almost_full`: Occupancy count $\ge$ `ALMOST_FULL_VAL`.
  - `almost_empty`: Occupancy count $\le$ `ALMOST_EMPTY_VAL` (and greater than 0).
* **Error Protection Flags**:
  - `overflow`: Triggers on write request while the FIFO is full.
  - `underflow`: Triggers on read request while the FIFO is empty.

---

## File Structure
* **[sync_fifo.v](sync_fifo.v)**: Main RTL implementation of the parameterized synchronous FIFO.
* **[testbench.sv](testbench.sv)**: SystemVerilog testbench verifying writing, reading, overflow, underflow, and flag behavior.
* **[fifo_explainer.html](fifo_explainer.html)** & **[fifo_architecture.html](fifo_architecture.html)**: Interactive visual explainers for the FIFO architecture.
* **[waveform.jpeg](waveform.jpeg)**: Saved simulation waveform screenshot.

---

## Port Interface

| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | Clock signal |
| `rst` | Input | 1 | Synchronous active-high reset |
| `wr_en` | Input | 1 | Write Enable |
| `rd_en` | Input | 1 | Read Enable |
| `wdata` | Input | `DATA_WIDTH` | Data to be written |
| `rdata` | Output | `DATA_WIDTH` | Data read from FIFO |
| `full` | Output | 1 | FIFO full flag |
| `empty` | Output | 1 | FIFO empty flag |
| `almost_full` | Output | 1 | Almost full flag |
| `almost_empty`| Output | 1 | Almost empty flag |
| `overflow` | Output | 1 | Write error flag |
| `underflow` | Output | 1 | Read error flag |

---

## Instantiation Example
```verilog
sync_fifo #(
    .DATA_WIDTH(16),
    .DEPTH(32),
    .ALMOST_FULL_VAL(28),
    .ALMOST_EMPTY_VAL(4)
) my_fifo (
    .clk(clk),
    .rst(rst),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .wdata(wdata),
    .rdata(rdata),
    .full(full),
    .empty(empty),
    .almost_full(almost_full),
    .almost_empty(almost_empty),
    .overflow(overflow),
    .underflow(underflow)
);
```
