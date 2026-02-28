# Verialgo 🔧
### FPGA Hardware-Accelerated Algorithm Visualizer & Custom SoC Architecture

> A fully synchronous, bare-metal System-on-Chip (SoC) built entirely in Verilog HDL — no soft-core processors, no shortcuts.

**National University of Singapore · Oct 2025 – Nov 2025**

---

## Overview

Verialgo is a custom FPGA SoC that visualizes sorting algorithms in real-time on an external OLED display. The entire system — from sorting engines to graphics pipeline to GUI — is implemented in RTL Verilog, demonstrating a strict separation between hardware datapath and control planes.

No MicroBlaze. No Nios II. Just hardware.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    SoC Top Module                    │
│                                                     │
│  ┌─────────────┐   ┌──────────────────────────┐    │
│  │  Sort Engine │   │   Delta Animation Buffer  │    │
│  │  ─────────  │   │   ──────────────────────  │    │
│  │  Merge Sort  │──▶│   Circular BRAM Buffer    │    │
│  │  Cocktail   │   │   (Pause / Rewind / Step) │    │
│  └─────────────┘   └──────────────┬───────────┘    │
│                                   │                 │
│  ┌────────────────────────────────▼───────────┐    │
│  │           Pixel-Stream Render Engine        │    │
│  │   Bar charts · Bitmap fonts · 3D UI        │    │
│  └────────────────────────┬───────────────────┘    │
│                            │ SPI                    │
│  ┌─────────────────────────▼───────────────────┐   │
│  │  Peripheral Drivers                          │   │
│  │  PS/2 Mouse Controller · SPI Display Init   │   │
│  └──────────────────────────────────────────────┘   │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │  Hardware GUI                                 │   │
│  │  LFSR RNG · On-screen Keypad · Speed Control │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## Key Features

### RTL Sort Engines
- **Merge Sort** — Recursive logic translated into parallel hardware FSMs operating on data arrays at clock speed
- **Cocktail Sort** — Iterative bidirectional sort implemented as a state machine with configurable pass tracking
- Both engines expose array state at every step for visualization capture

### Delta Animation Buffer
- Circular buffer built on **Dual-Port Block RAM (BRAM)**
- Captures array snapshots after each comparison/swap operation
- Enables full playback control: **pause, rewind, slow-motion, frame-by-frame stepping**
- All playback logic runs entirely in hardware — zero CPU involvement

### Custom Graphics Pipeline
- Pixel-stream rendering engine drives an external **OLED display via SPI** from scratch
- Handles real-time coordinate mapping for **dynamic bar charts**
- Renders **custom bitmap fonts/text** and **3D-style UI elements** without a GPU

### Peripheral Drivers
- **PS/2 Mouse Controller** — full protocol packet decoding, X/Y overflow handling, input debouncing
- **SPI Display Driver** — complete initialization sequence and frame transmission

### Hardware GUI
- **LFSR** (Linear Feedback Shift Register) for pseudo-random array generation
- **On-screen keypad** for manual data entry
- Configurable simulation speed control

---

## Tech Stack

| Category | Details |
|---|---|
| HDL | Verilog |
| Target Platform | FPGA (Vivado toolchain) |
| Memory | Dual-Port Block RAM (BRAM) |
| Display | OLED via SPI |
| Input | PS/2 Mouse |
| Tools | Xilinx Vivado, RTL Simulation |

---

## Project Structure

```
Verialgo/
├── final.srcs/
│   ├── sources_1/new/       # RTL source files (.v)
│   │   ├── top.v            # SoC top module
│   │   ├── sort_engine/     # Merge Sort & Cocktail Sort FSMs
│   │   ├── anim_buffer/     # Delta Animation Buffer (BRAM)
│   │   ├── render_engine/   # Pixel-stream graphics pipeline
│   │   ├── spi_driver/      # OLED SPI driver
│   │   ├── ps2_controller/  # PS/2 mouse driver
│   │   └── gui/             # Hardware GUI modules
│   ├── sim_1/new/           # Testbenches
│   └── constrs_1/new/       # XDC constraint files
└── final.xpr                # Vivado project file
```

---

## What I Learned

- Translating high-level algorithmic logic (recursion, iteration) into synthesizable RTL hardware FSMs
- Managing BRAM timing constraints for dual-port read/write operations
- Building a complete pixel rendering pipeline without any display library
- Low-level peripheral interfacing (SPI protocol, PS/2 packet decoding)
- The hardware/software boundary — everything a soft-core processor would normally handle, done in gates

---

## Author

**Ariff Muhammed Ahsan** · [LinkedIn](https://linkedin.com/in/ariff-muhammed-ahsan) · [Portfolio](https://ariffm.netlify.app)

*Computer Engineering, National University of Singapore*
