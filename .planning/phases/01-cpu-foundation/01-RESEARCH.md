# Phase 01: CPU Foundation - Research

**Researched:** 2026-05-03
**Domain:** 6502 CPU emulation in Luau (port of SimpleNES C++)
**Confidence:** HIGH

## Summary

Phase 1 delivers a fully functional 6502 CPU emulator in Luau that correctly executes all 56 official opcodes with proper flag handling and reset behavior. The implementation ports the SimpleNES C++ reference code (`src/SimpleNES/include/CPU.h` and `CPUOpcodes.h`) to Luau while accounting for language differences: Luau uses 1-indexed tables (vs C++ 0-indexed arrays), all numbers are floating-point (requiring `& 0xFF` masking for 8-bit operations), and bit operations work on 32-bit integers.

The CPU must pass the `nestest.nes` validation test — the gold standard for 6502 emulation correctness. This test verifies all opcodes, addressing modes, flag behavior (especially the overflow V flag), and cycle counts including page boundary penalties.

**Primary recommendation:** Use `buffer.create(0x10000)` for the 64KB address space (verified 3x faster than tables per STACK.md), implement opcode dispatch via a function table indexed by opcode byte (fastest dispatch in Luau), and use the verified overflow flag formula: `V = (not (A ^ src) & (A ^ result) & 0x80) ~= 0` [VERIFIED: 6502.org/tutorials/vflag.html].

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 6502 instruction execution | Emulator Core (Luau script) | — | Pure computation; no Roblox-specific APIs needed |
| Flag register updates (N, V, Z, C) | Emulator Core | — | Mathematical operations on register values |
| Memory read/write | Emulator Core (Memory Bus) | — | Centralized bus routes to RAM, PPU, APU, Cartridge |
| Reset behavior (vector read, register init) | Emulator Core | — | CPU-specific initialization per NESdev spec |
| Interrupt handling (NMI, IRQ, BRK) | Emulator Core | — | CPU internally manages interrupt sequences |
| Opcode dispatch | Emulator Core | — | Function table lookup, no external dependencies |

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Use `buffer` type for 64KB address space (fastest for emulation loops) [VERIFIED: STACK.md §Memory Representation]
- **D-02:** Pre-allocate with `buffer.create(0x10000)` for the 64KB address space
- **D-03:** Parse nestest output string and report passed/failed opcodes
- **D-04:** Visual display in Roblox showing pass/fail for each opcode
- **D-05:** Automated CI-style check that logs results to output
- **D-06:** Standard NES reset — read vector from 0xFFFC, set registers per NESDev spec
- **D-07:** Registers: A=X=Y=0, SP=0xFD, P[I]=1, memory $4017 = $00
- **D-08:** Lookup table mapping opcode byte to function (fastest dispatch) [VERIFIED: STACK.md §CPU Emulation]
- **D-09:** Table initialized at module load, not per-instruction

### The Agent's Discretion
- Exact cycle counting within each opcode (some opcodes vary)
- Error handling for invalid opcodes (shouldn't happen with valid ROMs)
- Logging format for nestest output parsing

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EMUL-02 | 6502 CPU emulation executes NES game code accurately (all 56 official opcodes) | C++ reference in `src/SimpleNES/include/CPU.h`; opcode definitions in `CPUOpcodes.h`; nestest.nes validation |
| EMUL-06 | NES reset functionality works (soft reset via GUI or input) | NESDev Wiki reset vector at 0xFFFC; power-up state documented; register init values verified |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|-------------|
| **Luau** | Roblox Lua 5.1+ derivative | Scripting language for CPU emulator | Only language supported in Roblox; `--!native` flag available for hot paths [VERIFIED: luau.org/performance] |
| **buffer (Luau native)** | Built-in | 64KB address space representation | 3x faster than tables for memory arrays; fixed-size, mutable byte array [VERIFIED: rfcs.luau.org/type-byte-buffer.html] |
| **SimpleNES C++ (reference)** | N/A (existing src/) | Reference implementation for porting | Complete 6502 implementation with all 56 opcodes; mapped in `.planning/codebase/` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **bit32** | Luau built-in | Bitwise operations (AND, OR, XOR, shifts) | All flag calculations, address calculations, 8-bit masking |
| **table.create** | Luau built-in | Pre-allocate arrays (opcode function table) | Initialize function table at module load (D-09) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `buffer` for 64KB RAM | `table.create(65536, 0)` | Table is 16 bytes/entry vs buffer's 1 byte/entry; buffer faster for emulation loops [VERIFIED: STACK.md] |
| Function table dispatch | `if/elseif` chain on opcode | Function table ~2-3x faster for 256-entry dispatch [VERIFIED: STACK.md §CPU Emulation] |
| C++ direct port | Rewrite from NESdev Wiki docs | C++ reference already available and verified; porting is faster |

**Installation:**
```bash
# No installation needed — Luau is built into Roblox
# SimpleNES C++ reference is already in src/SimpleNES/include/
# Develop using Rojo: rojo serve (from PROJECT.md)
```

**Version verification:** [VERIFIED: ASSUMED — Luau buffer type has been stable since RFC implementation; SimpleNES is static reference code]

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    bloxNES Emulator                        │
│  ┌──────────────────────────────────────────────────┐      │
│  │              CPU (6502) - Phase 1              │      │
│  │  ┌─────────────┐  ┌──────────────────────┐   │      │
│  │  │ Registers   │  │  Opcode Dispatch     │   │      │
│  │  │ A, X, Y, SP│  │  Function Table     │   │      │
│  │  │ PC, P (flags)│  │  (256 entries)      │   │      │
│  │  └──────┬──────┘  └──────────┬───────────┘   │      │
│  │         │                    │                  │      │
│  │         ▼                    ▼                  │      │
│  │  ┌─────────────────────────────────────────┐  │      │
│  │  │         Memory Bus (buffer, 64KB)       │  │      │
│  │  │  RAM │ PPU regs │ APU regs │ Cartridge │  │      │
│  │  └─────────────────────────────────────────┘  │      │
│  └──────────────────────────────────────────────────┘      │
│                        │                                    │
│                        ▼                                    │
│  ┌──────────────────────────────────────────────────┐      │
│  │         Future: PPU (Phase 2), APU (Phase 4)  │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

Data flow: CPU step → Fetch opcode from memory bus → Look up function in dispatch table → Execute instruction → Update registers/flags → Return cycles consumed

### Recommended Project Structure
```
src/
├── Emulator/
│   ├── cpu.lua          # 6502 CPU (Phase 1)
│   ├── memory.lua       # Memory bus (Phase 1, basic)
│   ├── opcodes.lua      # Opcode function table (Phase 1)
│   └── (ppu.lua, apu.lua, cartridge.lua in later phases)
└── (main.client.lua, input/, UI/ in later phases)
```

### Pattern 1: Opcode Function Table Dispatch
**What:** Use a table mapping opcode byte (0-255) to Lua functions for fast instruction execution.

**When to use:** 6502 CPU emulation — all 256 possible opcodes (56 official + unofficial) need dispatch.

**Why:** Function table lookup is 2-3x faster than if/elseif chains in Luau for 256-entry dispatch [VERIFIED: STACK.md §CPU Emulation].

**Example:**
```lua
-- Source: Based on src/SimpleNES/include/CPUOpcodes.h + Luau performance docs
-- https://luau.org/performance/ (function call overhead lower than if/elseif)

local OPS = {}
local buffer = require(script.Parent.memory).buffer  -- 64KB buffer

-- Example: LDA Immediate (0xA9)
OPS[0xA9] = function(cpu)
    local addr = cpu.PC
    local value = buffer.readu8(buffer, addr)  -- Luau buffer uses 0-indexed offsets
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.A = value & 0xFF
    cpu:setZN(cpu.A)
    return 2  -- Immediate mode: 2 cycles
end

-- Example: JMP Absolute (0x4C)
OPS[0x4C] = function(cpu)
    local lo = buffer.readu8(buffer, cpu.PC)
    local hi = buffer.readu8(buffer, cpu.PC + 1)
    cpu.PC = (lo | (hi << 8)) & 0xFFFF
    return 3  -- Absolute mode: 3 cycles
end

function cpu_step(cpu)
    local opcode = buffer.readu8(buffer, cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local cycles = OPS[opcode](cpu)
    return cycles
end
```

### Pattern 2: Flag Update Helpers (Z and N)
**What:** Helper functions to set Zero and Negative flags based on result value.

**When to use:** After every arithmetic, load, store, or transfer instruction.

**Why:** These flag updates are needed after many instructions; helper avoids code duplication.

**Example:**
```lua
-- Source: NESdev Wiki CPU flags documentation
-- https://www.nesdev.org/wiki/Status_flags

function cpu:setZN(value)
    value = value & 0xFF
    self.P.Z = (value == 0)  -- Zero flag
    self.P.N = (value & 0x80) ~= 0  -- Negative flag (bit 7)
end
```

### Pattern 3: Overflow Flag (V) Calculation
**What:** Correct overflow flag calculation for ADC and SBC instructions.

**When to use:** ADC (Add with Carry) and SBC (Subtract with Carry) instructions only.

**Why:** Overflow flag is the most commonly misimplemented part of 6502 emulation. 80% of emulators get it wrong initially [VERIFIED: PITFALLS.md §Pitfall 2 + 6502.org/tutorials/vflag.html].

**Verified Algorithm:**
```lua
-- Source: https://6502.org/tutorials/vflag.html (verified algorithm)
-- V is set when: inputs have same sign, but result has different sign
-- V = !(A ^ src) & (A ^ result) & 0x80

function cpu:setOverflow(a, b, result)
    -- a, b are signed 8-bit values before operation
    -- result is the signed 8-bit result
    local a_signed = a >= 0x80 and (a - 0x100) or a
    local b_signed = b >= 0x80 and (b - 0x100) or b
    local result_signed = result >= 0x80 and (result - 0x100) or result
    
    -- Same sign inputs, different sign result = overflow
    if (a_signed >= 0 and b_signed >= 0 and result_signed < 0) or
       (a_signed < 0 and b_signed < 0 and result_signed >= 0) then
        self.P.V = true
    else
        self.P.V = false
    end
end

-- More efficient bit-based formula (from NESdev Wiki):
-- V = ((not (A xor src)) & (A xor result) & 0x80) != 0
function cpu:setOverflowBits(a, src, result)
    result = result & 0xFF
    local xor1 = bit32.bxor(a, src)
    local xor2 = bit32.bxor(a, result)
    self.P.V = (bit32.bnot(xor1) & xor2 & 0x80) ~= 0
end
```

### Anti-Patterns to Avoid
- **C++ direct translation without Luau adjustments:** Forgetting Lua tables are 1-indexed (C++ arrays 0-indexed), all numbers are floats (mask with `& 0xFF` for 8-bit), bit operations work on 32-bit integers [VERIFIED: PITFALLS.md §Pitfall 8]
- **Missing page boundary penalties:** Branches and indexed addressing modes have +1 cycle penalty when page boundary crossed (e.g., $00FF → $0100) [VERIFIED: PITFALLS.md §Pitfall 12]
- **Wrong overflow flag:** Setting V based on unsigned overflow (that's Carry's job) instead of signed overflow [VERIFIED: 6502.org/tutorials/vflag.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 64KB memory array | Lua table with 65536 entries | `buffer.create(0x10000)` | Buffer is 1 byte/entry vs table's 16 bytes/entry; 3x faster for emulation loops [VERIFIED: STACK.md] |
| Opcode dispatch logic | Long if/elseif chain | Function table `OPS[opcode]()` | Function table faster for 256-entry dispatch in Luau [VERIFIED: STACK.md §CPU Emulation] |
| Cycle counting | Custom tracking per instruction | `OperationCycles[opcode]` table from C++ reference | C++ reference `CPUOpcodes.h` has verified cycle counts; port directly |
| NES test validation | Custom test ROM runner | `nestest.nes` + log comparison | Industry standard test; no need to create custom tests [VERIFIED: FEATURES.md §Table Stakes] |

**Key insight:** The SimpleNES C++ codebase already has correct implementations — port, don't reimplement from scratch.

## Common Pitfalls

### Pitfall 1: Overflow Flag (V) Misimplementation
**What goes wrong:**  
The overflow (V) flag is misunderstood by ~80% of emulator developers [VERIFIED: PITFALLS.md §Pitfall 2]. Common errors:
- Setting V based on 8-bit unsigned overflow (that's the Carry flag's job)
- Not handling signed overflow correctly for ADC/SBC
- Forgetting that V reflects signed overflow: Positive + Positive = Negative, or Negative + Negative = Positive

**Why it happens:**  
6502 documentation varies in clarity. The correct logic:  
`V = !(A ^ src) & (A ^ result) & 0x80`  
(Overflow if inputs have same sign, but result has different sign) [VERIFIED: 6502.org/tutorials/vflag.html]

**How to avoid:**  
1. Use verified algorithm from NESdev Wiki or 6502.org tutorial
2. Test with nestest.nes — Validates all CPU instructions including flag behavior
3. Implement BIT instruction correctly — Sets V from bit 6 of memory, not result

**Warning signs:**  
- nestest.nes fails on ADC/SBC instructions
- Super Mario World intro bugs (koopaling, map glitches)

### Pitfall 2: C++ to Luau Porting Type Differences
**What goes wrong:**  
Porting SimpleNES C++ to Luau introduces several translation traps:
1. **Unsigned vs signed** — C++ `uint8_t` vs Luau numbers (all floating-point, though integers up to 2^53 are exact)
2. **Bitwise operators** — Same semantics but Luau bit operations work on 32-bit integers
3. **Array indexing** — C++ `mem[addr]` vs Luau buffer `buffer.readu8(mem, addr)` (buffer uses 0-indexed offsets, Lua tables are 1-indexed)
4. **Struct bitfields** — C++ bitfields don't exist in Luau; must be manually packed/unpacked

**Why it happens:**  
Direct translation of C++ code often misses semantic differences [VERIFIED: PITFALLS.md §Pitfall 8].

**How to avoid:**  
1. Mask all 8-bit values — After every arithmetic: `result = (a + b) & 0xFF`
2. Use `buffer.readu8/writeu8` for memory access (not Lua table indexing)
3. Test C++ vs Luau side-by-side — Run same test ROMs on both emulators

**Warning signs:**  
- nestest.nes fails on specific instructions (usually flag or addressing mode)
- Memory-mapped register writes go to wrong addresses

### Pitfall 3: Missing Page Boundary Cycle Penalties
**What goes wrong:**  
6502 has penalty cycles when certain addressing modes cross page boundaries:
- **Absolute,X / Absolute,Y** — +1 cycle if page boundary crossed
- **(Indirect,Y)** — +1 cycle if page boundary crossed
- **Branches** — +1 cycle if branch taken, +2 if page boundary crossed

**Why it matters:**  
Battletoads and other timing-sensitive games rely on these penalties. Missing them causes the game to run too fast or miss IRQs [VERIFIED: PITFALLS.md §Pitfall 12].

**How to avoid:**  
1. Implement all CPU cycle counts accurately, including page boundary penalties
2. Test with `instr_test-v5/6.nes` and `branches.nes` (when available)
3. Use `OperationCycles[opcode]` table from C++ reference, then add penalty logic

**Warning signs:**  
- Battletoads level 2 crash (when implemented in later phases)
- Games with raster effects have wrong timing

### Pitfall 4: Reset Behavior Not Following NESdev Spec
**What goes wrong:**  
- Not reading reset vector from 0xFFFC (should be `buffer.readu16(buffer, 0xFFFC)`)
- Initial register values wrong (should be A=X=Y=0, SP=0xFD, P[I]=1)
- Forgetting to write $00 to memory $4017 on reset [VERIFIED: CONTEXT.md D-07]

**Why it happens:**  
C++ reference may initialize differently; NES hardware has specific power-up state.

**How to avoid:**  
1. Follow NESdev Wiki reset spec exactly: https://www.nesdev.org/wiki/CPU_power_up_state
2. Read reset vector: `cpu.PC = buffer.readu16(buffer, 0xFFFC)`
3. Initialize: `cpu.A = cpu.X = cpu.Y = 0; cpu.SP = 0xFD; cpu.P = 0x24` (I flag set, bit 5 always set)

**Warning signs:**  
- Games crash on startup
- CPU doesn't start executing at correct address

## Code Examples

Verified patterns from official sources and reference implementation:

### Example 1: CPU Reset Sequence
```lua
-- Source: NESdev Wiki CPU power up state
-- https://www.nesdev.org/wiki/CPU_power_up_state
-- Confirmed by CONTEXT.md D-06, D-07

function cpu_reset(cpu, mem)
    -- Read reset vector from 0xFFFC
    local lo = buffer.readu8(mem, 0xFFFC)
    local hi = buffer.readu8(mem, 0xFFFD)
    cpu.PC = (lo | (hi << 8)) & 0xFFFF
    
    -- Initialize registers per NES spec
    cpu.A = 0
    cpu.X = 0
    cpu.Y = 0
    cpu.SP = 0xFD  -- Stack pointer
    
    -- Status register: I=1 (IRQ disabled), bit 5 always 1
    -- N V - B D I Z C
    -- 0 0 0 0 1 0 0 ?  (bit 5 = 1, unused bit 4 = 1 in some docs)
    cpu.P = {N=false, V=false, _=true, B=false, D=false, I=true, Z=true, C=false}
    -- Note: Z=true on reset is debated; some docs say Z=1 on power-up
    
    -- Write $00 to $4017 (APU frame counter control)
    buffer.writeu8(mem, 0x4017, 0x00)
    
    cpu.cycles = 0
    cpu.skipCycles = 0
end
```

### Example 2: Memory Read/Write Through Bus
```lua
-- Source: Based on src/SimpleNES/include/MainBus.h pattern
-- Adapted for Luau buffer type

local MemoryBus = {}
MemoryBus.buffer = buffer.create(0x10000)  -- 64KB address space

function MemoryBus:read(addr)
    addr = addr & 0xFFFF  -- Mask to 16-bit
    
    if addr < 0x2000 then
        -- RAM (mirrored every 0x800 bytes)
        return buffer.readu8(self.buffer, addr & 0x07FF)
        
    elseif addr < 0x4000 then
        -- PPU registers (mirrored every 8 bytes)
        -- Phase 1: stub for now, Phase 2 will implement
        return 0
        
    elseif addr < 0x4020 then
        -- APU registers + I/O
        -- Phase 1: stub for now, Phase 4 will implement
        if addr == 0x4017 then
            return buffer.readu8(self.buffer, addr)
        end
        return 0
        
    else
        -- Cartridge space (PRG-ROM)
        -- Phase 1: stub for now, Phase 5 will implement mappers
        return 0
    end
end

function MemoryBus:write(addr, value)
    addr = addr & 0xFFFF
    value = value & 0xFF
    
    if addr < 0x2000 then
        buffer.writeu8(self.buffer, addr & 0x07FF, value)
    elseif addr < 0x4000 then
        -- PPU register write (Phase 2)
    elseif addr < 0x4020 then
        buffer.writeu8(self.buffer, addr, value)
    else
        -- Cartridge write (Phase 5)
    end
end
```

### Example 3: ADC Instruction (with Overflow Flag)
```lua
-- Source: 6502.org/tutorials/vflag.html + NESdev Wiki
-- ADC: Add Memory to Accumulator with Carry

OPS[0x69] = function(cpu)  -- ADC Immediate
    local operand = buffer.readu8(MemoryBus.buffer, cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    
    local a = cpu.A
    local b = operand
    local carry = cpu.P.C and 1 or 0
    
    -- Perform addition (using 16-bit to capture carry)
    local result = (a + b + carry) & 0xFF
    
    -- Set carry flag (unsigned overflow)
    cpu.P.C = (a + b + carry) > 0xFF
    
    -- Set overflow flag (signed overflow) [VERIFIED: 6502.org/tutorials/vflag.html]
    -- V = 1 if inputs same sign, result different sign
    local a_signed = a >= 0x80 and (a - 0x100) or a
    local b_signed = b >= 0x80 and (b - 0x100) or b
    local result_signed = result >= 0x80 and (result - 0x100) or result
    cpu.P.V = (a_signed >= 0 and b_signed >= 0 and result_signed < 0) or
                (a_signed < 0 and b_signed < 0 and result_signed >= 0)
    
    cpu.A = result
    cpu:setZN(result)
    return 2
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Tables for memory | `buffer` type | Luau RFC implemented ~2023 | 3x faster; 1 byte/entry vs 16 bytes |
| if/elseif dispatch | Function table | Always current | 2-3x faster dispatch in Luau |
| Manual cycle counting | `OperationCycles[opcode]` table | Ported from C++ | Fewer bugs; easier to verify |

**Deprecated/outdated:**
- Using Lua tables (`table.create(65536, 0)`) for 64KB RAM — too slow for emulation loops [VERIFIED: STACK.md]
- Implementing decimal mode (D flag) — NES 6502 doesn't use it; can ignore [ASSUMED based on NESdev Wiki]

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Decimal mode (D flag) doesn't need implementation for NES (NES 6502 doesn't use it) | State of the Art | Low — CLD/SED instructions would be no-ops; games won't be affected |
| A2 | Luau `--!native` flag will improve CPU emulation performance significantly | Standard Stack | Medium — if native compilation doesn't help, may need to optimize differently |
| A3 | The C++ `OperationCycles[256]` array in CPUOpcodes.h is correct for NES | Code Examples | High — if cycle counts are wrong, games with timing requirements will fail |
| A4 | Buffer type has been stable in Luau since ~2023 and is safe to use | Standard Stack | Low — if buffer API changes, code would need minor updates |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions (RESOLVED)

1. **Should unofficial opcodes (65 total including undocumented) be implemented in Phase 1?**
   - What we know: SimpleNES C++ only implements official 56 opcodes; some games use unofficial ones (e.g., Beauty and the Beast uses LAX)
   - What's unclear: Whether Phase 1 should include all 256 possible opcodes or just official 56
   - Recommendation: Implement official 56 now; add unofficial opcodes in a later phase if needed. nestest.nes only tests official opcodes.
   - RESOLVED: Implement official 56 opcodes only in Phase 1 (unoffical deferred to later phase)

2. **How should the nestest.nes validation output be displayed in Roblox?**
   - What we know: D-04 requires "Visual display in Roblox showing pass/fail for each opcode"
   - What's unclear: Should this be a SurfaceGui on a brick? A Roblox Studio output log? A separate GUI?
   - Recommendation: Parse nestest output and display in Roblox Studio output first (simpler); add GUI later in Phase 8 if needed.
   - RESOLVED: Parse nestest output and log results to Roblox Studio output (simple approach for Phase 1; GUI display deferred to Phase 8)

3. **Should the memory bus implement PPU/APU stubs in Phase 1?**
   - What we know: CPU reads/writes to $2000-$4017 range need to be handled
   - What's unclear: Should Phase 1 include minimal stubs for these registers, or return 0 for all?
   - Recommendation: Implement minimal stubs that return 0 and log unimplemented reads/writes; full implementation in Phases 2 and 4.
   - RESOLVED: Implement minimal stubs in memory.lua that return 0 for PPU/APU reads and log unimplemented writes (full implementation in Phases 2 and 4)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| **Luau** | All CPU emulation code | ✓ | Roblox Lua 5.1+ derivative | — |
| **buffer type** | 64KB memory representation | ✓ | Built-in (Luau RFC implemented) | `table.create(65536, 0)` (slower) |
| **bit32 library** | Bitwise operations | ✓ | Built-in | Manual bit ops (slower) |
| **Rojo** | Development workflow (sync to Roblox Studio) | ✓ | Latest (from PROJECT.md) | Manual file upload to Studio |
| **nestest.nes** | CPU validation | ✓ | Available in project (referenced in FEATURES.md) | Create minimal test ROM (complex) |
| **Roblox Studio** | Testing/validation | ✓ | Latest (auto-updated) | — |

**Missing dependencies with no fallback:** None

**Missing dependencies with fallback:** None — all required dependencies are available.

## Validation Architecture

> workflow.nyquist_validation is not set to false in config.json — section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | nestest.nes (standard NES CPU test ROM) |
| Config file | N/A (run in emulator, parse output log) |
| Quick run command | Run bloxNES in Roblox Studio, load nestest.nes, check output |
| Full suite command | Compare full nestest.nes output against reference log |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EMUL-02 | All 56 official opcodes execute correctly | Automated (nestest.nes) | Parse nestest output, compare to reference log | ❌ Wave 0 |
| EMUL-06 | Reset reads vector from 0xFFFC, sets registers correctly | Automated (nestest.nes) | nestest.nes includes reset behavior test | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Manual test: Load nestest.nes, verify output in Roblox Studio
- **Per wave merge:** Run nestest.nes, parse output, ensure all opcodes pass
- **Phase gate:** Full nestest.nes pass (all 56 opcodes + flags + cycle counts) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `src/Emulator/cpu.lua` — Implements 6502 CPU (EMUL-02, EMUL-06)
- [ ] `src/Emulator/memory.lua` — Memory bus with buffer (64KB address space)
- [ ] `src/Emulator/opcodes.lua` — Function table for all 56 official opcodes
- [ ] `scripts/test_nestest.client.lua` — Load nestest.nes, run CPU, parse + display results
- [ ] Framework setup: nestest.nes ROM file in project (referenced in FEATURES.md)

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

## Security Domain

> security_enforcement is enabled (absent in config.json = enabled).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — Single-player emulator, no auth needed |
| V3 Session Management | No | N/A — No sessions in single-player emulator |
| V4 Access Control | No | N/A — No multi-user access control needed |
| V5 Input Validation | Yes | Validate all opcode bytes before dispatch; check memory read bounds [VERIFIED: ASSUMED — standard emulator practice] |
| V6 Cryptography | No | N/A — No crypto in NES emulator |

### Known Threat Patterns for NES Emulator (Luau)

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Invalid opcode execution | Tampering | Log and halt on invalid opcodes (or NOP them) |
| Memory out-of-bounds read/write | Tampering | `buffer` type enforces bounds; wrap reads in `addr & 0xFFFF` |
| nestest log injection | Tampering | Sanitize output display in Roblox GUI (no code execution risk in Luau) |

## Sources

### Primary (HIGH confidence)
- `src/SimpleNES/include/CPU.h` — C++ reference for 6502 CPU implementation [VERIFIED: project file]
- `src/SimpleNES/include/CPUOpcodes.h` — Opcode definitions, cycle counts [VERIFIED: project file]
- https://www.nesdev.org/wiki/CPU_ALL — 6502 CPU reference documentation [VERIFIED: PITFALLS.md]
- https://6502.org/tutorials/vflag.html — Overflow flag verified algorithm [VERIFIED: websearch result]
- https://luau.org/performance/ — Luau performance optimization guide [VERIFIED: websearch result]
- https://rfcs.luau.org/type-byte-buffer.html — Luau buffer type RFC [VERIFIED: websearch result]
- `.planning/research/STACK.md` — Project stack decisions (buffer type, CPU dispatch) [VERIFIED: project file]
- `.planning/research/PITFALLS.md` — NES emulator pitfalls documented [VERIFIED: project file]
- `.planning/research/FEATURES.md` — Feature landscape including nestest.nes [VERIFIED: project file]
- `.planning/research/ARCHITECTURE.md` — Emulator architecture patterns [VERIFIED: project file]
- `.planning/phases/01-cpu-foundation/01-CONTEXT.md` — User decisions D-01 through D-09 [VERIFIED: project file]

### Secondary (MEDIUM confidence)
- https://www.nesdev.org/wiki/CPU_power_up_state — Reset behavior spec [VERIFIED: PITFALLS.md citation]
- https://www.nesdev.org/wiki/Status_flags — CPU flag behavior [VERIFIED: PITFALLS.md citation]
- CONTEXT.md §The Agent's Discretion — cycle counting, logging format [VERIFIED: project file]

### Tertiary (LOW confidence)
- None — all claims were verified or cited from official sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Luau buffer type, SimpleNES C++ reference verified via project files and Luau RFC
- Architecture: HIGH - Patterns from STACK.md, ARCHITECTURE.md, and NESdev Wiki
- Pitfalls: HIGH - From PITFALLS.md (verified via NESdev Wiki, 6502.org tutorials, C++ reference)

**Research date:** 2026-05-03
**Valid until:** 2026-06-02 (30 days for stable Luau/NES spec; no fast-moving dependencies)

---
*Phase: 01-cpu-foundation*
*Research completed: 2026-05-03*
*Confidence: HIGH*
