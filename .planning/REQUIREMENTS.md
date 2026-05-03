# Requirements: bloxNES

**Defined:** 2026-05-03
**Core Value:** Players can play NES games inside Roblox with authentic emulation and flexible input/rendering options.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Emulation Core

- [ ] **EMUL-01**: Player can run public domain NES ROMs from rom/ folder (BombSweeper as first test)
- [ ] **EMUL-02**: 6502 CPU emulation executes NES game code accurately (all 56 official opcodes)
- [ ] **EMUL-03**: PPU renders NES graphics at 256x240 resolution with correct palette colors
- [ ] **EMUL-04**: APU generates NES audio (pulse, triangle, noise, DMC channels) played through Roblox sound
- [ ] **EMUL-05**: Emulator maintains ~60 FPS (16.67ms per frame) in Luau
- [ ] **EMUL-06**: NES reset functionality works (soft reset via GUI or input)

### Memory Mappers

- [ ] **MAPR-01**: NROM mapper (mapper 0) loads and runs correctly (no bank switching)
- [ ] **MAPR-02**: MMC1 mapper (mapper 1) supports bank switching for larger games
- [ ] **MAPR-03**: MMC3 mapper (mapper 4) supports advanced bank switching and IRQs
- [ ] **MAPR-04**: CNROM mapper (mapper 3) supports CHR-ROM bank switching
- [ ] **MAPR-05**: Mapper detection auto-detects correct mapper from ROM header

### Screen Rendering

- [ ] **REND-01**: NES screen displays on brick in center of map via SurfaceGui
- [ ] **REND-02**: Pixel-drawing mode updates texture/image on SurfaceGui each frame
- [ ] **REND-03**: Part-based mode creates Roblox parts/frames to represent NES pixels
- [ ] **REND-04**: GUI settings panel allows player to toggle between rendering modes
- [ ] **REND-05**: Screen renders at authentic NES resolution (256x240) or scaled appropriately
- [ ] **REND-06**: PPU palette colors map correctly to Roblox color values

### Input System

- [ ] **INPT-01**: Physical button parts (A, B, Start, Select, D-Pad) on/near brick provide NES controller input
- [ ] **INPT-02**: Keyboard input via UserInputService maps to NES controller (arrow keys, Z, X, Enter, Shift)
- [ ] **INPT-03**: Both input methods work simultaneously (player can use either)
- [ ] **INPT-04**: Input latency is minimal (<50ms) for playable experience
- [ ] **INPT-05**: Controller state resets properly on NES reset

### GUI & Settings

- [ ] **GUI-01**: Settings panel GUI allows toggling rendering mode (pixel vs part-based)
- [ ] **GUI-02**: Settings panel displays current FPS and emulation status
- [ ] **GUI-03**: Player can select different ROMs from available public domain games
- [ ] **GUI-04**: GUI is accessible via clickable button or keybind

### ROM Management

- [ ] **ROM-01**: ROM files load from rom/ folder (synced via ReplicatedStorage)
- [ ] **ROM-02**: ROM header parsing detects PRG-ROM size, CHR-ROM size, and mapper number
- [ ] **ROM-03**: Invalid or corrupted ROM files show error message to player
- [ ] **ROM-04**: Only public domain ROMs are included (legal compliance)

### Audio

- [ ] **AUDI-01**: APU pulse channels (2x) generate correct NES waveforms
- [ ] **AUDI-02**: APU triangle channel generates correct waveforms
- [ ] **AUDI-03**: APU noise channel generates percussive sounds
- [ ] **AUDI-04**: APU DMC channel plays delta-modulation samples
- [ ] **AUDI-05**: Audio syncs with video (no desync)
- [ ] **AUDI-06**: Volume control via GUI settings

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Features

- **FEAT-01**: Save states (save/load game at any point)
- **FEAT-02**: Multiple ROM support (switch games without rejoining)
- **FEAT-03**: Full-screen mode (expand screen to fill more of the map)
- **FEAT-04**: Gamepad API support (Roblox gamepad input for controllers)

### Multiplayer

- **MULT-01**: Two-player NES games work (second controller input)
- **MULT-02**: Two NES consoles in same map (separate bricks for two players)

### Performance & Polish

- **PERF-01**: Performance optimization pass (profile and optimize hot paths)
- **PERF-02**: Configurable frame skip for slower devices
- **PERF-03**: Dynamic resolution scaling based on performance

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Commercial NES ROMs | Legal concerns — copyright infringement risk |
| Online multiplayer (networked) | Complex, out of scope for v1 |
| Cheat codes / ROM hacks | Not core to authentic NES experience |
| NES mouse / light gun support | Rare peripherals, not in SimpleNES reference |
| Streaming to other Roblox players | Complex networking, not needed for v1 |
| Mobile gyroscope/accelerometer input | Not applicable to NES controller |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| EMUL-01 | Phase 1 | Pending |
| EMUL-02 | Phase 1 | Pending |
| EMUL-03 | Phase 2 | Pending |
| EMUL-04 | Phase 3 | Pending |
| EMUL-05 | Phase 2 | Pending |
| EMUL-06 | Phase 4 | Pending |
| MAPR-01 | Phase 1 | Pending |
| MAPR-02 | Phase 5 | Pending |
| MAPR-03 | Phase 5 | Pending |
| MAPR-04 | Phase 5 | Pending |
| MAPR-05 | Phase 1 | Pending |
| REND-01 | Phase 2 | Pending |
| REND-02 | Phase 2 | Pending |
| REND-03 | Phase 6 | Pending |
| REND-04 | Phase 6 | Pending |
| REND-05 | Phase 2 | Pending |
| REND-06 | Phase 2 | Pending |
| INPT-01 | Phase 4 | Pending |
| INPT-02 | Phase 4 | Pending |
| INPT-03 | Phase 4 | Pending |
| INPT-04 | Phase 4 | Pending |
| INPT-05 | Phase 4 | Pending |
| GUI-01 | Phase 6 | Pending |
| GUI-02 | Phase 6 | Pending |
| GUI-03 | Phase 7 | Pending |
| GUI-04 | Phase 6 | Pending |
| ROM-01 | Phase 1 | Pending |
| ROM-02 | Phase 1 | Pending |
| ROM-03 | Phase 7 | Pending |
| ROM-04 | Phase 1 | Pending |
| AUDI-01 | Phase 3 | Pending |
| AUDI-02 | Phase 3 | Pending |
| AUDI-03 | Phase 3 | Pending |
| AUDI-04 | Phase 3 | Pending |
| AUDI-05 | Phase 3 | Pending |
| AUDI-06 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 37 total
- Mapped to phases: 37
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-03*
*Last updated: 2026-05-03 after initial definition*
