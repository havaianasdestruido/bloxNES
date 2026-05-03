# Feature Landscape

**Domain:** NES emulator on Roblox (Luau)  
**Researched:** 2026-05-03  
**Project:** bloxNES

---

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|----------------|------------|-------|
| **Full 6502 CPU emulation** | NES can't run without it | High | All 56 official opcodes + unofficial ones; correct flags (N, V, Z, C); page boundary penalties |
| **PPU graphics (256×240)** | Visual output is essential | High | Cycle-accurate PPU; background + sprite rendering; nametable mirroring; palette |
| **APU audio (5 channels)** | Authentic NES sound | High | 2×Pulse, Triangle, Noise, DMC; frame counter; expansion audio (optional for v1) |
| **Controller input (NES buttons)** | Playable games | Medium | A, B, Start, Select, D-pad; map to keyboard + physical button parts |
| **Public domain ROM loading** | Must have games to play | Medium | Load ROM from Roblox assets (ReplicatedStorage); parse iNES header; start with BombSweeper |
| **SurfaceGui screen on brick** | Core project concept | Medium | Render NES output to brick face; two toggleable modes |
| **Multiple memory mappers** | Support multiple game types | High | NROM (Mapper 0) first; then MMC1, MMC3; each has different bank switching |
| **Two rendering modes** | Flexibility for perf/visuals | Medium | Pixel-drawing (texture) vs Part-based (Frames); toggle via GUI |
| **GUI settings panel** | User control over experience | Low | Toggle rendering mode; potential future: keybinding, volume |

---

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Physical button parts as controller** | Unique Roblox experience; tactile feel | Medium | Players click 3D button parts in-game; mobile-friendly |
| **In-game NES console brick** | Immersive; fits Roblox world | Low | Center of map; players gather around it |
| **Two toggleable rendering modes** | Choose perf (parts) vs visual (pixels) | Medium | Part mode: less visual fidelity but maybe faster; Pixel mode: authentic but heavy |
| **Public domain ROMs only (legal safety)** | Clear legal boundary; safe for Roblox | Low | No commercial ROMs; educational/historical games only |
| **Keyboard + physical input dual support** | PC and mobile players supported | Low | UserInputService for keyboard; ClickDetectors for buttons |

---

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|---------------|-----------|-------------------|
| **Commercial NES ROMs** | Legal issues; copyright infringement | Public domain ROMs only; state legal boundary clearly |
| **Multiplayer NES (2-player co-op)** | Too complex for v1; no netplay API in Roblox | Single-player only for v1; may add local 2-player (P2 controller) |
| **Save states** | Complex; requires state serialization | Not in v1; only in-game saves via battery-backed RAM (if ROM supports) |
| **Network multiplayer between Roblox players** | Out of scope; requires syncing emulator state | Out of scope for v1; focus on single-player emulation |
| **Cycle-accurate audio (DMC ultra-precision)** | Overkill for v1; perf cost in Luau | Approximate APU first; refine if time permits |
| **All 600+ NES mappers** | Unnecessary; only few popular ones needed | Support NROM, MMC1, MMC3 first; add others in v2+ |
| **Roblox gamepad API for controllers** | Roblox doesn't have gamepad API | Use keyboard + physical button parts instead |

---

## Feature Dependencies

```
Full NES Emulation
├── 6502 CPU Emulation
├── PPU Graphics
│   ├── Nametable Mirroring
│   ├── Palette / Color Emulation
│   └── Sprite Rendering
├── APU Audio
│   ├── Pulse/Triangle/Noise channels
│   └── DMC (sample playback)
├── Memory Mappers
│   ├── NROM (Mapper 0) → Required for BombSweeper
│   ├── MMC1 (Mapper 1) → Future games
│   └── MMC3 (Mapper 3) → Future games (Mega Man 2, etc.)
└── ROM Loading
    ├── iNES header parsing
    └── PRG-ROM + CHR-ROM loading

SurfaceGui Screen
├── Pixel-Drawing Mode
│   ├── buffer for pixel data
│   └── ImageLabel texture update
├── Part-Based Mode
│   ├── Frame objects for pixels
│   └── Batch update logic
└── GUI Settings Panel
    ├── Mode toggle button
    └── Future: volume, keybinding

Controller Input
├── Physical Button Parts (A, B, Start, Select, D-pad)
│   └── ClickDetectors
└── Keyboard Input
    └── UserInputService
```

---

## MVP Recommendation

Prioritize for initial playable version:

1. **6502 CPU (official opcodes only)** — Core of emulation
2. **PPU (background + sprites, NROM mapper)** — Show something on screen
3. **Pixel-drawing rendering mode (SurfaceGui)** — Simpler than part-based
4. **Controller input (keyboard A, B, Start, Select, arrows)** — Playable
5. **APU (Pulse channels only, simple beeps)** — Audio validation
6. **Load BombSweeper (public domain ROM)** — First playable game

**Defer:**
- MMC1, MMC3 mappers → After NROM proven
- Part-based rendering → After pixel mode works
- Physical button parts → After keyboard input works
- Full APU (DMC, expansion audio) → After Pulse channels proven
- GUI settings panel → After core emulation stable

---

## Phase-to-Feature Mapping

| Phase | Features Addressed | Dependencies Met |
|-------|---------------------|-------------------|
| **Phase 1: CPU** | 6502 CPU, flags, interrupts | None (foundation) |
| **Phase 2: PPU** | PPU rendering, nametables, sprites | CPU working |
| **Phase 3: Rendering** | SurfaceGui, two modes, pixel output | PPU generating frames |
| **Phase 4: APU** | Audio channels, sound output | CPU working |
| **Phase 5: Mappers** | NROM → MMC1 → MMC3 | CPU + PPU stable |
| **Phase 6: Input** | Keyboard + physical buttons | None (can parallel) |
| **Phase 7: ROM Loading** | Parse iNES, load PD ROMs | Mappers working |
| **Phase 8: GUI** | Settings panel, mode toggle | Rendering + Input working |

---

## Sources

- **PROJECT.md:** Project requirements, constraints — HIGH confidence
- **NESdev Wiki:** iNES format, mappers, hardware features — HIGH confidence
- **SimpleNES analysis:** .planning/codebase/ — HIGH confidence (mapped C++ reference)
- **NES emulator dev guides:** Common features expected — MEDIUM confidence (websearch)

---

*Features mapped: 2026-05-03*  
*Next: ARCHITECTURE.md*
