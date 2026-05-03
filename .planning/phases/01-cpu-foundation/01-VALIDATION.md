---
phase: 01
slug: cpu-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-03
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual validation (Luau in Roblox Studio) |
| **Config file** | None yet — Wave 0 installs infrastructure |
| **Quick run command** | `loadstring(game:GetService("ReplicatedStorage"):WaitForChild("nestest"):FindFirstChild("cpu_test"):Run()` |
| **Full suite command** | `Run nestest.nes in Roblox Studio, check output for "Passed"/"Failed" for all 56 opcodes |
| **Estimated runtime** | ~30 seconds (manual observation) |

---

## Sampling Rate

- **After every task commit:** Run `cpu:step()` with nestest and check output
- **After every plan wave:** Run full nestest.nes validation
- **Before `/gsd-verify-work`:** Full suite must show all 56 opcodes passed
- **Max feedback latency:** 60 seconds (manual observation)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01-01 | 1 | EMUL-06 | T-01-01 / — | buffer enforces bounds + `addr & 0xFFF` | unit | `grep -q "buffer.create(0x10000)" cpu.lua` | ✅ / ❌ W0 | ⬜ pending |
| 01-01-02 | 01-01 | 1 | EMUL-06 | T-01-06 / T-01-07 | A=X=Y=0, SP=0xFD, P[I]=1, $4017=$00 | unit | `grep -q "SP = 0xFD" cpu.lua && grep -q "P\\[I\\] = 1" cpu.lua` | ✅ / ❌ W0 | ⬜ pending |
| 01-02-01 | 01-02 | 2 | EMUL-02 | T-01-02 / T-01-08 | OPS[] table maps all 56 opcodes | unit | `grep -c "function OPS\\[0x[0-9A-F]\\]" cpu.lua | count >= 56` | ✅ / ❌ W0 | ⬜ pending |
| 01-02-02 | 01-02 | 2 | EMUL-02 | T-01-01 (invalid opcodes) | 56 opcodes execute correctly, flags set | integration | `Run nestest.nes, check "Passed: 56/56"` | ✅ / ❌ W0 | ⬜ pending |
| 01-03-01 | 01-03 | 3 | EMUL-02, EMUL-06 | T-01-03 / T-01-05 | nestest output parsed, pass/fail reported | integration | `Check Roblox Studio output for "Passed:" and "Failed:" lines` | ✅ / ❌ W0 | ⬜ pending |
| 01-03-02 | 01-03 | 3 | EMUL-02, EMUL-06 | T-01-04 / T-01-09 | Visual display in Roblox (log results) | manual | `See Roblox Studio output panel for pass/fail summary` | ✅ / ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `nestest.nes` ROM loaded into Roblox ReplicatedStorage
- [ ] `cpu.lua` stubs for $2000-$4017 reads/writes (return 0, accept writes)
- [ ] Manual test: "Run nestest.nes and observe output in Roblox Studio"

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| nestest.nes visual output | EMUL-02 | Roblox Studio output panel observation | Open Roblox Studio, run game, observe output panel for "Passed: 56/56 opcodes" |
| CPU reset behavior | EMUL-06 | Register values need manual verification in Studio | Add print statements in cpu.lua, verify A=X=Y=0, SP=0xFD, P[I]=1 after reset |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** {pending / approved YYYY-MM-DD}
