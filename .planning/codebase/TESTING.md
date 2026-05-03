# Testing

**Analysis Date:** 2026-05-03

## Testing Framework

**Current State:**
- No testing framework detected
- No test files present
- Early development stage (only "Hello World" prints)

**Roblox Testing Options:**
- **Roblox TestService** - Built-in testing framework (basic)
- **Rojo + External** - Sync to Roblox, run tests in Studio
- **No standard Luau testing framework** equivalent to Jest/Vitest

## Test Structure

**None currently** - No test directories or files exist.

**Expected Structure (if implementing tests):**
```
src/
├── client/
│   ├── init.client.luau
│   └── ... (client modules)
├── server/
│   ├── init.server.luau
│   └── ... (server modules)
└── shared/
    ├── Hello.luau
    ├── CPU.luau
    └── ... (shared modules)
```

No dedicated `tests/` directory (Roblox doesn't have standard test layout).

## Testing Patterns

**Roblox TestService Pattern:**
```lua
-- In a test script
local TestService = game:GetService("TestService")
TestService:ExpectTrue(condition, "Test description")
TestService:ExpectEquals(expected, actual, "Test description")
```

**Manual Testing (Current Approach):**
- Load game in Roblox Studio
- Check `print()` output in console
- Verify emulator behavior visually

## Mocking

**None currently** - No mocking framework detected.

**Potential Mocking Needs:**
- Mock `UserInputService` for controller input tests
- Mock `ScreenGui` for rendering tests
- Mock ROM data for CPU/PPU unit tests

## Coverage

**None currently** - No coverage tooling for Luau.

**Challenge:** Roblox/Luau has limited tooling for code coverage.

## CI/CD Integration

**None currently** - No GitHub Actions or CI pipeline detected.

**`.github/workflows/` in `src/SimpleNES/`** (reference C++ project only):
- `compile.yml` - Compiles C++ SimpleNES
- `pr.yaml` - PR checks for C++ project

**Not applicable to Luau code** (Roblox games don't compile externally).

## Recommendations

**For bloxNES Testing:**
1. **Unit Tests:** Test 6502 CPU instructions, PPU rendering logic
2. **Integration Tests:** Test ROM loading, full frame emulation
3. **Manual Tests:** Verify games run correctly, input works, audio plays
4. **No automated CI** - Roblox games are tested in Studio

**Testing Strategy:**
- Since NES emulation is deterministic, unit test CPU instructions
- Test PPU output against known frame hashes
- Manual testing for games (run public domain ROMs)

---

*Testing analysis: 2026-05-03*
*Update when testing framework is added*
