# bloxNES

## What This Is

bloxNES is a full NES emulator running inside Roblox, ported from the C++ SimpleNES codebase to Luau. Players join a Roblox game with a physical NES console brick in the center of the map — the brick displays the NES screen via SurfaceGui, physical button parts provide controller input, and keyboard input is also supported. The emulator runs public domain NES ROMs with full hardware emulation (6502 CPU, PPU graphics, APU audio) and multiple memory mappers, with toggleable rendering modes via a GUI settings panel.

## Core Value

Players can play NES games inside Roblox with authentic emulation and flexible input/rendering options.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope. Building toward these. -->

- [ ] Full NES emulation: 6502 CPU, PPU (graphics), APU (audio)
- [ ] Support multiple NES memory mappers (NROM, MMC1, MMC3, etc.)
- [ ] Run public domain NES ROMs from rom/ folder (starting with BombSweeper)
- [ ] NES screen rendered on a brick in center of map via SurfaceGui
- [ ] Physical button parts as NES controller (A, B, Start, Select, D-pad)
- [ ] Keyboard input support via UserInputService (PC players)
- [ ] GUI settings panel to toggle rendering mode
- [ ] Two rendering modes, toggleable:
  - Pixel-drawing mode (texture-based, update pixels per frame)
  - Part-based mode (Roblox parts/frames to represent pixels)
- [ ] Audio playback via Roblox sound objects (APU output)

### Out of Scope

- [Commercial NES ROMs] — Legal concerns, public domain only for v1
- [Multiplayer NES] — Single-player only for v1
- [Save states] — Not in v1, may come later
- [Network multiplayer between Roblox players] — Out of scope for v1

## Context

**Technical Environment:**
- Roblox platform with Luau (Roblox's Lua dialect)
- Porting from C++ SimpleNES (in src/SimpleNES/) to Luau
- Rojo for project synchronization between filesystem and Roblox Studio
- Reference implementation: CPU, PPU, APU, Cartridge, Mappers in C++

**Prior Work:**
- SimpleNES C++ codebase analyzed and mapped (src/SimpleNES/)
- Codebase mapping complete (.planning/codebase/)
- Only "Hello World" prints exist in current Luau code

**Known Challenges:**
- Performance: NES requires ~60 FPS emulation, Luau is slower than C++
- Rendering: 256x240 NES resolution to Roblox SurfaceGui efficiently
- Audio: APU sample generation to Roblox sound objects
- Accuracy: Cycle-accurate timing in interpreted Luau

## Constraints

- **Platform**: Roblox only — must run within Roblox engine limitations
- **Performance**: Must maintain ~60 FPS emulation speed in Luau
- **ROM Scope**: Public domain ROMs only (legal boundary)
- **Rendering**: SurfaceGui on brick, two toggleable modes
- **Input**: Physical button parts + keyboard, no gamepad API in Roblox

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Port SimpleNES to Luau | Existing C++ codebase provides complete NES implementation reference | — Pending |
| Public domain ROMs only | Avoid legal issues with commercial ROMs | — Pending |
| Two rendering modes | Flexibility for different performance/visual needs | — Pending |
| Physical + keyboard input | Support both mobile (physical buttons) and PC (keyboard) players | — Pending |
| GUI settings panel | Let players choose rendering mode and configure input | — Pending |

---
*Last updated: 2026-05-03 after initialization*
