# Roadmap: bloxNES

## Overview

bloxNES ports the SimpleNES C++ emulator to Luau inside Roblox. The journey: build a cycle-accurate 6502 CPU → implement PPU graphics with correct timing → create two rendering modes on SurfaceGui → add APU audio playback → support multiple memory mappers → enable physical and keyboard input → load public domain ROMs → and finally wrap it all in a GUI settings panel. Each phase delivers a testable capability, from CPU correctness (validated by nestest) to playing complete NES games inside Roblox.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: CPU Foundation** - 6502 CPU emulation runs with all 56 opcodes and correct reset
- [ ] **Phase 2: PPU Graphics** - PPU renders NES graphics at 256x240 with cycle-accurate timing and correct palette
- [ ] **Phase 3: Rendering Modes** - NES screen displays on brick via SurfaceGui with two toggleable rendering modes at ~60 FPS
- [ ] **Phase 4: Audio (APU)** - APU generates and plays all 5 NES audio channels through Roblox sound objects with video sync
- [ ] **Phase 5: Memory Mappers** - Multiple NES memory mappers (NROM, MMC1, MMC3, CNROM) load and run correctly with auto-detection
- [ ] **Phase 6: Input System** - Players control NES games via physical button parts and keyboard with <50ms latency
- [ ] **Phase 7: ROM Management** - Public domain ROMs load from rom/ folder with header parsing and error handling
- [ ] **Phase 8: GUI & Settings** - Settings panel allows rendering mode toggle, FPS display, ROM selection, and accessible controls

## Phase Details

### Phase 1: CPU Foundation
**Goal**: NES 6502 CPU emulation runs correctly with all 56 opcodes and proper reset behavior
**Depends on**: Nothing (first phase)
**Requirements**: EMUL-02, EMUL-06
**Success Criteria** (what must be TRUE):
  1. Player can run nestest.nes and see correct CPU test results verifying all 56 official opcodes
  2. CPU executes all addressing modes and sets N, V, Z, C flags correctly for each opcode
  3. NES reset (soft reset via CPU) sets registers and memory to correct power-up state
**Plans**: TBD

Plans:
- [ ] 01-01: Port 6502 CPU core from SimpleNES C++ to Luau with all 56 opcodes
- [ ] 01-02: Implement CPU reset vector and power-up state initialization
- [ ] 01-03: Create nestest validation harness and verify CPU correctness

### Phase 2: PPU Graphics
**Goal**: NES PPU renders graphics correctly at 256x240 with cycle-accurate timing and proper palette colors
**Depends on**: Phase 1 (CPU required for PPU register communication)
**Requirements**: EMUL-03, REND-05, REND-06
**Success Criteria** (what must be TRUE):
  1. PPU renders NES test ROMs with correct colors (NES palette maps correctly to Roblox colors)
  2. PPU timing is cycle-accurate at 3 PPU dots per CPU cycle with correct scanline behavior
  3. NES resolution (256x240) displays correctly in Roblox (scaled appropriately if needed)
**Plans**: TBD

Plans:
- [ ] 02-01: Port PPU from SimpleNES C++ to Luau with cycle-accurate timing (3:1 CPU ratio)
- [ ] 02-02: Implement NES palette to Roblox color mapping for all 64 palette entries
- [ ] 02-03: Implement PPU rendering pipeline (nametables, sprites, scanline timing)

### Phase 3: Rendering Modes
**Goal**: NES screen displays on brick in center of map via SurfaceGui with two toggleable rendering modes at ~60 FPS
**Depends on**: Phase 2 (PPU must produce pixel output)
**Requirements**: REND-01, REND-02, REND-03, REND-04, EMUL-05
**Success Criteria** (what must be TRUE):
  1. Player sees NES screen rendered on brick in center of map via SurfaceGui
  2. Player can toggle between pixel-drawing mode and part-based mode via settings
  3. Emulator maintains ~60 FPS (16.67ms per frame) in Luau during rendering
  4. PPU palette colors render correctly in both rendering modes
**UI hint**: yes
**Plans**: TBD

Plans:
- [ ] 03-01: Implement SurfaceGui screen on brick with ImageLabel/texture for pixel-drawing mode
- [ ] 03-02: Implement part-based rendering mode using Roblox parts/frames to represent pixels
- [ ] 03-03: Create GUI settings panel toggle to switch between rendering modes
- [ ] 03-04: Performance optimization pass for 60 FPS using buffer native type and --!native flag

### Phase 4: Audio (APU)
**Goal**: APU generates and plays all 5 NES audio channels through Roblox sound objects with video sync
**Depends on**: Phase 1 (CPU communicates with APU via registers $4000-$4017)
**Requirements**: EMUL-04, AUDI-01, AUDI-02, AUDI-03, AUDI-04, AUDI-05, AUDI-06
**Success Criteria** (what must be TRUE):
  1. Player hears correct NES audio from all 5 APU channels (2x pulse, triangle, noise, DMC)
  2. Audio syncs with video during gameplay (no desync between APU output and PPU rendering)
  3. Player can control volume via GUI settings
**Plans**: TBD

Plans:
- [ ] 04-01: Port APU from SimpleNES C++ to Luau (pulse, triangle, noise, DMC channels)
- [ ] 04-02: Implement APU sample generation to Roblox Sound object pipeline
- [ ] 04-03: Handle DMC DMA and frame counter IRQ timing (Pitfall 5 from research)
- [ ] 04-04: Add volume control and audio/video sync verification

### Phase 5: Memory Mappers
**Goal**: Multiple NES memory mappers (NROM, MMC1, MMC3, CNROM) load and run correctly with auto-detection
**Depends on**: Phase 1 (CPU for bank switching), Phase 2 (PPU for MMC3 scanline IRQs)
**Requirements**: MAPR-01, MAPR-02, MAPR-03, MAPR-04, MAPR-05
**Success Criteria** (what must be TRUE):
  1. NROM mapper (0) loads and runs games without bank switching
  2. MMC1 mapper (1) supports PRG-ROM and CHR-ROM bank switching for larger games
  3. MMC3 mapper (4) supports advanced bank switching and scanline-based IRQs (test with Battletoads)
  4. CNROM mapper (3) supports CHR-ROM bank switching
  5. Mapper auto-detection correctly identifies mapper number from iNES header
**Plans**: TBD

Plans:
- [ ] 05-01: Implement NROM mapper (0) with no bank switching
- [ ] 05-02: Implement MMC1 mapper (1) with bank switching registers
- [ ] 05-03: Implement MMC3 mapper (4) with scanline IRQs and advanced bank switching
- [ ] 05-04: Implement CNROM mapper (3) and mapper auto-detection from ROM header

### Phase 6: Input System
**Goal**: Players control NES games via physical button parts and keyboard input with minimal latency
**Depends on**: Phase 1 (CPU reads controller registers $4016/$4017)
**Requirements**: INPT-01, INPT-02, INPT-03, INPT-04, INPT-05
**Success Criteria** (what must be TRUE):
  1. Player can use physical button parts (A, B, Start, Select, D-Pad) on/near brick to control NES games
  2. Player can use keyboard (arrow keys, Z, X, Enter, Shift) via UserInputService to control NES games
  3. Both input methods work simultaneously without conflict (player can switch seamlessly)
  4. Input latency is minimal (<50ms) for playable experience
  5. Controller state resets properly on NES reset
**Plans**: TBD

Plans:
- [ ] 06-01: Implement physical button parts with ClickDetectors mapping to NES controller ($4016/$4017)
- [ ] 06-02: Implement keyboard input via UserInputService mapping to NES controller registers
- [ ] 06-03: Handle simultaneous input from both methods and controller state reset
- [ ] 06-04: Measure and optimize input latency to achieve <50ms target

### Phase 7: ROM Management
**Goal**: Public domain ROMs load from rom/ folder with header parsing, error handling, and legal compliance
**Depends on**: Phase 1 (CPU to execute), Phase 5 (mappers to load correctly)
**Requirements**: ROM-01, ROM-02, ROM-03, ROM-04, EMUL-01
**Success Criteria** (what must be TRUE):
  1. Player can run public domain NES ROMs from rom/ folder (BombSweeper as first test)
  2. ROM header parsing detects PRG-ROM size, CHR-ROM size, and mapper number correctly
  3. Invalid or corrupted ROM files show clear error message to player
  4. Only public domain ROMs are included (legal compliance verified)
**Plans**: TBD

Plans:
- [ ] 07-01: Implement ROM loading from rom/ folder via ReplicatedStorage sync
- [ ] 07-02: Implement iNES header parsing (PRG-ROM, CHR-ROM sizes, mapper detection)
- [ ] 07-03: Add error handling for invalid/corrupted ROMs with player-facing messages
- [ ] 07-04: Verify legal compliance (public domain ROMs only) and create ROM validation tool

### Phase 8: GUI & Settings
**Goal**: Settings panel allows rendering mode toggle, FPS display, ROM selection, and accessible controls
**Depends on**: Phase 3 (rendering modes to toggle), Phase 6 (input to access GUI), Phase 7 (ROMs to select)
**Requirements**: GUI-01, GUI-02, GUI-03, GUI-04
**Success Criteria** (what must be TRUE):
  1. Settings panel GUI allows toggling rendering mode (pixel vs part-based)
  2. Settings panel displays current FPS and emulation status to player
  3. Player can select different ROMs from available public domain games
  4. GUI is accessible via clickable button on brick or keyboard keybind
**UI hint**: yes
**Plans**: TBD

Plans:
- [ ] 08-01: Build settings panel GUI with rendering mode toggle and volume control
- [ ] 08-02: Add FPS counter and emulation status display to settings panel
- [ ] 08-03: Implement ROM selection UI for switching between public domain games
- [ ] 08-04: Add GUI accessibility via clickable button on brick and keyboard keybind

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

Note: Phases 4 (Audio) and 6 (Input) and 7 (ROM) can theoretically parallelize after their dependencies are met, but execute sequentially per GSD workflow.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. CPU Foundation | 0/3 | Not started | - |
| 2. PPU Graphics | 0/3 | Not started | - |
| 3. Rendering Modes | 0/4 | Not started | - |
| 4. Audio (APU) | 0/4 | Not started | - |
| 5. Memory Mappers | 0/4 | Not started | - |
| 6. Input System | 0/4 | Not started | - |
| 7. ROM Management | 0/4 | Not started | - |
| 8. GUI & Settings | 0/4 | Not started | - |

---
*Roadmap created: 2026-05-03*
*Granularity: Fine (8 phases as suggested by research)*
*Coverage: 36/36 v1 requirements mapped ✓*
