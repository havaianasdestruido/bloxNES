# Architecture Patterns

**Domain:** NES emulator on Roblox (Luau)  
**Researched:** 2026-05-03  
**Project:** bloxNES

---

## Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Roblox Game                              │
│  ┌──────────────────────────────────────────────────┐    │
│  │              bloxNES Emulator                     │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │    │
│  │  │   CPU       │  │   PPU       │  │  APU    │ │    │
│  │  │   (6502)    │◄─┼─►│   (Graphics) │  │  (Audio) │ │    │
│  │  └─────┬───────┘  └─────┬───────┘  └────┬────┘ │    │
│  │        │              │              │       │    │
│  │        ▼              ▼              ▼       │    │
│  │  ┌─────────────────────────────────────────┐  │    │
│  │  │           Memory Bus (Luau table)        │  │    │
│  │  │  RAM │ PPU regs │ APU regs │ Cartridge │  │    │
│  │  └─────────────────────────────────────────┘  │    │
│  │        │                                        │    │
│  │        ▼                                        │    │
│  │  ┌─────────────────────────────────────────┐  │    │
│  │  │         Cartridge / Mapper Logic        │  │    │
│  │  │  PRG-ROM │ CHR-ROM │ SRAM │ Bank switch │  │    │
│  │  └─────────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────┘    │
│                        │                                  │
│                        ▼                                  │
│  ┌──────────────────────────────────────────────────┐    │
│  │         Rendering (SurfaceGui / buffer)          │    │
│  │  Pixel Mode (ImageLabel) │ Part Mode (Frames) │    │
│  └──────────────────────────────────────────────────┘    │
│                        │                                  │
│                        ▼                                  │
│  ┌──────────────────────────────────────────────────┐    │
│  │          Input (Keyboard + Physical Buttons)      │    │
│  │  UserInputService │ ClickDetectors on Parts    │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries

| Component | Responsibility | Communicates With | Data Flow |
|------------|-----------------|---------------------|------------|
| **CPU (6502)** | Execute instructions, manage registers, handle interrupts | Memory Bus, PPU (NMI/IRQ), APU (IRQ) | Read/write memory; signal interrupts to self |
| **PPU (Graphics)** | Generate 256×240 frames, handle sprites/background | Memory Bus, CPU (NMI via PPUSTATUS), Rendering | Read CHR-ROM, nametables; write to frame buffer |
| **APU (Audio)** | Generate audio samples (5 channels), handle IRQs | Memory Bus, CPU (IRQ via $4017) | Write samples to audio buffer |
| **Memory Bus** | Route reads/writes to correct hardware (RAM, PPU, APU, Cartridge) | All components | Unified interface: `bus_read(addr)`, `bus_write(addr, val)` |
| **Cartridge/Mapper** | Bank switching, ROM/RAM access | Memory Bus | Implements `mem_read`/`mem_write` with bank logic |
| **Rendering** | Convert PPU frame buffer to Roblox display | PPU (frame data), SurfaceGui | PPU → buffer → ImageLabel (pixel mode) or Frames (part mode) |
| **Input** | Map Roblox input to NES controller state | CPU (controller registers $4016/$4017) | UserInputService/ClickDetectors → set button bits in CPU memory |

---

## Data Flow

### Per-Frame Execution (Main Loop)

```
1. Run CPU + PPU + APU for one frame (~29780 CPU cycles)
   ├── CPU step: Fetch opcode → Execute → Update cycles
   ├── For each CPU cycle: PPU step ×3 (3:1 ratio)
   └── APU step: Update frame counter, envelope, sweep, length

2. After frame: Render frame
   ├── Pixel Mode: buffer → ImageLabel.Texture
   └── Part Mode: Update Frame objects with pixel colors

3. Poll input: Update $4016/$4017 based on UserInputService/ClickDetectors

4. Audio: APU buffer → Roblox Sound (if ready)

5. Repeat (target 60 FPS)
```

### Memory Map (NES Standard)

| Address Range | Component | Read/Write | Notes |
|---------------|------------|-----------|-------|
| $0000-$07FF | RAM | R/W | 2KB internal RAM (mirrored to $1FFF) |
| $2000-$2007 | PPU registers | R/W | Mirrored to $3FFF |
| $4000-$4013 | APU registers | R/W | Pulse, Triangle, Noise channels |
| $4014 | OAMDMA | Write-only | Sprite DMA from CPU RAM to OAM |
| $4015 | APU status | R/W | Channel enable, frame counter mode |
| $4016-$4017 | Controller ports | R/W | Input (read), Strobe (write) |
| $4020-$FFFF | Cartridge | R/W | PRG-ROM, SRAM, Mapper registers |

---

## Patterns to Follow

### Pattern 1: Memory Bus with Function Callbacks

**What:** Centralized memory access through `bus_read`/`bus_write` functions that route to correct component.

**When:** NES emulation (all components access memory through PPU/APU registers, cartridge mappers).

**Why:** NES hardware uses memory-mapped I/O. Direct function dispatch is faster than table lookups with `if/elseif`.

**Example (Luau):**
```lua
local MemoryBus = {}

-- Component handlers
local RAM = table.create(2048, 0)
local PPU = {}
local APU = {}
local Cartridge = {}

function MemoryBus.read(addr)
    addr = addr & 0xFFFF  -- Mask to 16-bit
    
    if addr < 0x2000 then
        -- RAM (with mirror)
        return RAM[ (addr & 0x07FF) + 1 ]  -- Lua 1-indexed
        
    elseif addr < 0x4000 then
        -- PPU registers
        return PPU.read_register(addr & 0x0007)
        
    elseif addr < 0x4020 then
        -- APU registers
        return APU.read_register(addr)
        
    else
        -- Cartridge (mapper-dependent)
        return Cartridge.read(addr)
    end
end

function MemoryBus.write(addr, value)
    addr = addr & 0xFFFF
    
    if addr < 0x2000 then
        RAM[ (addr & 0x07FF) + 1 ] = value & 0xFF
        
    elseif addr < 0x4000 then
        PPU.write_register(addr & 0x0007, value)
        
    elseif addr < 0x4020 then
        APU.write_register(addr, value)
        
    else
        Cartridge.write(addr, value)
    end
end

return MemoryBus
```

---

### Pattern 2: Cycle-Accurate PPU Clocking

**What:** PPU runs at exactly 3× CPU clock rate. Every CPU cycle triggers 3 PPU "dots".

**When:** PPU rendering, sprite evaluation, scanline timing.

**Why:** Games rely on cycle-accurate PPU for raster effects (Battletoads, Super Mario Bros. split-screen).

**Example (Luau):**
```lua
local PPU = {}
PPU.dot = 0          -- Current dot in scanline (0-340)
PPU.scanline = 0  -- Current scanline (0-261)
PPU.frame_complete = false

function PPU.step()
    -- Update internal PPU state for one dot (1/3 CPU cycle)
    -- Handle background/ sprite fetches, shift registers, etc.
    
    PPU.dot = PPU.dot + 1
    
    if PPU.dot >= 341 then
        PPU.dot = 0
        PPU.scanline = PPU.scanline + 1
        
        if PPU.scanline >= 262 then
            PPU.scanline = 0
            PPU.frame_complete = true
        end
    end
end

-- In CPU step:
function cpu_step()
    local opcode = MemoryBus.read(cpu.PC)
    local cycles = instruction_cycles[opcode]
    
    -- Execute instruction logic...
    
    -- Clock PPU 3 times per CPU cycle
    for i = 1, cycles * 3 do
        PPU.step()
    end
end
```

---

### Pattern 3: Frame-Based Emulation with Catch-Up

**What:** Run CPU for N cycles, then run PPU/APU to catch up (optimization).

**When:** Performance-critical; avoids per-cycle PPU/APU calls.

**Why:** Calling PPU.step() 3× per CPU cycle is expensive in Luau. Batching improves perf.

**Trade-off:** Less accurate timing; may break games relying on mid-instruction PPU/APU effects.

**Recommendation:** Do true cycle-accurate first (Pattern 2); optimize to catch-up later if too slow.

---

### Pattern 4: Mapper as Swappable Module

**What:** Implement each memory mapper as a Lua table with `read`/`write` methods. Swap based on iNES header.

**When:** Supporting multiple NES mappers (NROM, MMC1, MMC3, etc.).

**Why:** Clean separation; easy to add new mappers without modifying core bus logic.

**Example (Luau):**
```lua
local Mappers = {}
Mappers[0] = require(script.MapperNROM)
Mappers[1] = require(script.MapperMMC1)
Mappers[3] = require(script.MapperMMC3)

-- After parsing iNES header:
local mapper_id = header.mapper
Cartridge.mapper = Mappers[mapper_id].new(header)

-- In MemoryBus.read for cartridge space:
function Cartridge.read(addr)
    return Cartridge.mapper.read(addr)
end
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Flat 64KB Memory Table

**What:** `local memory = table.create(65536, 0)` for entire NES address space.

**Why bad:**  
- NES uses memory-mapped I/O (PPU/APU at specific addresses) → need active logic on reads/writes  
- Mapper bank switching would require copying 16KB arrays → slow in Luau  
- No differentiation between RAM, ROM, registers  

**Instead:** Use function-based memory bus (Pattern 1).

---

### Anti-Pattern 2: Per-Pixel SurfaceGui Updates

**What:** Updating individual pixels on SurfaceGui every frame with `Frame` objects or `ImageLabel` pixel-by-pixel.

**Why bad:**  
- 256×240 = 61,440 updates per frame  
- Roblox GUI updates are slow in Luau  
- Will drop far below 60 FPS  

**Instead:** Use `buffer` to build pixel data, push to texture in bulk (Pattern TBD in rendering phase).

---

### Anti-Pattern 3: Creating Tables in Emulation Loop

**What:** `local temp = {}` or `table.insert(t, val)` inside CPU/PPU step functions.

**Why bad:**  
- Table creation = GC pressure  
- Might trigger GC assists in Luau → frame drops  
- NES runs ~60K+ operations per frame  

**Instead:** Pre-allocate all buffers; reuse tables; use `table.create()` with known size.

---

### Anti-Pattern 4: Blocking Main Thread with Heavy Emulation

**What:** Running entire NES frame (~29780 CPU cycles) in one `RenderStepped` callback.

**Why bad:**  
- Luau has ~30ms budget per frame  
- Will trigger "script timeout" errors  
- Blocks Roblox rendering/input  

**Instead:** Use `task.wait()` to split work across frames, or use `--!native` for heavy scripts on server.

---

## Scalability Considerations

| Concern | At 1 game | At 10 games (future) | At 100 games (unlikely) |
|---------|------------|---------------------|----------------------|
| **CPU emulation** | One CPU instance | 10 instances (impactical) | N/A (not happening) |
| **PPU rendering** | One 256×240 framebuffer | 10 framebuffers | N/A |
| **APU audio** | One audio buffer | 10 audio buffers | N/A |
| **ROM storage** | ~100KB PD ROMs | ~1MB (still fine) | ~10MB (use streaming) |

**Note:** bloxNES is single-emulator-instance by design (one console brick). Scalability concerns are minimal.

---

## Roblox-Specific Architecture

### Script Organization (Rojo structure)

```
src/
├── Client/
│   ├── Emulator/
│   │   ├── cpu.lua          -- 6502 CPU
│   │   ├── ppu.lua          -- PPU graphics
│   │   ├── apu.lua          -- APU audio
│   │   ├── memory.lua       -- Memory bus
│   │   ├── cartridge.lua    -- Cartridge loader
│   │   ├── mappers/
│   │   │   ├── nrom.lua
│   │   │   ├── mmc1.lua
│   │   │   └── mmc3.lua
│   │   └── renderer/
│   │       ├── pixel_mode.lua
│   │       └── part_mode.lua
│   ├── Input/
│   │   ├── keyboard.lua    -- UserInputService
│   │   └── buttons.lua     -- Physical button parts
│   ├── UI/
│   │   └── settings_panel.lua
│   └── main.client.lua      -- Entry point, game loop
├── Server/
│   └── (maybe unused for v1; single-player)
└── Shared/
    └── roms/
        └── bombsweeper.lua   -- PD ROM as Lua table
```

**Note:** Use `--!native` flag on CPU, PPU, APU scripts for server-side execution (if running on server). Client-side scripts may not benefit from native compilation.

---

## Sources

- **NESdev Wiki:** PPU rendering, CPU timing, memory map — HIGH confidence
- **SimpleNES C++ architecture:** .planning/codebase/ — HIGH confidence (reference implementation)
- **Luau performance docs:** https://luau.org/performance/ — HIGH confidence
- **Roblox Creator Docs:** Script organization, Rojo — HIGH confidence

---

*Architecture documented: 2026-05-03*  
*Next: SUMMARY.md*
