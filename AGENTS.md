# AGENTS.md - bloxNES

## Project Context

**Name:** bloxNES
**Type:** NES Emulator for Roblox (Luau port of SimpleNES C++)
**Core Value:** Players can play NES games inside Roblox with authentic emulation and flexible input/rendering options.

## Current Phase

**Phase 1: CPU Foundation** — 6502 CPU emulation runs correctly with all 56 opcodes and proper reset behavior

## Key Files

- `.planning/PROJECT.md` — Project context and goals
- `.planning/REQUIREMENTS.md` — v1 requirements (37 total)
- `.planning/ROADMAP.md` — 8 phases with requirements mapped
- `.planning/STATE.md` — Current project state
- `.planning/config.json` — Workflow preferences (YOLO, Fine granularity, Parallel)
- `src/` — Luau source code (currently minimal)
- `src/SimpleNES/` — C++ reference implementation

## Workflow Rules

1. **YOLO Mode:** Auto-approve, just execute
2. **Granularity:** Fine (8-12 phases, 5-10 plans each)
3. **Parallelization:** Independent plans run simultaneously
4. **Git Tracking:** Planning docs tracked in version control
5. **Research:** Yes — research before planning each phase
6. **Plan Check:** Yes — verify plans achieve goals
7. **Verifier:** Yes — verify work satisfies requirements
8. **Model Profile:** Inherit (use current session model)

## NES Emulator Specifics

- **Reference:** SimpleNES C++ codebase in `src/SimpleNES/include/`
- **Target:** Full NES emulation (6502 CPU, PPU graphics, APU audio)
- **Mappers:** NROM, MMC1, MMC3, CNROM (and more)
- **ROMs:** Public domain only (legal compliance)
- **Rendering:** SurfaceGui on brick + two toggleable modes (pixel/part-based)
- **Input:** Physical button parts + keyboard (UserInputService)
- **Performance:** Must maintain ~60 FPS in Luau

## Next Steps

**Current:** Ready to plan Phase 1
**Command:** `/gsd-discuss-phase 1` or `/gsd-plan-phase 1`

## Important Notes

- Port from C++ to Luau carefully — maintain accuracy
- Performance is critical — use `buffer` type, `--!native` flag, `table.create()`
- Test with public domain ROMs first (BombSweeper)
- PPU timing accuracy is non-negotiable (3 PPU dots per CPU cycle)
- Audio (APU) → Roblox sound objects (creative workaround needed)
