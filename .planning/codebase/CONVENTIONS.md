# Coding Conventions

**Analysis Date:** 2026-05-03

## Naming Patterns

**Files:**
- `*.client.luau` for client scripts (Roblox convention)
- `*.server.luau` for server scripts (Roblox convention)
- `*.luau` for shared modules (no special suffix)
- Lowercase with hyphens for multi-word: `init.client.luau`

**Functions:**
- `camelCase` for all functions (Luau convention)
- No special prefix for async (Luau doesn't have async/await)

**Variables:**
- `camelCase` for variables
- `UPPER_SNAKE_CASE` for constants (if any)
- No underscore prefix (no private marker in Luau)

**Types (if using Luau types):**
- PascalCase for type aliases and interfaces
- No `I` prefix for interfaces (Luau convention)

## Code Style

**Formatting:**
- No standardized formatter detected (no `.stylua.toml` or similar)
- Roblox Studio auto-formats Lua/Luau code
- 4-space indentation (Roblox default)
- No semicolons (Lua/Luau doesn't use them)

**Conventions observed:**
- `print()` for output (currently used)
- Simple function returns (no complex patterns yet)

## Import Organization

**Luau Module Pattern:**
```lua
-- In shared/Hello.luau
return function()
    -- module code
end

-- In client/init.client.luau
local hello = require(script.Parent.Shared.Hello)
```

**Order:**
1. Luau built-in functions
2. Roblox services (`game:GetService()`)
3. Local modules via `require()`

**Path References:**
- Use `script.Parent` to navigate relative paths
- Roblox doesn't use filesystem-style paths in code

## Error Handling

**Patterns:**
- `pcall()` for protected calls (Lua/Luau standard)
- `xpcall()` for protected calls with custom error handler
- `error()` to throw errors
- `warn()` for warnings

**Expected Pattern (not yet implemented):**
```lua
local success, result = pcall(function()
    -- risky operation
end)
if not success then
    warn("Error:", result)
end
```

## Logging

**Framework:**
- `print()` - Standard output
- `warn()` - Warnings
- `error()` - Errors (stops execution)

**Patterns:**
- Currently: `print("Hello world, from client!")`
- No structured logging framework
- Roblox outputs to console in Studio

## Comments

**When to Comment:**
- Explain complex emulation logic (6502 instructions, PPU rendering)
- Document NES hardware behavior
- Note differences between C++ reference and Luau implementation

**Style:**
- `--` for single-line comments (Lua/Luau style)
- No JSDoc/TSDoc equivalent yet (Luau has basic type comments)

**TODO Comments:**
- `-- TODO: description`

## Function Design

**Size:**
- Keep functions focused (no specific limit observed)
- Extract helpers for repeated patterns (e.g., 6502 addressing modes)

**Parameters:**
- Pass multiple parameters directly (no options object pattern in Lua)
- Use tables for complex data structures

**Return Values:**
- Explicit `return` statements
- Can return multiple values (Lua feature): `return success, data`

## Module Design

**Exports:**
- Return a table or function from module
- Common pattern: `return { func1 = func1, func2 = func2 }`
- Or: `return function() ... end` for single-function modules

**Barrel Files:**
- Not typically used in Roblox Lua/Luau
- Each script is a separate module

---

*Convention analysis: 2026-05-03*
*Update when patterns evolve during implementation*
