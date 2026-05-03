# Codebase Structure

**Analysis Date:** 2026-05-03

## Directory Layout

```
bloxNES/
├── .git/                 # Git repository
├── .gitignore            # Git ignore rules
├── aftman.toml           # Toolchain manager config (Rojo)
├── default.project.json   # Rojo project definition
├── README.md             # Project documentation
├── rom/                  # NES ROM files
│   └── bombsweeper/     # Public domain NES game
│       ├── BombSweeper.nes
│       └── readme.txt
└── src/                  # Source code
    ├── client/           # Client-side Luau scripts
    │   └── init.client.luau
    ├── server/           # Server-side Luau scripts
    │   └── init.server.luau
    ├── shared/            # Shared Luau modules
    │   └── Hello.luau
    └── SimpleNES/        # C++ reference implementation (git submodule)
        ├── include/      # C++ header files
        │   ├── APU/      # Audio Processing Unit
        │   ├── Mapper*.h # NES memory mappers
        │   ├── CPU.h
        │   ├── PPU.h
        │   └── ...
        ├── vendor/       # Third-party dependencies
        │   └── miniaudio/
        └── main.cpp      # C++ entry point
```

## Directory Purposes

**`src/client/`:**
- Purpose: Client-side logic running on player's Roblox client
- Contains: `*.client.luau` scripts (Luau code)
- Key files: `init.client.luau` (entry point)
- Subdirectories: None currently

**`src/server/`:**
- Purpose: Server-side logic running on Roblox game server
- Contains: `*.server.luau` scripts (Luau code)
- Key files: `init.server.luau` (entry point)
- Subdirectories: None currently

**`src/shared/`:**
- Purpose: Code shared between client and server
- Contains: `*.luau` modules (Luau code)
- Key files: `Hello.luau` (example module)
- Subdirectories: None currently

**`src/SimpleNES/`:**
- Purpose: Reference C++ NES emulator implementation
- Contains: C++ headers and source files
- Key files: `include/*.h` (CPU, PPU, APU, Mappers), `main.cpp`
- Subdirectories: `include/APU/`, `vendor/`, `.git/` (submodule)

**`rom/`:**
- Purpose: NES ROM files for testing
- Contains: `.nes` ROM files in subdirectories
- Key files: `bombsweeper/BombSweeper.nes` (public domain game)
- Subdirectories: One per game

## Key File Locations

**Entry Points:**
- `src/client/init.client.luau`: Client entry point
- `src/server/init.server.luau`: Server entry point
- `src/SimpleNES/main.cpp`: Reference C++ entry point

**Configuration:**
- `default.project.json`: Rojo project structure
- `aftman.toml`: Tool versions (Rojo 7.7.0-rc.1)
- `src/SimpleNES/.clang-format`: C++ formatting config

**Core Logic:**
- `src/shared/*.luau`: Shared modules (to be implemented)
- `src/SimpleNES/include/*.h`: Reference emulator components

**ROM Files:**
- `rom/bombsweeper/BombSweeper.nes`: Test ROM (public domain)

**Documentation:**
- `README.md`: Project overview and setup instructions

## Naming Conventions

**Files:**
- `*.client.luau`: Client-side scripts (Roblox convention)
- `*.server.luau`: Server-side scripts (Roblox convention)
- `*.luau`: Shared modules or libraries
- `*.h`, `*.cpp`: C++ reference code
- `*.nes`: NES ROM files

**Directories:**
- Lowercase with descriptive names (`client/`, `server/`, `shared/`)
- `SimpleNES/` maintains original C++ project naming

**Special Patterns:**
- `init.client.luau`: Standard Roblox client script entry
- `init.server.luau`: Standard Roblox server script entry
- No index files or barrel exports (Roblox doesn't use this pattern)

## Where to Add New Code

**New Emulator Module:**
- Implementation: `src/shared/` (e.g., `src/shared/CPU.luau`)
- Tests: No testing framework yet
- Config if needed: N/A

**New Client Feature (GUI, Input):**
- Implementation: `src/client/` (e.g., `src/client/ScreenGui.luau`)
- Types: N/A (Luau has optional typing)
- Tests: N/A

**New Server Feature:**
- Implementation: `src/server/` (if needed)
- Types: N/A
- Tests: N/A

**New ROM for Testing:**
- Implementation: `rom/{game-name}/{game}.nes`
- Documentation: `rom/{game-name}/readme.txt`

## Special Directories

**`src/SimpleNES/`:**
- Purpose: Git submodule with reference C++ implementation
- Source: Original SimpleNES repository
- Committed: Yes (as submodule)
- Note: Reference only, not compiled or used in Roblox game

**`rom/`:**
- Purpose: Test ROM files
- Source: Public domain NES ROMs
- Committed: Yes (small ROM files)

**`.git/` (in `src/SimpleNES/`):**
- Purpose: Git submodule metadata
- Source: SimpleNES repository history
- Committed: No (git internal)

---

*Structure analysis: 2026-05-03*
*Update when directory structure changes*
