# Research Summary: bloxNES

**Domain:** NES emulator on Roblox (Luau port of SimpleNES)  
**Researched:** 2026-05-03  
**Overall confidence:** HIGH (NESdev Wiki, hardware docs, emulator developer war stories, Luau perf docs)

---

## Executive Summary

bloxNES is a unique project: porting a complete NES emulator (SimpleNES C++) to Luau running inside Roblox. This combines three difficult domains: NES hardware emulation (notoriously tricky timing), C++-to-Luau porting (type system & performance differences), and Roblox platform constraints (limited execution time, SurfaceGui rendering limitations).

**Key findings:**

1. **NES emulation correctness is dominated by PPU timing.** The Picture Processing Unit must be cycle-accurate (3 PPU dots per CPU cycle) or games like Battletoads, Super Mario Bros., and Mach Rider will glitch. The PPU has documented hardware bugs (sprite overflow flag, $2000/$2005/$2006 early-write glitches at dot 257) that commercial games rely on.

2. **Luau performance is the critical risk.** NES requires ~29780 CPU cycles/frame × 3 PPU dots = ~89k PPU updates/frame plus audio. Luau tables are slower than C++ arrays; table creation in emulation loops triggers GC pressure. Pre-allocation with `table.create()` and `--!native` flags are essential.

3. **Rendering 256×240 pixels on SurfaceGui is uncharted territory.** No known Roblox projects do per-pixel framebuffer updates at 60 FPS. Two modes (pixel-texture vs part-based) are planned, but both have performance pitfalls. Using `buffer` native type is recommended over tables for pixel data.

4. **Audio (APU) has subtle DMA/IRQ timing.** DMC DMA conflicts with controller reads (hardware bug used by games like Gimmick!). Frame counter generates IRQs at ~240Hz with cycle delays after $4017 writes.

5. **Memory mappers (MMC1, MMC3) have complex IRQ timing.** MMC3 IRQs are based on PPU scanlines, not CPU cycles. Battletoads stage 2 is the canonical test case.

---

## Key Findings

**Stack:** Luau (Roblox's Lua), SimpleNES C++ as reference, Rojo for dev workflow. No third-party Luau NES libraries exist — everything must be written from scratch.

**Architecture:** Memory-bus pattern with function callbacks for components (CPU, PPU, APU, Cartridge). Cycle-accurate PPU clocking (3:1 ratio with CPU). Mapper as swappable modules.

**Critical pitfall:** PPU timing accuracy. Most emulator projects fail here. Must use NESdev Wiki PPU rendering diagram, implement scanline timing, handle $2000/$2005/$2006 early-write glitches, and sync with CPU clock.

**Roblox-specific:** Luau has ~30ms/frame budget. NES emulation needs ~150k+ operations/frame. Must use `buffer` for pixels, consider `--!native` for server-side scripts, and potentially spread work across frames with `task.wait()`.

---

## Implications for Roadmap

Based on research, suggested phase structure:

### 1. **CPU Foundation** (Phase 1)
   - **Addresses:** 6502 CPU emulation (FEATURES.md: "Full 6502 CPU")
   - **Avoids:** Pitfall 2 (Overflow flag wrong), Pitfall 8 (C++ porting type errors), Pitfall 12 (page boundary penalties missing)
   - **Rationale:** CPU must be cycle-accurate with correct flags (N, V, Z, C) before PPU/APU can work. Use `nestest.nes` for validation immediately.

### 2. **PPU Graphics** (Phase 2)
   - **Addresses:** PPU rendering, nametables, sprites (FEATURES.md: "PPU graphics")
   - **Avoids:** Pitfall 1 (PPU timing), Pitfall 9 (sprite evaluation bugs), Pitfall 11 (NMI timing), Pitfall 13 (scroll register latching)
   - **Rationale:** Most difficult component. Must be cycle-accurate from day 1. Use NESdev Wiki PPU frame timing diagram. Test with sprite 0 hit ROMs, PPU coloring tests.

### 3. **Rendering Modes** (Phase 3)
   - **Addresses:** SurfaceGui screen, two toggleable modes (FEATURES.md: "SurfaceGui screen", "Two rendering modes")
   - **Avoids:** Pitfall 4 (SurfaceGui performance), Anti-Pattern 2 (per-pixel updates)
   - **Rationale:** Critical for playable FPS. Prototype early with `buffer` + ImageLabel. Consider 128×120 half-resolution as fallback.

### 4. **Audio (APU)** (Phase 4)
   - **Addresses:** APU 5 channels, audio playback (FEATURES.md: "APU audio")
   - **Avoids:** Pitfall 5 (DMC DMA conflicts), Pitfall 10 (frame counter timing), Pitfall 14 (open bus behavior)
   - **Rationale:** DMC DMA conflict with controller reads is a known hardware bug. Must implement ~1.79MHz sample generation → downsample to ~48kHz for Roblox Sound objects.

### 5. **Memory Mappers** (Phase 5)
   - **Addresses:** NROM (Mapper 0), MMC1, MMC3 (FEATURES.md: "Multiple memory mappers")
   - **Avoids:** Pitfall 6 (Mapper IRQ timing), Pitfall 15 (unofficial opcodes if supporting them)
   - **Rationale:** Only after PPU is stable. MMC3 IRQ timing based on PPU scanlines. Test with Battletoads, Mega Man 2.

### 6. **Input System** (Phase 6)
   - **Addresses:** Physical buttons, keyboard input (FEATURES.md: "Controller input")
   - **Avoids:** Pitfall 5 (DMC corruption of controller reads — implement double-read pattern from Super Mario Bros.)
   - **Rationale:** Can parallelize with other phases. Map UserInputService (keyboard) + ClickDetectors (physical buttons) to $4016/$4017 register bits.

### 7. **ROM Loading** (Phase 7)
   - **Addresses:** iNES header parsing, public domain ROMs (FEATURES.md: "Public domain ROM loading")
   - **Avoids:** Pitfall 7 (power-up state assumptions — initialize RAM to random values)
   - **Rationale:** Convert ROMs to Lua tables (bytes). Store in ReplicatedStorage. Start with BombSweeper (public domain).

### 8. **GUI Settings** (Phase 8)
   - **Addresses:** Settings panel, rendering mode toggle (FEATURES.md: "GUI settings panel")
   - **Rationale:** Polish feature. After core emulation is proven stable.

---

## Phase Ordering Rationale

### Why this order?
1. **CPU first** — All other components depend on correct memory reads/writes and interrupt handling.
2. **PPU second** — Graphics are the most complex; must be cycle-accurate. Delays here block rendering.
3. **Rendering third** — Depends on PPU output. Must solve Luau performance early.
4. **Audio fourth** — Independent of rendering; can parallelize with ROM loading.
5. **Mappers fifth** — Needs stable CPU + PPU. MMC3 IRQs require PPU scanline counting.
6. **Input can be anytime** — Simple register writes; can be done during CPU/PPU development.
7. **ROM loading anytime** — Just parsing + memory initialization.
8. **GUI last** — Pure polish; doesn't affect emulation correctness.

### Dependencies:
```
Phase 1 (CPU) → Phase 2 (PPU) → Phase 3 (Rendering)
                        ↓
                   Phase 5 (Mappers)
         ↓
Phase 4 (Audio) ← can parallelize with 2-3
Phase 6 (Input) ← can parallelize with 1-5
Phase 7 (ROM) ← can parallelize with 1-5
Phase 8 (GUI) ← after 3, 6 stable
```

---

## Research Flags for Phases

| Phase | Research Needed? | Reason |
|-------|-------------------|--------|
| Phase 1: CPU | ✅ DONE | Flags, cycle counts, addressing modes verified |
| Phase 2: PPU | ✅ DONE | Timing diagram, register glitches documented |
| Phase 3: Rendering | ⚠️ PARTIAL | Luau `buffer` + SurfaceGui perf untested in project context |
| Phase 4: APU | ✅ DONE | DMC DMA, frame counter timing documented |
| Phase 5: Mappers | ✅ DONE | MMC3 IRQ scanline-based timing documented |
| Phase 6: Input | ⚠️ PARTIAL | Roblox Sound object real-time sample playback untested |
| Phase 7: ROM | ⚠️ PARTIAL | ROM → Lua table conversion approach designed |
| Phase 8: GUI | ✅ LOW RISK | Standard Roblox GUI patterns |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|-----------|-------|
| Stack | **HIGH** | Luau + Roblox native APIs; no alternatives exist |
| Features | **HIGH** | NES hardware is well-documented; project requirements clear |
| Architecture | **HIGH** | Memory-bus pattern standard for emulators; SimpleNES reference available |
| Pitfalls | **HIGH** | NESdev Wiki + developer war stories; verified across multiple sources |
| Roblox specifics | **MEDIUM** | `buffer` + SurfaceGui for NES resolution untested in wild; audio API for APU samples unclear |

---

## Gaps to Address

- [ ] **Benchmark Luau NES emulation speed** — Need proof-of-concept: Can Luau hit 60 FPS for full NES? Run SimpleNES C++ CPU test in Luau, measure time.
- [ ] **Roblox audio API for APU** — How to push dynamically-generated samples to Roblox Sound? May need `buffer` → custom format → Sound object.
- [ ] **SurfaceGui pixel throughput** — Test `buffer` + ImageLabel update rate. 256×240×60 = 3.7M pixel updates/sec. Is this feasible?
- [ ] **Multi-frame emulation** — If Luau can't run full frame in ~16ms, need `task.wait()` chunking strategy.
- [ ] **ROM to Lua table conversion** — Tool to convert `.nes` files to `local rom = {0x4E, ...}` format for Roblox asset storage.

---

## Sources & Verification

### High Confidence (multiple sources, official docs)
- NESdev Wiki (CPU_ALL, PPU_rendering, APU, Errata) — hardware reference
- SimpleNES C++ source code — direct porting reference
- Luau performance docs (luau.org/performance) — official optimization guide
- Roblox Creator Docs — platform API reference

### Medium Confidence (single source or need project-specific validation)
- "pitfalls – how to dumb" (SNES but similar PPU issues)
- NES emulator development guide (newer emulators use similar approaches)
- WebSearch results on Luau optimizations

### Low Confidence (need testing in project context)
- Roblox `buffer` + SurfaceGui for NES-resolution pixel pushing
- APU sample → Roblox Sound object pipeline
- Luau `--!native` flag effectiveness for emulator loops

---

## Recommendations for Orchestrator

1. **Start with CPU phase** — Use `nestest.nes` immediately for validation
2. **PPU must be cycle-accurate** — No shortcuts; use 3:1 clock ratio
3. **Prototype rendering early** — Phase 3 should be a spike/prototype before full implementation
4. **Document all hardware bugs** — PPU Errata page should be open alongside coding
5. **Legal safety** — Only public domain ROMs; state this clearly in UI/instructions
6. **Performance profiling from day 1** — Roblox Studio profiler on every phase

---

*Research completed: 2026-05-03*  
*Researcher: Claude (big-pickle model)*  
*Files created: PITFALLS.md, STACK.md, FEATURES.md, ARCHITECTURE.md, SUMMARY.md*  
*Next step: Orchestrator integrates findings into roadmap (ROADMAP.md)*
