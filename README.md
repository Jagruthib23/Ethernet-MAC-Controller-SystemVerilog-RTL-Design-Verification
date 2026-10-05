# Ethernet-MAC-Controller-SystemVerilog-RTL-Design-Verification
SystemVerilog RTL design and verification of an Ethernet MAC controller with TX/RX FSMs, CRC-32/FCS, MAC filtering, assertions, and functional coverage.

# Ethernet MAC Controller | SystemVerilog RTL Design & Verification

A synthesizable Ethernet Media Access Control (MAC) controller implemented using SystemVerilog RTL, featuring frame transmission and reception, CRC-32/FCS processing, destination MAC filtering, payload padding, and simulation-based verification.

The project focuses on RTL design, finite state machines, protocol-level frame handling, and functional verification using Icarus Verilog, GTKWave, and Vivado.

## Key Features

* Ethernet TX: Frame generation using a finite state machine (FSM).
* Ethernet RX: Frame reception, header parsing, and payload extraction.
* CRC-32/FCS: Frame check sequence generation and error detection.
* MAC Address Filtering: Destination address validation and broadcast frame support.
* Payload Padding: Zero-padding for payloads shorter than the 46-byte Ethernet minimum.
* Frame Validation: Detection of CRC errors and invalid destination MAC addresses.
* Verification: Directed testbenches, assertions, and functional scenario tracking.
* Synthesis: RTL synthesis using Xilinx Vivado 2023.2.

## Architecture

```text
                   +----------------------+
 TX Interface ---->|                      |----> TX Byte Stream
                   |    Ethernet MAC TX   |
                   |      TX FSM          |
                   |                      |
                   +----------------------+

                   +----------------------+
 RX Byte Stream -->|                      |----> RX Interface
                   |    Ethernet MAC RX   |
                   |      RX FSM          |
                   |                      |
                   +----------------------+
                             |
                   +----------------------+
                   | CRC-32 / FCS Checking|
                   | MAC Address Filtering|
                   +----------------------+
```

The design is organized into reusable RTL modules for transmission, reception, and CRC computation, integrated through a top-level Ethernet MAC module.

## Ethernet Frame Format

The controller handles the following Ethernet frame fields:

 Field                                 Size 

 Preamble                           7 bytes 
 Start Frame Delimiter (SFD)        1 byte 
 Destination MAC Address            6 bytes 
 Source MAC Address                 6 bytes 
 EtherType                          2 bytes 
 Payload                            46–1500 bytes 
 Frame Check Sequence (FCS)         4 bytes 

Frame sizes follow the standard Ethernet convention: the 64-byte minimum and 1518-byte maximum exclude the preamble and SFD.

## Project Structure

```text
Ethernet-MAC-Controller/
├── rtl/
│   ├── crc32.sv
│   ├── mac_tx.sv
│   ├── mac_rx.sv
│   └── ethernet_mac.sv
├── tb/
│   ├── crc32_tb.sv
│   ├── mac_tx_tb.sv
│   ├── mac_rx_tb.sv
│   ├── mac_rx_crc_error_tb.sv
│   ├── mac_rx_mac_error_tb.sv
│   ├── mac_rx_broadcast_tb.sv
│   ├── mac_rx_min_payload_tb.sv
│   ├── mac_rx_100_payload_tb.sv
│   ├── mac_rx_back_to_back_tb.sv
│   └── mac_rx_coverage_tb.sv
├── sim/
├── docs/
├── .gitignore
└── README.md
```

## Verification and Test Results

Simulation-based verification was performed using **Icarus Verilog 12.0** and waveforms were inspected using **GTKWave**.

 Test Scenario                           Expected Result 

 CRC-32 known test vector (`123456789`)  PASS            
 TX frame generation                     PASS            
 Valid RX frame                          PASS            
 Corrupted FCS / CRC error               PASS            
 Wrong destination MAC                   PASS            
 Broadcast frame                         PASS            
 Minimum 46-byte payload                 PASS            
 100-byte payload                        PASS            
 Payload padding                         PASS            
 Back-to-back frame reception            PASS            
 RX assertions                           PASS            

### CRC-32 Validation

The CRC implementation was verified using the standard test vector:

* Input: `123456789`
* Expected CRC-32: `0xCBF43926`
* Observed CRC-32: `0xCBF43926`
* Result: PASS

### Functional Coverage

The functional coverage testbench tracks seven scenarios:

* Minimum-length payload
* Normal payload
* Payload requiring padding
* CRC error detection
* MAC address filtering
* Broadcast frame reception
* Back-to-back frame reception

**Result: 7/7 tracked scenarios covered.**

This represents scenario coverage from the implemented testbench, not exhaustive protocol coverage.

## Simulation Instructions

Run the following commands from the repository root. These examples assume Icarus Verilog is installed and available in your terminal.

### 1. CRC-32 Test

```bash
iverilog -g2012 -o sim/crc_sim rtl/crc32.sv tb/crc32_tb.sv
vvp sim/crc_sim
```

Expected output includes:

```text
CRC      = cbf43926
Expected = CBF43926
PASS: CRC is correct!
```

### 2. TX Simulation

```bash
iverilog -g2012 -o sim/mac_tx_sim rtl/crc32.sv rtl/mac_tx.sv tb/mac_tx_tb.sv
vvp sim/mac_tx_sim
```

### 3. RX Simulation

```bash
iverilog -g2012 -o sim/mac_rx_sim rtl/crc32.sv rtl/mac_rx.sv tb/mac_rx_tb.sv
vvp sim/mac_rx_sim
```

### 4. CRC Error Test

```bash
iverilog -g2012 -o sim/mac_rx_crc_error_sim rtl/crc32.sv rtl/mac_rx.sv tb/mac_rx_crc_error_tb.sv
vvp sim/mac_rx_crc_error_sim
```

### 5. Back-to-Back Frame Test

```bash
iverilog -g2012 -o sim/mac_rx_back_to_back_sim rtl/crc32.sv rtl/mac_rx.sv tb/mac_rx_back_to_back_tb.sv
vvp sim/mac_rx_back_to_back_sim
```

### 6. Functional Coverage Test

```bash
iverilog -g2012 -o sim/mac_rx_coverage_sim rtl/crc32.sv rtl/mac_rx.sv tb/mac_rx_coverage_tb.sv
vvp sim/mac_rx_coverage_sim
```

### Viewing Waveforms

To inspect a generated VCD waveform:

```bash
gtkwave sim/mac_rx_back_to_back.vcd
```

The corresponding testbench must generate the VCD file before GTKWave can open it.

## Synthesis

The RTL was synthesized using:

* **Tool:** Xilinx Vivado 2023.2
* **Target device:** Kintex-7 `xc7k70tfbv676-1`

Synthesis completed with *zero errors and zero critical warnings*, with one non-critical warning reported by Vivado.

No timing constraints were applied; therefore, timing closure and post-implementation performance have not been established.

## Tools and Technologies

* HDL: SystemVerilog
* Simulation: Icarus Verilog
* Waveform Analysis: GTKWave
* Synthesis: Xilinx Vivado 2023.2
* Concepts: RTL Design, FSMs, CRC-32, Ethernet Framing, MAC Address Filtering, Assertions, Functional Verification

## Scope and Limitations

This is an educational RTL implementation of selected Ethernet MAC functions. It does not implement the Ethernet PHY, IP/TCP/UDP layers, or a complete network stack. The verification results reflect the test scenarios implemented in this project and do not establish full IEEE 802.3 compliance.

## Future Improvements

* Add constrained-random frame generation and broader payload-length testing.
* Develop a reusable reference-model scoreboard.
* Extend verification to malformed frames and additional corner cases.
* Add timing constraints and evaluate implementation timing.
* Explore FPGA hardware validation with a compatible Ethernet PHY interface.

---

Project Focus: SystemVerilog RTL Design | Digital Design | Ethernet MAC | CRC-32 | Design Verification | Vivado Synthesis
