# Digital Stopwatch Controller (Hardware-Software Co-Design)

## Student Information
**Name:** Abhinav Yadaram
**ID:** 2023B5A30999G

## Project Overview
This project implements a Digital Stopwatch Controller using a hardware-software co-design approach. The timekeeping logic is implemented in Verilog (RTL), and the control/observation logic is implemented in C++ using Verilator.

## Directory Structure
* `rtl/`: Contains all Verilog source files (`stopwatch_top.v`, `control_fsm.v`, etc.).
* `tb/`: Contains the Verilog testbench (`tb_stopwatch.v`) for Vivado simulation.
* `verilator_sw/`: Contains the C++ source code (`main.cpp`) and `Makefile` for Verilator simulation.

## Tool Versions Used
* **Operating System:** Ubuntu 22.04 via WSL
* **Verilator Version:** 4.038
* **Compiler:** 11.4.0
* **Make:** GNU Make 4.3

## Build and Run Instructions
To run the Verilator simulation, follow these steps:

1.  Navigate to the software directory:
    ```bash
    cd verilator_sw
    ```

2.  Compile the project using the Makefile:
    ```bash
    make
    ```

3.  Run the generated executable:
    ```bash
    ./obj_dir/Vstopwatch_top
    ```

## Design Choices

### 1. Hardware Architecture
* **Modular Design:** The system is split into three distinct modules (`control_fsm`, `seconds_counter`, `minutes_counter`) to ensure separation of concerns.
* **Synchronous Logic:** All counters are synchronous to the global clock `clk`. No ripple counters were used.
* **FSM Implementation:** A 3-state Mealy-like machine (IDLE, RUNNING, PAUSED) controls the system. I chose to use separate output logic for `count_enable` and `clear_time` to prevent race conditions during state transitions.

### 2. Software Co-Design
* **Clock Simulation:** The C++ wrapper manually toggles the clock signal (`clk`) to simulate hardware cycles.
* **Time Scaling:** For demonstration purposes, the C++ loop treats one clock cycle as one second to allow for immediate visual verification of the time increment logic without waiting for millions of cycles.
* **Output Formatting:** The software reads the raw integer values from the hardware ports and formats them into a standard `MM:SS` string using `std::setw` and `std::setfill`.
