# Integrations

**Analysis Date:** 2026-05-03

## External Services

**None currently** - bloxNES is a self-contained NES emulator running within Roblox.

## Roblox Platform APIs

**Game Services:**
- `game:GetService("ReplicatedStorage")` - Shared assets between client/server
- `game:GetService("ServerScriptService")` - Server-side script execution
- `game:GetService("StarterPlayer")` - Player initialization
- `game:GetService("SoundService")` - Audio playback

**Client APIs:**
- `game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")` - Client script entry
- Roblox GUI APIs (expected) - For rendering NES screen
- `UserInputService` (expected) - For NES controller input

**Server APIs:**
- `game:GetService("ServerScriptService"):WaitForChild("Server")` - Server script entry

## File System Integration

**ROM Loading:**
- `rom/` directory - Contains `.nes` ROM files (public domain games like `bombsweeper/BombSweeper.nes`)
- Expected: Runtime loading of ROM files from `ReplicatedStorage` or `ServerStorage`

## Data Exchange

**Client-Server Communication:**
- RemoteEvents/RemoteFunctions (expected) - For synchronizing emulator state if multiplayer
- Currently: Single-player emulator, likely client-side execution

## No External APIs

- No HTTP requests (Roblox `HttpService` not used)
- No database connections
- No third-party SDKs
- No webhook integrations

---

*Integrations analysis: 2026-05-03*
*Update when adding external services or APIs*
