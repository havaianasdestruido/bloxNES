--!native
-- 6502 CPU Emulator
-- Ports SimpleNES C++ CPU.h to Luau
-- Implements NES reset behavior per D-06, D-07 and NESdev Wiki

local bit32 = bit32

local CPU = {}
CPU.__index = CPU

function CPU.new(memoryBus)
    local self = setmetatable({}, CPU)
    self.mem = memoryBus

    -- Initialize registers (will be set properly by reset())
    self.A = 0       -- Accumulator
    self.X = 0       -- X index register
    self.Y = 0       -- Y index register
    self.SP = 0xFD   -- Stack pointer (NES power-up state)
    self.PC = 0x0000  -- Program counter

    -- Status register flags (P)
    -- Bit layout: N V - B D I Z C (bit 5 is always 1)
    -- N: Negative, V: Overflow, -: unused (always 1), B: Break, D: Decimal, I: Interrupt disable, Z: Zero, C: Carry
    self.P = {
        N = false,  -- Negative flag (bit 7)
        V = false,  -- Overflow flag (bit 6)
        _ = true,   -- Bit 5: always 1 (unused)
        B = false,  -- Break flag (bit 4)
        D = false,  -- Decimal mode (bit 3, not used in NES)
        I = true,   -- Interrupt disable (bit 2, set on power-up per D-07)
        Z = false,  -- Zero flag (bit 1)
        C = false,  -- Carry flag (bit 0)
    }

    self.cycles = 0
    self.skipCycles = 0

    return self
end

-- Read 8-bit value from memory
function CPU:readu8(addr)
    return self.mem:read(addr)
end

-- Write 8-bit value to memory
function CPU:writeu8(addr, value)
    self.mem:write(addr, value)
end

-- Read 16-bit value from memory (little-endian)
function CPU:readu16(addr)
    local lo = self.mem:read(addr)
    local hi = self.mem:read((addr + 1) & 0xFFFF)
    return (lo | (hi << 8)) & 0xFFFF
end

-- Set Zero and Negative flags based on value
function CPU:setZN(value)
    value = value & 0xFF
    self.P.Z = (value == 0)
    self.P.N = (value & 0x80) ~= 0
end

-- Push value to stack
function CPU:pushStack(value)
    self.mem:write(0x100 | self.SP, value)
    self.SP = (self.SP - 1) & 0xFF
end

-- Pull value from stack
function CPU:pullStack()
    self.SP = (self.SP + 1) & 0xFF
    return self.mem:read(0x100 | self.SP)
end

-- NES Reset behavior per D-06, D-07 and NESdev Wiki
-- https://www.nesdev.org/wiki/CPU_power_up_state
function CPU:reset()
    -- Read reset vector from 0xFFFC (D-06)
    local lo = self.mem:read(0xFFFC)
    local hi = self.mem:read(0xFFFD)
    self.PC = (lo | (hi << 8)) & 0xFFFF

    -- Initialize registers per NESdev spec (D-07)
    self.A = 0
    self.X = 0
    self.Y = 0
    self.SP = 0xFD  -- Stack pointer

    -- Status register: I=1 (IRQ disabled), bit 5 always 1
    -- Binary: 00100100 = 0x24 (I=1, bit5=1)
    self.P.N = false
    self.P.V = false
    self.P._ = true
    self.P.B = false
    self.P.D = false
    self.P.I = true   -- D-07: P[I]=1
    self.P.Z = false
    self.P.C = false

    -- Write $00 to memory $4017 (APU frame counter control) per D-07
    self.mem:write(0x4017, 0x00)

    self.cycles = 0
    self.skipCycles = 0
end

-- Placeholder for step function (implemented in 01-02-PLAN.md)
function CPU:step()
    -- To be implemented in next plan with opcode dispatch table
    return 0
end

return CPU
