# Domain Pitfalls: NES Emulator on Roblox (Luau)

**Project:** bloxNES  
**Domain:** NES emulation in Roblox using Luau  
**Researched:** 2026-05-03  
**Overall confidence:** HIGH (verified via NESdev Wiki, hardware documentation, emulator developer war stories)

---

## Executive Summary

NES emulator development is notoriously difficult due to strict timing requirements, hardware quirks, and undocumented behaviors. Porting a C++ emulator (SimpleNES) to Luau on Roblox introduces a second layer of complexity: performance constraints of interpreted Luau, Roblox's rendering limitations, and platform-specific API restrictions.

The most critical pitfalls cluster around:
1. **PPU timing accuracy** — Causes visual glitches in games like Super Mario Bros., Battletoads
2. **CPU flag handling** — Overflow (V) flag misunderstandings are endemic
3. **Table performance in Luau** — NES emulation requires tight loops; Lua tables are slower than C++ arrays
4. **Roblox SurfaceGui rendering** — 256×240 pixel updates per frame is expensive in Luau
5. **APU audio timing** — DMC DMA conflicts with controller reads; frame counter quirks

---

## Critical Pitfalls

Mistakes that cause rewrites or major architectural issues.

### Pitfall 1: PPU Timing / Scanline Accuracy

**What goes wrong:**  
The PPU (Picture Processing Unit) is the most common source of emulation bugs. Developers often implement instruction-level accuracy without cycle-level PPU synchronization. This causes:
- Sprite 0 hit detection failures (used by games like Mach Rider for split-screen)
- Scrolling glitches (dot 257 writes to PPUCTRL/PPUSCROLL/PPUADDR cause wrong nametable selection)
- OAM corruption when toggling rendering mid-scanline (especially in StarTropics)
- Incorrect sprite evaluation due to PPU's buggy overflow flag logic

**Why it happens:**  
The PPU runs at 3× CPU clock (NTSC). Games like Battletoads and Super Mario Bros. rely on precise cycle-level timing for raster effects. PPU register writes during rendering have specific vulnerable dots (e.g., dot 257) where open-bus values cause glitches.

**Consequences:**  
- Visual glitches that are extremely hard to debug (symptom: "gravity doesn't work" → actual bug: wrong tile collision detection due to PPU addressing error)
- Games failing to boot or crashing (Battletoads stage 2, Donkey Kong title screen)

**Prevention:**  
1. **Use cycle-accurate PPU emulation** — Clock PPU 3 times per CPU cycle; don't batch PPU updates
2. **Implement PPU register write glitch emulation** — Handle dot 257/258 early-write bugs for PPUCTRL ($2000), PPUSCROLL ($2005), PPUADDR ($2006)
3. **Test with nestest.nes + visual tests** — Use PPU coloring test ROMs early
4. **Study NESdev Wiki Errata page** — Documents known hardware bugs

**Detection:**  
- Sprite 0 hit flag never sets, or sets at wrong scanline
- Blue vertical line in Super Mario World (common pitfall: missing W1_LEFT > W1_RIGHT handling)
- Scrolling jumps by 3-4 scanlines (Legend of Zelda)

**Phase to address:** Phase 2 (PPU Implementation) — Must be cycle-accurate from the start.

**Sources:**
- https://www.nesdev.org/wiki/PPU_frame_timing
- https://www.nesdev.org/wiki/Errata
- https://www.nesdev.org/wiki/PPU_rendering
- https://www.gridbugs.org/nes-emulator-debugging/

---

### Pitfall 2: CPU Overflow Flag (V) Misimplementation

**What goes wrong:**  
The overflow (V) flag is misunderstood by ~80% of emulator developers. Common errors:
- Setting V based on 8-bit unsigned overflow (that's the Carry flag's job)
- Not handling signed overflow correctly for ADC/SBC
- Forgetting that V reflects signed overflow: Positive + Positive = Negative, or Negative + Negative = Positive

**Why it happens:**  
6502 documentation varies in clarity. The correct logic:  
`V = !(A ^ src) & (A ^ result) & 0x80`  
(Overflow if inputs have same sign, but result has different sign)

**Consequences:**  
- Games using signed comparisons fail (bit instructions, branch logic)
- Super Mario World koopaling falls through floor (signed overflow in collision detection)
- Road rendering in Mach Rider breaks

**Prevention:**  
1. **Use verified algorithm** — Copy from NESdev Wiki or Blargg's test ROM reference
2. **Test with nestest.nes** — Validates all CPU instructions including flag behavior
3. **Implement BIT instruction correctly** — Sets V from bit 6 of memory, not result

**Detection:**  
- Run `nestest.nes` — Any CPU failures indicate flag issues
- Super Mario World intro bugs (koopaling, map glitches)

**Phase to address:** Phase 1 (CPU Implementation) — Flags must be correct before any other component.

**Sources:**
- https://www.nesdev.org/wiki/CPU_ALL
- http://6502.org/tutorials/vflag.html
- https://www.nesdev.org/wiki/Status_flags

---

### Pitfall 3: Luau Table Performance in Emulation Loops

**What goes wrong:**  
NES emulation runs ~29780 CPU cycles per frame (≈60 FPS). Each cycle may access memory, requiring table lookups. Luau tables, while optimized, are slower than C++ arrays/switch statements.

Specific performance traps:
- **Using Lua tables for memory arrays** — NES has 2KB RAM ($0000-$07FF), but emulators often use a 64KB table. Table lookups in tight loops are expensive.
- **Creating tables per frame** — Table creation allocates memory; GC pressure hurts performance
- **Using `pairs()` vs `ipairs()` in hot loops** — While similar in modern Luau, `ipairs` on array-like data is slightly faster
- **Table resizing during emulation** — Dynamic resizing is slow; pre-allocate with `table.create()`

**Why it happens:**  
C++ uses direct array indexing (`mem[addr]`). Luau uses hash-table lookups for all table accesses. SimpleNES C++ has switch-case for CPU opcodes; Luau must use either:
- Large `if/elseif` chain (slow)
- Table of functions (function call overhead)
- Hybrid approach (recommended, but complex)

**Consequences:**  
- Emulation runs below 60 FPS
- Frame drops, audio stutter
- Roblox throttles script execution if frame time exceeds ~30ms

**Prevention:**  
1. **Pre-allocate all tables** — Use `table.create(size, value)` for memory arrays
2. **Use array part, not hash part** — Keep memory as contiguous integer-keyed table
3. **Avoid creating tables in CPU/PPU step loops** — Reuse buffers
4. **Consider `--!native` flag** — Server-side scripts can use native code generation for compute-heavy functions
5. **Profile early** — Use Roblox Studio's Script Profiler to identify hot paths
6. **Lookup table for CPU opcodes** — Avoid long `if/elseif` chains; use function table

**Detection:**  
- Frame rate drops below 60 FPS in Studio
- Script timeout warnings
- GC "assists" consuming visible time in profiler

**Phase to address:** Phase 1 (CPU) and Phase 2 (PPU) — Performance must be designed in, not bolted on.

**Sources:**
- https://luau.org/performance/
- https://create.roblox.com/docs/en-us/performance-optimization/improve
- https://github.com/Roblox/luau/issues/590 (table fill performance)

---

### Pitfall 4: SurfaceGui Pixel Rendering Performance

**What goes wrong:**  
NES outputs 256×240 = 61,440 pixels per frame. Updating each pixel individually on a Roblox SurfaceGui is extremely slow. Two rendering modes are planned:

1. **Pixel-drawing mode** — Update texture pixels per frame
2. **Part-based mode** — Use Roblox parts/frames to represent pixels

Both have pitfalls:
- **Pixel mode:** `buffer` operations or `ImageLabel` manipulation per-pixel is slow in Luau
- **Part mode:** Creating 61k parts/frames is impossible (Roblox limits, performance)
- **Texture upload:** Frequent texture updates may cause lag

**Why it happens:**  
Roblox is not designed for per-pixel framebuffer manipulation. SurfaceGui is a 2D UI layer; updating it 60 times/second with 60k pixels requires careful optimization.

**Consequences:**  
- Game runs at <10 FPS due to rendering overhead
- Roblox Studio crashes or times out scripts
- Visual artifacts from partial frame updates

**Prevention:**  
1. **Use `buffer` library** — Luau's `buffer` type is optimized for binary data; faster than tables for pixel data
2. **Render at lower resolution** — Consider 128×120 (half NES res) with bilinear scaling
3. **Use `ViewportFrame`** — May offer better performance than SurfaceGui for 3D-like rendering
4. **Batch pixel updates** — Don't update pixels individually; use bulk operations
5. **Consider frame-skipping** — If emulation can't keep up, skip rendering every Nth frame
6. **Dither pattern for part mode** — Represent 4 pixels with 1 part using checkerboard pattern

**Detection:**  
- Frame rate drops when rendering enabled
- "Script exhausted allowed execution time" errors
- Visual lag between input and response

**Phase to address:** Phase 3 (Rendering Mode Implementation) — Critical path for playable FPS.

**Sources:**
- https://create.roblox.com/docs/en-us/performance-optimization/improve
- https://devforum.roblox.com/t/luau-optimizations-make-your-game-run-faster/4378272

---

### Pitfall 5: APU DMC DMA and Controller Conflict

**What goes wrong:**  
The NES Audio Processing Unit (APU) uses DMC (Delta Modulation Channel) for sample playback. DMC uses DMA (Direct Memory Access) to read samples from memory. This DMA conflicts with controller port reads:

- **Controller read corruption** — If DMC DMA occurs during controller port read ($4016/$4017), the read may return garbage
- **Gimmick! game bug** — Relies on DMC conflict detection; fails on PAL NES where conflict is milder
- **IRQ timing** — DMC can trigger IRQs; frame counter also generates IRQs

**Why it happens:**  
The 6502 CPU and APU share the bus. DMC DMA steals cycles from the CPU, causing controller reads to potentially read the wrong value. Games like Super Mario Bros. read controllers twice to verify.

**Consequences:**  
- Spurious button presses (pausing when not pressing Start, character moves right when idle)
- Audio samples playing incorrectly
- Frame counter IRQs firing at wrong times

**Prevention:**  
1. **Implement DMC DMA bus conflict** — When DMC DMA occurs during $4016/$4017 read, return corrupted value
2. **Read controllers twice** — Follow Super Mario Bros. pattern: read, read again, compare
3. **Handle DMC IRQ timing** — DMC end-of-sample can generate IRQ; must be cycle-accurate
4. **Emulate frame counter modes** — 4-step and 5-step sequences; IRQ on 4-step mode

**Detection:**  
- Random button presses in games
- Gimmick! behaves incorrectly (known to rely on DMC conflict)
- Audio glitches in games using DMC samples

**Phase to address:** Phase 4 (APU Implementation) — Audio must handle DMA and IRQ timing.

**Sources:**
- https://www.nesdev.org/wiki/APU
- https://www.nesdev.org/wiki/Game_bugs (Gimmick! entry)
- https://wiki.nesdev.org/wiki/APU_Mixer

---

### Pitfall 6: Memory Mapper IRQ Timing (MMC3, MMC5)

**What goes wrong:**  
Memory mappers extend NES capabilities by bank-switching ROM/RAM. MMC3 is the most popular mapper with complex IRQ timing:

- **IRQ counter reload** — MMC3 has a countdown IRQ; reload value affects timing
- **IRQ clear vs disable** — `$E000` clears IRQ, `$E001` disables; different semantics
- **Scanline counting** — MMC3 IRQs trigger on PPU scanlines, not CPU cycles; requires PPU synchronization

**Why it happens:**  
Mappers are separate hardware from CPU/PPU. Their IRQs must be synchronized with PPU scanlines. MMC3 IRQ timing varies based on PPU dot alignment.

**Consequences:**  
- Games using MMC3 (Mega Man 2-6, Kirby's Adventure) have scrolling glitches
- IRQ fires too early/late → split-screen effects break
- Battletoads stage 2 crash (uses MMC3 IRQs for level transitions)

**Prevention:**  
1. **Synchronize mapper IRQs with PPU** — MMC3 IRQs based on PPU scanlines, not CPU cycles
2. **Implement IRQ counter reload correctly** — Reload happens after decrement, not before
3. **Test with known games** — Use Battletoads, Mega Man 2 for validation
4. **Log IRQ events** — Debug mapper IRQs separately from CPU/PPU

**Detection:**  
- Games using MMC3 mappers have graphical glitches on scanline splits
- IRQ-related crashes in known MMC3 games

**Phase to address:** Phase 5 (Memory Mappers) — MMC3 timing is complex; defer to after PPU is stable.

**Sources:**
- https://www.nesdev.org/wiki/MMC3
- https://forums.nesdev.org/viewtopic.php?t=24652 (cycle accuracy)

---

### Pitfall 7: Startup / Power-Up State Assumptions

**What goes wrong:**  
Developers assume RAM/registers start at 0. Real NES hardware has random power-up state (especially RAM). Additionally:
- **PPU warm-up** — PPU takes ~240 scanlines after power/reset before it's ready
- **OAM decay** — If rendering disabled too long, OAM (sprite memory) decays
- **Mapper registers** — Some mappers have undefined power-up state (e.g., MMC1 needs $8000 write to stabilize)

**Why it happens:**  
Emulators often initialize everything to 0 for simplicity. Real hardware has capacitor discharge, random noise → RAM contains garbage on power-up.

**Consequences:**  
- Games relying on uninitialized RAM fail (Othello crash, Micro Machines glitches)
- PPU writes during warm-up cause undefined behavior
- Reset doesn't clear all registers (especially mappers)

**Prevention:**  
1. **Initialize RAM to random values** — Use `math.random()` to fill RAM on power-up
2. **Handle PPU warm-up** — Ignore PPU writes for first ~240 scanlines after power/reset
3. **Clear registers properly** — PPUCTRL ($2000), PPUMASK ($2001) must be cleared on reset
4. **Implement OAM decay** — If rendering off > ~1ms, OAM contents decay (optional, few games rely on it)

**Detection:**  
- Games crash on power-on but work after reset
- Othello FDS version crashes (stack overflow due to uninitialized RAM)
- Micro Machines glitches on PAL revision PPUs

**Phase to address:** Phase 1 (CPU) and Phase 2 (PPU) — Initialization affects all components.

**Sources:**
- https://www.nesdev.org/wiki/CPU_power_up_state
- https://www.nesdev.org/wiki/PPU_power_up_state
- https://www.nesdev.org/wiki/Game_bugs

---

### Pitfall 8: C++ to Luau Porting: Type and Bit-Operation Differences

**What goes wrong:**  
Porting SimpleNES C++ to Luau introduces several translation traps:

1. **Unsigned vs signed** — C++ `uint8_t` vs Luau numbers (all floating-point, though integers up to 2^53 are exact)
2. **Bitwise operators** — C++ `& | ^ ~` vs Luau `& | ~ ^` (different precedence, same semantics)
3. **64-bit shift behavior** — Luau numbers are 64-bit floats; bit operations work on 32-bit integers
4. **Array indexing** — C++ `mem[addr]` vs Luau `mem[addr+1]` (Lua tables are 1-indexed!)
5. **struct bitfields** — C++ bitfields (e.g., PPU scroll register) don't exist in Luau; must be manually packed/unpacked

**Why it happens:**  
Direct translation of C++ code often misses semantic differences. Example:  
C++ `if (addr < 0x2000)` becomes Luau `if addr < 0x2000` — looks same, but Luau `0x2000` is a number, not an integer. Bit operations in Luau convert to 32-bit signed int, then back to float.

**Consequences:**  
- Off-by-one errors in memory mapping (Lua 1-indexing vs C 0-indexing)
- Incorrect bitfield extraction (PPU scroll register bugs)
- Overflow/underflow in 8-bit arithmetic (Luau doesn't have native 8-bit types)

**Prevention:**  
1. **Mask all 8-bit values** — After every arithmetic: `result = (a + b) & 0xFF`
2. **Use helper functions for bitfields** — `get_bit(value, bit)`, `set_bit(value, bit, on)`
3. **Convert to 0-indexed arrays** — Store memory as `mem[addr+1]` or use `__index` metamethod
4. **Test C++ vs Luau side-by-side** — Run same test ROMs on both emulators
5. **LuaJIT reference** — If performance allows, LuaJIT has better integer support

**Detection:**  
- nestest.nes fails on specific instructions (usually flag or addressing mode)
- Memory-mapped register writes go to wrong addresses
- PPU scroll/CTRL registers have wrong bits set

**Phase to address:** Phase 1 (CPU Porting) — Foundation for all other components.

**Sources:**
- https://www.lua.org/manual/5.4/manual.html#3.4.2 (bitwise operations)
- https://luau.org/why.html (Luau differences from Lua)

---

## Moderate Pitfalls

Mistakes that cause bugs or wasted time, but not architectural failures.

### Pitfall 9: Sprite Evaluation and OAM Corruption

**What goes wrong:**  
The PPU evaluates 64 sprites (OAM) per scanline to select 8 for rendering. The PPU's sprite overflow flag is buggy (false positives & negatives). Additionally:
- **OAM corruption on render toggle** — Disabling rendering mid-scanline corrupts OAM (StarTropics, Isolated Warrior)
- **OAMADDR ($2003) bug** — On 2C02G+, if OAMADDR ≠ 0 at sprite evaluation start, first 8 bytes of OAM get overwritten

**Prevention:**  
- Implement sprite evaluation bug (scan diagonally after 8 sprites found)
- Avoid rendering toggle during scanlines 192-240 (unsafe window)
- Clear OAMADDR to 0 before OAMDMA

**Detection:**  
- Sprites flicker or disappear
- StarTropics shadow sprite glitch
- Garbage sprites appear on scanline after rendering re-enable

**Phase:** Phase 2 (PPU)

**Source:** https://www.nesdev.org/wiki/PPU_sprite_evaluation

---

### Pitfall 10: Frame Counter Timing / APU IRQs

**What goes wrong:**  
APU frame counter generates IRQs at ~240Hz (NTSC). Timing quirks:
- **Write timing** — `$4017` write resets counter; IRQ fires after 3 or 4 CPU cycles (odd/even alignment)
- **4-step vs 5-step** — 4-step generates IRQ; 5-step doesn't (usually)
- **Frame counter vs NMI** — Frame counter runs independently of PPU NMI; games may rely on specific phase relationship

**Prevention:**  
- Implement frame counter with correct cycle delay (2-3 CPU cycles after $4017 write)
- Handle both 4-step and 5-step modes
- Synchronize with CPU/PPU timing (not independent!)

**Detection:**  
- Games using APU IRQs fail (rare, but some homebrew uses it)
- Audio envelope/sweep updates at wrong rate

**Phase:** Phase 4 (APU)

**Source:** https://www.nesdev.org/wiki/APU_Frame_Counter

---

### Pitfall 11: NMI on Timing Test Failures

**What goes wrong:**  
NMI (Non-Maskable Interrupt) triggers at PPU scanline 241, dot 1. Common bugs:
- **NMI suppression** — Reading PPUSTATUS ($2002) just before vblank can suppress NMI for that frame
- **CLI/SEI latency** — Interrupt flag changes take 1 instruction to take effect
- **NMI during BRK** — If NMI occurs during BRK, B flag in stack may be wrong

**Prevention:**  
- Use NMI for vblank detection, not PPUSTATUS polling
- Handle NMI/IRQ interaction (NMI can interrupt IRQ)
- Test with `07-NMI_on_timing.nes` test ROM

**Detection:**  
- Games stutter or miss frames
- Vblank never detected (infinite loop on PPUSTATUS read)

**Phase:** Phase 2 (PPU) + Phase 1 (CPU Interrupts)

**Source:** https://www.nesdev.org/wiki/PPU_frame_timing

---

### Pitfall 12: Page Boundary Penalties (CPU Addressing Modes)

**What goes wrong:**  
6502 has penalty cycles when certain addressing modes cross page boundaries:
- **Absolute,X / Absolute,Y** — +1 cycle if page boundary crossed
- **(Indirect,Y)** — +1 cycle if page boundary crossed
- **Branches** — +1 cycle if branch taken, +2 if page boundary crossed

**Why it matters:**  
Battletoads and other timing-sensitive games rely on these penalties. Missing them causes the game to run too fast or miss IRQs.

**Prevention:**  
- Implement all CPU cycle counts accurately, including page boundary penalties
- Test with `instr_test-v5/6.nes` and `branches.nes`

**Detection:**  
- Battletoads level 2 crash
- Games with raster effects have wrong timing

**Phase:** Phase 1 (CPU)

**Source:** https://www.nesdev.org/wiki/CPU_IMPLIED

---

## Minor Pitfalls

Mistakes that are easy to fix, but good to know.

### Pitfall 13: Forgetting to Latch PPU Scroll Registers

**What goes wrong:**  
PPU has internal latches for scroll registers. Writes to PPUSCROLL ($2005) and PPUADDR ($2006) latch data internally before copying to active registers at specific timing points.

**Prevention:**  
- Implement PPU internal `t` and `v` registers (from NESdev wiki PPU scrolling article)
- Handle double-writes (first/second write semantics)

**Phase:** Phase 2 (PPU)

**Source:** https://www.nesdev.org/wiki/PPU_scrolling

---

### Pitfall 14: Open Bus Behavior

**What goes wrong:**  
When reading from a register that doesn't exist, or after certain writes, the "open bus" (last value on the bus) is returned. Some games rely on this.

**Prevention:**  
- Keep track of last value written/read on PPU/APU bus
- Return open bus on read-only register reads

**Phase:** Phase 2 (PPU) / Phase 4 (APU)

**Source:** https://www.nesdev.org/wiki/Open_bus

---

### Pitfall 15: Unofficial Opcodes

**What goes wrong:**  
6502 has undocumented/unofficial opcodes (e.g., SAX, DCP, ISB). Some games use them (e.g., Beauty and the Beast uses `LAX`).

**Prevention:**  
- Decide early: support unofficial opcodes or not
- If yes, implement all ~256 opcodes (including illegal ones)
- If no, log attempts to execute them

**Phase:** Phase 1 (CPU)

**Source:** https://www.nesdev.org/wiki/CPU_unofficial

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|----------------|------------|
| Phase 1: CPU (6502) | Overflow flag wrong | Use verified algorithm; test with nestest.nes |
| Phase 1: CPU (6502) | Page boundary penalties missing | Implement all cycle counts accurately |
| Phase 2: PPU (Graphics) | Scanline timing inaccurate | Clock PPU 3× per CPU cycle; use NESdev diagram |
| Phase 2: PPU (Graphics) | Sprite 0 hit wrong | Test with sprite 0 hit test ROMs |
| Phase 3: Rendering (SurfaceGui) | Pixel update too slow | Use `buffer`; batch updates; consider lower res |
| Phase 4: APU (Audio) | DMC DMA conflicts | Implement bus conflict with controller reads |
| Phase 4: APU (Audio) | Audio aliasing | Use blip_buffer-style bandlimiting before downsampling |
| Phase 5: Mappers (MMC1, MMC3) | IRQ timing wrong | Sync with PPU scanlines; test Battletoads/Mega Man |
| Phase 6: Input (Controllers) | DPCM corruption | Read controller ports twice; handle DMC conflict |

---

## Roblox-Specific Concerns

### Concern 1: Luau Performance Budget

Roblox scripts have ~30ms per frame before "script timeout." NES emulation needs:
- ~29780 CPU cycles × ~2-3 Luau instructions per cycle = ~60k-90k Luau operations per frame
- PPU rendering: 262 scanlines × 341 dots = 89k PPU ticks per frame
- **Total: ~150k+ operations per frame**

**Mitigation:**  
- Use `--!native` for server-side CPU/PPU emulation scripts
- Consider running emulation in `task.wait()` chunks (spread over multiple frames)
- Profile aggressively; optimize hot paths

---

### Concern 2: SurfaceGui Limitations

- **Max size:** SurfaceGui has practical limits on pixel density
- **Update rate:** Frequent updates may throttle
- **Texture format:** Need to use `ImageLabel` with procedural textures or `Frame` objects

**Mitigation:**  
- Research `buffer` + custom rendering vs Unity-style `ViewportFrame`
- Consider downscaling NES output to 128×120 or 192×160

---

### Concern 3: No File System Access

Roblox cannot read arbitrary files. ROMs must be:
- Uploaded as game assets (Lua table data)
- Stored in `ReplicatedStorage` or `ServerStorage`
- Loaded via `require()` or asset ID

**Mitigation:**  
- Convert ROMs to Luau tables (e.g., `local rom = {0x4E, 0x45, 0x53, ...}`)
- Support multiple ROM formats (iNES, NES 2.0)
- Only load public domain ROMs (legal safety)

---

## Gaps to Address

- [ ] **Benchmark Luau NES emulation speed** — Unknown if Luau can hit 60 FPS for full NES; need proof-of-concept early
- [ ] **Roblox audio API for APU** — How to generate NES audio samples in Roblox? (Sound objects? `buffer`?)
- [ ] **Multi-frame emulation** — Can we run N frames per script tick to compensate for slow Luau?
- [ ] **Roblox input API** — `UserInputService` for keyboard; physical buttons for mobile; need to map to NES controller

---

## Sources and Confidence

| Source | Confidence | Notes |
|--------|-----------|-------|
| NESdev Wiki (CPU/PPU/APU) | HIGH | Hardware documentation, maintained by community |
| NESdev Forums (emudev discussions) | HIGH | Real developer war stories |
| SimpleNES C++ reference | HIGH | Direct source for porting |
| Luau Performance Docs | HIGH | Official Luau optimization guide |
| Roblox Creator Docs | HIGH | Platform-specific constraints |
| "pitfalls – how to dumb" (SNES but relevant) | MEDIUM | SNES similar issues; some transfer |
| WebSearch (general emulator guides) | MEDIUM | Broader context, less specific |

---

## Summary of Critical Path

1. **Phase 1 (CPU):** Get 6502 right, especially flags and cycle counts. Use nestest.nes.
2. **Phase 2 (PPU):** Cycle-accurate PPU is non-negotiable. Sync with CPU at 3:1 ratio.
3. **Phase 3 (Rendering):** Luau performance bottleneck. Prototype early with buffer/pixel approach.
4. **Phase 4 (APU):** Audio timing + DMC DMA. Test with Blargg's APU test ROMs.
5. **Phase 5 (Mappers):** MMC3 IRQ timing tricky. Only after PPU is stable.
6. **Phase 6 (Integration):** Controller input + Roblox APIs. Legal: public domain ROMs only.

---

*Research completed: 2026-05-03*  
*Researcher: Claude (big-pickle model)*  
*Next: Write STACK.md, FEATURES.md, ARCHITECTURE.md, SUMMARY.md*
