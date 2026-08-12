Date: August 12, 2026
Project: Custom GNSS Baseband Receiver (Fork of greta-oto)
Hardware Targets: ZedBoard (XC7Z020) for Baseline, ADRV9361-Z7035 for Custom Implementation
1. Architecture & RTL Analysis
Deep Dive into greta-oto Baseband: Analyzed the complete RTL signal chain from ADC input to PVT output.
Tracking Engine Analysis: Studied the Time-Division Multiplexing (TDM) architecture. Documented how 4 physical correlators rapidly context-switch to track up to 32 logical satellites by saving/restoring state to RAM.
Acquisition Engine Analysis: Evaluated the 2D search grid (Doppler × Code Phase). Documented the rationale behind the 682-sample (1/3 ms) coherent integration blocks used to prevent navigation data bit transitions from canceling out the signal.
Memory Map Review: Mapped out the address.v register space (Global, AE, TE, FIFO, and Peripheral registers) to understand the CPU-to-FPGA interface.
2. Hardware Feasibility Study & Design Pivots
ADRV9361 Dual-Frequency Investigation: Initially proposed tuning RX1 to L1 and RX2 to L2 for dual-frequency operation.
Correction/Discovery: Investigated the AD9361 datasheet and discovered the chip shares a single RX Local Oscillator (LO) between RX1 and RX2. True simultaneous L1+L2 is impossible on a single AD9361.
Pivot: Shifted the custom design focus to maximizing single-band (L1) performance (12-bit ADC, 5-10 MHz sample rate, FFT acquisition, and narrow correlators) rather than impossible hardware configurations.
Zynq-7020 vs Zynq-7035 Resource Planning: Evaluated LUT/BRAM utilization limits for the ZedBoard to ensure the unmodified baseline fits before adding custom FFT/Correlator logic.
3. Repository & Version Control Strategy
Repo Structuring: Designed a split-directory Git repository architecture to prevent custom modifications from breaking the baseline hardware verification.
baseline/: Read-only original RTL for ZedBoard verification.
custom/: Working directory for modified RTL (ADRV9361 target).
Git Workflow: Established a feature-branch strategy for upcoming RTL modifications (e.g., feat/adc-12bit, feat/fft-acquisition).
4. RTL Development & IP Integration
AXI4-Lite Bridge Design: Wrote and documented gnss_axi_wrapper.v.
Function: Translates Zynq ARM AXI4-Lite read/write transactions into the simple host_cs/rd/wr bus expected by gnss_top.
Implementation: Developed dual state machines (Write Path and Read Path) with proper AXI handshaking (AWREADY, WVALID, etc.) and byte-to-DWORD address translation.
Testbench & Verification Strategy (Major Find):
Discovered if_data/all_signal.bin in the original repository, which contains 200ms of realistic, simulated multi-constellation IF data (L1 C/A, L1C, B1C, E1) with proper Doppler shifts and PRN codes.
Action: Abandoned the idea of a dummy sine-wave generator (test_pattern_gen.v).
New Implementation: Designed if_data_reader.v to load all_signal.bin into Zynq BRAM and stream it at 4.113 MHz. This allows the ZedBoard to acquire actual simulated satellites without needing external RF hardware.
5. Vivado Block Design Planning
Mapped out the complete IP Integrator Block Diagram for the ZedBoard baseline:
Zynq PS (XC7Z020) with 100MHz PL clock and AXI GP0 master enabled.
AXI Interconnect routing to gnss_axi_wrapper and AXI GPIO (for onboard LEDs).
Integration of if_data_reader to feed the ADC ports of the wrapper.
Drafted the XDC constraints file structure for ZedBoard pins (LEDs, Switches, PMOD PPS outputs).