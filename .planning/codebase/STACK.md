# Technology Stack

**Analysis Date:** 2026-05-03

## Languages

**Primary:**
- Luau (Roblox Lua) - All game code (`src/client/`, `src/server/`, `src/shared/`)

**Secondary:**
- C++ - Reference implementation in `src/SimpleNES/` (original SimpleNES emulator)
- JSON - Configuration files (`default.project.json`, `aftman.toml`)

## Runtime

**Environment:**
- Roblox Platform (Roblox Studio + Roblox Game Engine)
- Luau VM (Roblox's Lua interpreter)

**Tooling:**
- Rojo 7.7.0-rc.1 - Project synchronization between filesystem and Roblox Studio
- Aftman - Toolchain manager for Roblox development tools

## Frameworks

**Core:**
- None (vanilla Luau for Roblox)

**Build/Dev:**
- Rojo - Filesystem-to-Roblox sync (`rojo build`, `rojo serve`)
- Roblox Studio - IDE and runtime environment

## Key Dependencies

**Critical:**
- SimpleNES (C++ reference) - Original NES emulator to port from
- Roblox Engine APIs - `game`, `workspace`, `script`, etc.
- Rojo - Project structure and syncing

**Infrastructure:**
- None (self-contained Roblox experience)

## Configuration

**Environment:**
- `default.project.json` - Rojo project structure definition
- `aftman.toml` - Tool versions (Rojo 7.7.0-rc.1)

**Build:**
- Rojo commands: `rojo build -o "bloxNES.rbxlx"`, `rojo serve`

## Platform Requirements

**Development:**
- Roblox Studio installed
- Rojo installed via Aftman
- File system access for Rojo sync

**Production:**
- Roblox Game Experience (hosted on Roblox platform)
- Compatible with Roblox client versions

---

*Stack analysis: 2026-05-03*
*Update after adding new dependencies or tools*
