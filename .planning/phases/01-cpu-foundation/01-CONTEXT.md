# Phase 1: CPU Foundation - Context

**Gathered:** 2026-05-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the 6502 CPU core from SimpleNES C++ to Luau with all 56 official opcodes, correct flag handling, and proper reset behavior. This phase delivers a working 6502 CPU emulator that can run nestest.nes and verify correctness.
</domain>

<decisions>
## Implementation Decisions

### Memory Representation
- **D-01:** Use `buffer` type for 64KB address space (fastest for emulation loops)
- **D-02:** Pre-allocate with `buffer.create(0x10000)` for the 64KB address space

### nestest Validation
- **D-03:** Parse nestest output string and report passed/failed opcodes
- **D-04:** Visual display in Roblox showing pass/fail for each opcode
- **D-05:** Automated CI-style check that logs results to output

### Reset Behavior
- **D-06:** Standard NES reset — read vector from 0xFFFC, set registers per NESDev spec
- **D-07:** Registers: A=X=Y=0, SP=0xFD, P[I]=1, memory $4017 = $00

### Opcode Dispatch
- **D-08:** Lookup table mapping opcode byte to function (fastest dispatch)
- **D-09:** Table initialized at module load, not per-instruction

### The Agent's Discretion
- Exact cycle counting within each opcode (some opcodes vary)
- Error handling for invalid opcodes (shouldn't happen with valid ROMs)
- Logging format for nestest output parsing

### Folded Todos
- None folded into this phase.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### CPU Emulation
- `src/SimpleNES/include/CPU.h` — C++ reference for 6502 CPU implementation
- `src/SimpleNES/include/CPUOpcodes.h` — Opcode definitions and addressing modes
- `src/SimpleNES/include/MainBus.h` — Memory bus implementation (CPU side)
- `.planning/research/STACK.md` §Luau Performance — `buffer` type, `table.create()`, `--!native` flag
- `.planning/research/ARCHITECTURE.md` §9 Major Components — CPU + MainBus architecture
- `.planning/research/PITFALLS.md` §CPU flag handling (Overflow V) — Verified algorithm provided

### Validation
- `.planning/research/FEATURES.md` §Table stakes — nestest.nes is standard CPU test
- `rom/bombsweeper/` — Public domain ROM for initial testing after CPU works

### NES Hardware Specs
- NESDev Wiki: 6502 reset vector at 0xFFFC, power-up state documented
- `.planning/ROADMAP.md` §Phase 1 — Goal, success criteria, requirements (EMUL-02, EMUL-06)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/SimpleNES/include/CPU.h` — Complete C++ implementation to port (reference only, not used in Luau)
- `src/SimpleNES/include/CPUOpcodes.h` — All 56 opcodes with addressing modes defined

### Established Patterns
- SimpleNES uses constructor injection for MainBus — may or may not port to Luau
- C++ uses `std::array<uint8_t, 0x10000>` for 64KB RAM — Luau `buffer` is equivalent

### Integration Points
- CPU will read/write to MainBus (to be implemented in this phase)
- CPU registers visible to other components (PPU reads via register writes, APU via $4000-$4017)
</code_context>

<specifics>
## Specific Ideas

- "I want the nestest validation to be thorough — parse output, show visual results, and log automatically"
- "Use buffer type for memory — research confirmed it's 3x faster than tables"
- Standard NES reset behavior per NESDev Wiki spec
</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- None reviewed.
</deferred>

---
*Phase: 01-cpu-foundation*
*Context gathered: 2026-05-03*
