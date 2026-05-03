# Technology Stack

**Project:** bloxNES  
**Researched:** 2026-05-03  
**Domain:** NES emulator on Roblox (Luau)

---

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Luau** | Roblox Lua 5.1+ derivative | Scripting language for entire emulator | Required — Roblox only runs Luau; optimized interpreter; supports `--!native` for hot paths |
| **Roblox Engine** | Latest (auto-updated) | Platform runtime, rendering, input, audio | Only deployment target; provides SurfaceGui, UserInputService, Sound objects |

### Emulation Core
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **SimpleNES C++ (reference)** | N/A (existing src/) | Reference implementation for porting | Already mapped (.planning/codebase/); complete NES implementation (CPU, PPU, APU, Mappers) |
| **Custom Luau NES core** | N/A (to be built) | Ported emulator logic in Luau | Must be written from scratch in Luau; no Lua/NES libraries exist |

### Rendering
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **SurfaceGui** | Roblox native | Display NES screen on brick face | Project requirement: "NES screen rendered on a brick via SurfaceGui" |
| **buffer (Luau native)** | Built-in | Efficient binary data for pixel buffers | Faster than tables for 256×240 pixel data; avoids GC pressure |
| **ViewportFrame** | Roblox native (alternative) | 3D-ish rendering option | May offer better perf than SurfaceGui for pixel updates; good fallback |
| **ImageLabel** | Roblox native | Display pre-rendered texture | Option for pixel mode: update texture via buffer → push to ImageLabel |

### Input
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **UserInputService** | Roblox native | Keyboard input for PC players | Project requirement: "Keyboard input support via UserInputService" |
| **BasePart (buttons)** | Roblox native | Physical button parts as NES controller | Project requirement: "Physical button parts as NES controller (A, B, Start, Select, D-pad)" |
| **ClickDetectors** | Roblox native | Detect clicks on button parts | Attach to button parts for mouse/touch input |

### Audio
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Sound objects** | Roblox native | Play APU-generated audio samples | Project requirement: "Audio playback via Roblox sound objects" |
| **buffer (Luau native)** | Built-in | Generate/store audio sample data | APU outputs samples; buffer is efficient for real-time audio data |

### Development Tools
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Rojo** | Latest | Sync filesystem ↔ Roblox Studio | Project already uses it; required for development workflow |
| **Roblox Studio** | Latest | IDE, testing, deployment | Required to run/test emulator; only way to test on platform |

---

## Architecture Decisions

### Memory Representation
**Decision:** Use Luau tables with integer keys for NES memory mapping.

| Memory Region | Luau Representation | Size | Notes |
|---------------|---------------------|------|-------|
| RAM ($0000-$07FF) | `table.create(2048, 0)` | 2KB | Use array part; pre-allocate |
| PPU registers ($2000-$2007) | Separate table or memory-mapped | 8 regs | Handle via memory read/write callbacks |
| APU registers ($4000-$4017) | Separate table or memory-mapped | 24 regs | Include expansion audio range |
| Cartridge PRG-ROM | `table.create(size, 0)` | 16-32KB+ | Load from ROM data (Lua table of bytes) |
| Cartridge CHR-ROM | `table.create(size, 0)` | 8KB+ | For character/graphics data |
| OAM (Sprite memory) | `table.create(256, 0)` | 256 bytes | Primary sprite memory |
| Secondary OAM | `table.create(32, 0)` | 32 bytes | PPU internal for sprite evaluation |

**Why not flat 64KB table?**  
SimpleNES C++ uses flat array; but Luau tables with function-based memory mapping allow proper bank switching for mappers without copying 16KB arrays constantly.

---

### CPU Emulation
**Approach:** Switch-case on opcode (0-255), with function table for faster dispatch.

```lua
-- Pseudo-code for opcode dispatch
local CPU_OPS = {}
CPU_OPS[0x00] = function() -- BRK
    -- implementation
end
CPU_OPS[0x01] = function() -- ORA (IndirectX)
    -- implementation
end
-- ... 256 entries

function cpu_step()
    local opcode = mem_read(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    CPU_OPS[opcode]()  -- Fast function call
end
```

**Performance note:** Luau's `table.create()` + function table is faster than `if/elseif` chains for 256 opcodes.

---

### PPU Emulation
**Approach:** Cycle-accurate, clocked 3× per CPU cycle.

```lua
function ppu_step()
    -- Single PPU dot (pixel)
    -- Update internal state, shift registers, etc.
end

function cpu_step()
    -- Execute one CPU instruction (may take 2-7 cycles)
    local cycles = instruction_cycles[opcode]
    for i = 1, cycles do
        ppu_step() ppu_step() ppu_step()  -- 3 PPU dots per CPU cycle
    end
end
```

**Rendering approach (two modes):**
1. **Part-based mode:** Create Roblox Frames sized to represent pixels (heavy, but visual)
2. **Pixel-drawing mode:** Use `buffer` to build pixel data, push to SurfaceGui ImageLabel texture

---

### APU Emulation
**Approach:** Generate samples at ~1.79MHz, downsample to ~48kHz for Roblox Sound.

- Use `buffer` for sample accumulation
- Implement blip_buffer-style bandlimited synthesis (avoid aliasing)
- Output: Buffer of samples → Roblox Sound object (may need to batch)

**Challenge:** Roblox audio API expects Sound objects with pre-made assets; generating real-time audio from Luau is unexplored. May need to:
- Pre-generate audio clips for simple beeps
- Use `Sound.Playing = true` with procedural buffers (if API allows)
- Fallback: Simple tone generation for v1, full APU for v2

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **Language** | Luau | JavaScript (via Roblox TS) | Luau is native; TS adds complexity; perp is similar |
| **Rendering** | SurfaceGui + buffer | ViewportFrame | SurfaceGui is project requirement; ViewportFrame is backup |
| **CPU dispatch** | Function table | If/elseif chain | Function table faster for 256-entry table |
| **Memory** | Table with callbacks | Flat 64KB table | Flat table too slow for bank switching |
| **Audio** | Buffer + Luau synth | External audio files | Must generate from APU; files won't capture dynamic audio |

---

## Installation / Setup

```bash
# Already in project (from PROJECT.md):
# 1. Install Rojo
# (Follow Rojo installation guide)

# 2. Serve project
rojo serve

# 3. In Roblox Studio: Connect to Rojo server

# No additional dependencies! 
# - Luau is built into Roblox
# - No third-party Luau libraries needed
# - All emulation code written from scratch
```

---

## Key Performance Considerations

| Concern | Impact | Mitigation |
|----------|--------|------------|
| **Luau speed** | HIGH | Use `--!native` on CPU/PPU scripts; use buffer; avoid table creation in hot loops |
| **256×240 pixel updates** | HIGH | Use buffer + ImageLabel; batch updates; consider 128×120 scaled |
| **APU sample generation** | MEDIUM | Downsample aggressively; may need frame-based audio chunks |
| **Memory mapping overhead** | MEDIUM | Pre-allocate tables; use integer keys (array part); avoid hash lookups |
| **Mapper bank switching** | LOW | Use function-based memory mapping; avoid copying large tables |

---

## Sources

- **Context7/NESdev Wiki:** CPU_ALL, PPU_rendering, APU — HIGH confidence (hardware reference)
- **Luau performance docs:** https://luau.org/performance/ — HIGH confidence (official)
- **Roblox Creator Docs:** SurfaceGui, UserInputService, Sound — HIGH confidence (official)
- **SimpleNES C++ source:** src/SimpleNES/ — HIGH confidence (direct reference)
- **Project PROJECT.md:** Requirements, constraints — HIGH confidence (project spec)

---

*Stack researched: 2026-05-03*  
*Next: FEATURES.md, ARCHITECTURE.md, SUMMARY.md*
