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
| HDL | Verilog (primary), VHDL (PS/2 peripheral) |
| Target Platform | Basys 3 (Xilinx Artix-7 FPGA) |
| Memory | Dual-Port Block RAM (BRAM) |
| Display | OLED via SPI |
| Input | PS/2 Mouse |
| Tools | Xilinx Vivado, RTL Simulation |

---

## Project Structure

```
Verialgo/
├── final.srcs/
│   ├── sources_1/new/
│   │   │
│   │   │── Top_Student_Integrated.v     # SoC top module
│   │   │
│   │   │   # Sort Engines
│   │   ├── merge_sort_engine.v          # Merge Sort FSM
│   │   ├── cocktail_sort_engine.v       # Cocktail Sort FSM (full)
│   │   ├── cocktail_sort_simple.v       # Cocktail Sort (simplified)
│   │   ├── random_sort_simple.v         # Random shuffle engine
│   │   │
│   │   │   # Animation & Memory
│   │   ├── history_buffer.v             # Delta Animation Buffer (circular BRAM)
│   │   ├── dual_port_ram.v              # Dual-Port BRAM primitive
│   │   │
│   │   │   # Graphics Pipeline
│   │   ├── Oled_Display.v               # OLED SPI display driver
│   │   ├── Oled_Display.vh              # Display header/parameters
│   │   ├── text_renderer.v              # Bitmap font text rendering
│   │   ├── font_rom.v                   # Font ROM (bitmap glyphs)
│   │   ├── mouse_cursor_gfx.v           # Hardware mouse cursor sprite
│   │   ├── playback_indicator_gfx.v     # Playback status UI element
│   │   ├── eight_bar_celebration.v      # Sort completion animation
│   │   │
│   │   │   # GUI Screens
│   │   ├── verialgo_splash_gfx.v        # Splash / boot screen
│   │   ├── prescreen_gfx.v              # Pre-sort setup screen
│   │   ├── selection_screen_gfx.v       # Algorithm selection screen
│   │   ├── algo_selection_gfx.v         # Algorithm picker UI
│   │   ├── array_entry_gfx.v            # Manual array input screen
│   │   ├── create_setup_gfx.v           # Configuration screen
│   │   │
│   │   │   # Peripheral Drivers & Utilities
│   │   ├── Ps2Interface.vhd             # PS/2 mouse interface (VHDL)
│   │   ├── Mouse_Control.vhd            # PS/2 mouse controller (VHDL)
│   │   ├── debouncer.v                  # Input debouncer
│   │   ├── clock_divider.v              # Clock divider for speed control
│   │   └── lfsr.v                       # LFSR pseudo-random number generator
│   │
│   ├── sim_1/new/                       # Testbenches
│   └── constrs_1/new/                   # XDC constraint files
└── final.xpr                            # Vivado project file
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
