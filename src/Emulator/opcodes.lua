--!native
-- 6502 CPU Opcode Function Table
-- Ports SimpleNES C++ CPU.cpp to Luau
-- Implements all 56 official opcodes per D-08, D-09
-- Table initialized at module load (D-09), not per-instruction

local bit32 = bit32

local OPS = {}
local OperationCycles = {}

-- Initialize cycle counts from C++ CPUOpcodes.h OperationCycles[256]
-- 0 implies unused/unofficial opcode
OperationCycles = {
    7, 6, 0, 0, 0, 3, 5, 0, 3, 2, 2, 0, 0, 4, 6, 0, -- 0x00-0x0F
    2, 5, 0, 0, 0, 4, 6, 0, 2, 4, 0, 0, 0, 4, 7, 0, -- 0x10-0x1F
    6, 6, 0, 0, 3, 3, 5, 0, 4, 2, 2, 0, 4, 4, 6, 0, -- 0x20-0x2F
    2, 5, 0, 0, 0, 4, 6, 0, 2, 4, 0, 0, 0, 4, 7, 0, -- 0x30-0x3F
    6, 6, 0, 0, 0, 3, 5, 0, 3, 2, 2, 0, 3, 4, 6, 0, -- 0x40-0x4F
    2, 5, 0, 0, 0, 4, 6, 0, 2, 4, 0, 0, 0, 4, 7, 0, -- 0x50-0x5F
    6, 6, 0, 0, 0, 3, 5, 0, 4, 2, 2, 0, 5, 4, 6, 0, -- 0x60-0x6F
    2, 5, 0, 0, 0, 4, 6, 0, 2, 4, 0, 0, 0, 4, 7, 0, -- 0x70-0x7F
    2, 6, 2, 0, 3, 3, 5, 0, 2, 2, 2, 0, 4, 4, 6, 0, -- 0x80-0x8F
    2, 5, 0, 0, 4, 4, 6, 0, 2, 5, 2, 0, 0, 5, 0, 0, -- 0x90-0x9F
    2, 6, 2, 0, 3, 3, 5, 0, 2, 2, 2, 0, 4, 4, 6, 0, -- 0xA0-0xAF
    2, 5, 0, 0, 4, 4, 6, 0, 2, 4, 2, 0, 4, 4, 6, 0, -- 0xB0-0xBF
    2, 6, 0, 0, 3, 3, 5, 0, 2, 2, 2, 0, 4, 4, 6, 0, -- 0xC0-0xCF
    2, 5, 0, 0, 0, 4, 6, 0, 2, 4, 0, 0, 0, 4, 7, 0, -- 0xD0-0xDF
    2, 6, 0, 0, 3, 3, 5, 0, 2, 2, 2, 0, 4, 4, 6, 0, -- 0xE0-0xEF
    2, 5, 0, 0, 0, 4, 6, 0, 2, 4, 0, 0, 0, 4, 7, 0, -- 0xF0-0xFF
}

-- Helper: Read 16-bit address from memory (little-endian)
local function readAddress(cpu, addr)
    local lo = cpu:readu8(addr)
    local hi = cpu:readu8((addr + 1) & 0xFFFF)
    return (lo | (hi << 8)) & 0xFFFF
end

-- Helper: Skip cycle if page boundary crossed (PITFALLS.md §Pitfall 12)
local function skipPageCross(cpu, addr1, addr2)
    -- Page is determined by high byte
    if (addr1 & 0xFF00) ~= (addr2 & 0xFF00) then
        cpu.skipCycles = cpu.skipCycles + 1
    end
end

-- Helper: Set overflow flag for ADC/SBC (PITFALLS.md §Pitfall 2, verified algorithm)
-- V = (!(A ^ src) & (A ^ result) & 0x80) ~= 0
local function setOverflow(cpu, a, src, result)
    result = result & 0xFF
    local xor1 = bit32.bxor(a, src)
    local xor2 = bit32.bxor(a, result)
    cpu.P.V = (bit32.bnot(xor1) & xor2 & 0x80) ~= 0
end

-- BRK (0x00): Force interrupt
OPS[0x00] = function(cpu)
    -- BRK is a 2-byte instruction (padding byte after opcode)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    -- Push PC (high byte first, then low)
    cpu:pushStack((cpu.PC >> 8) & 0xFF)
    cpu:pushStack(cpu.PC & 0xFF)
    -- Push status register with B flag set
    local flags = (cpu.P.N and 0x80 or 0) |
                 (cpu.P.V and 0x40 or 0) |
                 0x20 |  -- Bit 5 always 1
                 0x10 |  -- B flag set for BRK
                 (cpu.P.D and 0x08 or 0) |
                 (cpu.P.I and 0x04 or 0) |
                 (cpu.P.Z and 0x02 or 0) |
                 (cpu.P.C and 0x01 or 0)
    cpu:pushStack(flags)
    cpu.P.I = true
    -- Read interrupt vector at 0xFFFE
    cpu.PC = cpu:readu16(0xFFFE)
    return 7
end

-- ORA IndirectX (0x01)
OPS[0x01] = function(cpu)
    local zp_addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local addr = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A | value) & 0xFF
    cpu:setZN(cpu.A)
    return 6
end

-- ORA ZeroPage (0x05)
OPS[0x05] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A | value) & 0xFF
    cpu:setZN(cpu.A)
    return 3
end

-- ASL ZeroPage (0x06)
OPS[0x06] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.C = (value & 0x80) ~= 0
    value = (value << 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 5
end

-- PHP (0x08) - Push Processor Status
OPS[0x08] = function(cpu)
    local flags = (cpu.P.N and 0x80 or 0) |
                 (cpu.P.V and 0x40 or 0) |
                 0x20 |  -- Bit 5 always 1
                 0x10 |  -- B flag set when pushing via PHP
                 (cpu.P.D and 0x08 or 0) |
                 (cpu.P.I and 0x04 or 0) |
                 (cpu.P.Z and 0x02 or 0) |
                 (cpu.P.C and 0x01 or 0)
    cpu:pushStack(flags)
    return 3
end

-- ORA Immediate (0x09)
OPS[0x09] = function(cpu)
    local operand = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.A = (cpu.A | operand) & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- ASL Accumulator (0x0A)
OPS[0x0A] = function(cpu)
    cpu.P.C = (cpu.A & 0x80) ~= 0
    cpu.A = (cpu.A << 1) & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- ORA Absolute (0x0D)
OPS[0x0D] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A | value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ASL Absolute (0x0E)
OPS[0x0E] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.C = (value & 0x80) ~= 0
    value = (value << 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- BPL (0x10) - Branch if Plus (N=0)
OPS[0x10] = function(cpu)
    local offset = cpu:readu8(cpu.PC)
    -- Sign-extend offset (treat as signed 8-bit)
    if offset >= 0x80 then offset = offset - 0x100 end
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    if not cpu.P.N then
        -- Page boundary crossing penalty
        local newPC = (cpu.PC + offset) & 0xFFFF
        if (cpu.PC & 0xFF00) ~= (newPC & 0xFF00) then
            cpu.skipCycles = cpu.skipCycles + 2  -- +1 for branch taken, +1 for page cross
        else
            cpu.skipCycles = cpu.skipCycles + 1  -- +1 for branch taken
        end
        cpu.PC = newPC
        return 3  -- Minimum cycles for taken branch
    end
    return 2  -- Not taken
end

-- CLC (0x18) - Clear Carry
OPS[0x18] = function(cpu)
    cpu.P.C = false
    return 2
end

-- ORA IndirectY (0x11)
OPS[0x11] = function(cpu)
    local zp_addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local base = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A | value) & 0xFF
    cpu:setZN(cpu.A)
    return 5
end

-- ORA ZeroPageX (0x15)
OPS[0x15] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A | value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ASL ZeroPageX (0x16)
OPS[0x16] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.C = (value & 0x80) ~= 0
    value = (value << 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- CLI (0x58) - Clear Interrupt Disable
OPS[0x58] = function(cpu)
    cpu.P.I = false
    return 2
end

-- ORA AbsoluteY (0x19)
OPS[0x19] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A | value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ORA AbsoluteX (0x1D)
OPS[0x1D] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A | value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ASL AbsoluteX (0x1E)
OPS[0x1E] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.C = (value & 0x80) ~= 0
    value = (value << 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 7
end

-- JSR (0x20) - Jump to Subroutine
OPS[0x20] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF  -- Push PC-1 (point to last byte of JSR)
    cpu:pushStack((cpu.PC >> 8) & 0xFF)
    cpu:pushStack(cpu.PC & 0xFF)
    cpu.PC = addr
    return 6
end

-- AND IndirectX (0x21)
OPS[0x21] = function(cpu)
    local zp_addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local addr = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A & value) & 0xFF
    cpu:setZN(cpu.A)
    return 6
end

-- BIT ZeroPage (0x24)
OPS[0x24] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.Z = (cpu.A & value) == 0
    cpu.P.V = (value & 0x40) ~= 0
    cpu.P.N = (value & 0x80) ~= 0
    return 3
end

-- AND ZeroPage (0x25)
OPS[0x25] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A & value) & 0xFF
    cpu:setZN(cpu.A)
    return 3
end

-- ROL ZeroPage (0x26)
OPS[0x26] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    local oldC = cpu.P.C
    cpu.P.C = (value & 0x80) ~= 0
    value = ((value << 1) | (oldC and 1 or 0)) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 5
end

-- PLP (0x28) - Pull Processor Status
OPS[0x28] = function(cpu)
    local flags = cpu:pullStack()
    cpu.P.N = (flags & 0x80) ~= 0
    cpu.P.V = (flags & 0x40) ~= 0
    cpu.P._ = true  -- Bit 5 always 1
    cpu.P.B = false  -- B flag cleared when pulled from stack
    cpu.P.D = (flags & 0x08) ~= 0
    cpu.P.I = (flags & 0x04) ~= 0
    cpu.P.Z = (flags & 0x02) ~= 0
    cpu.P.C = (flags & 0x01) ~= 0
    return 4
end

-- AND Immediate (0x29)
OPS[0x29] = function(cpu)
    local operand = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.A = (cpu.A & operand) & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- ROL Accumulator (0x2A)
OPS[0x2A] = function(cpu)
    local oldC = cpu.P.C
    cpu.P.C = (cpu.A & 0x80) ~= 0
    cpu.A = ((cpu.A << 1) | (oldC and 1 or 0)) & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- BIT Absolute (0x2C)
OPS[0x2C] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.Z = (cpu.A & value) == 0
    cpu.P.V = (value & 0x40) ~= 0
    cpu.P.N = (value & 0x80) ~= 0
    return 4
end

-- AND Absolute (0x2D)
OPS[0x2D] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A & value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ROL Absolute (0x2E)
OPS[0x2E] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = cpu:readu8(addr)
    local oldC = cpu.P.C
    cpu.P.C = (value & 0x80) ~= 0
    value = ((value << 1) | (oldC and 1 or 0)) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- BMI (0x30) - Branch if Minus (N=1)
OPS[0x30] = function(cpu)
    local offset = cpu:readu8(cpu.PC)
    if offset >= 0x80 then offset = offset - 0x100 end
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    if cpu.P.N then
        local newPC = (cpu.PC + offset) & 0xFFFF
        if (cpu.PC & 0xFF00) ~= (newPC & 0xFF00) then
            cpu.skipCycles = cpu.skipCycles + 2
        else
            cpu.skipCycles = cpu.skipCycles + 1
        end
        cpu.PC = newPC
        return 3
    end
    return 2
end

-- SEC (0x38) - Set Carry
OPS[0x38] = function(cpu)
    cpu.P.C = true
    return 2
end

-- AND IndirectY (0x31)
OPS[0x31] = function(cpu)
    local zp_addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local base = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A & value) & 0xFF
    cpu:setZN(cpu.A)
    return 5
end

-- AND ZeroPageX (0x35)
OPS[0x35] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A & value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ROL ZeroPageX (0x36)
OPS[0x36] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    local oldC = cpu.P.C
    cpu.P.C = (value & 0x80) ~= 0
    value = ((value << 1) | (oldC and 1 or 0)) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- SEI (0x78) - Set Interrupt Disable
OPS[0x78] = function(cpu)
    cpu.P.I = true
    return 2
end

-- AND AbsoluteY (0x39)
OPS[0x39] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A & value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- AND AbsoluteX (0x3D)
OPS[0x3D] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A & value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ROL AbsoluteX (0x3E)
OPS[0x3E] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:readu8(addr)
    local oldC = cpu.P.C
    cpu.P.C = (value & 0x80) ~= 0
    value = ((value << 1) | (oldC and 1 or 0)) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 7
end

-- RTI (0x40) - Return from Interrupt
OPS[0x40] = function(cpu)
    local flags = cpu:pullStack()
    cpu.P.N = (flags & 0x80) ~= 0
    cpu.P.V = (flags & 0x40) ~= 0
    cpu.P._ = true
    cpu.P.B = false
    cpu.P.D = (flags & 0x08) ~= 0
    cpu.P.I = (flags & 0x04) ~= 0
    cpu.P.Z = (flags & 0x02) ~= 0
    cpu.P.C = (flags & 0x01) ~= 0
    local lo = cpu:pullStack()
    local hi = cpu:pullStack()
    cpu.PC = (lo | (hi << 8)) & 0xFFFF
    return 6
end

-- EOR IndirectX (0x41)
OPS[0x41] = function(cpu)
    local zp_addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local addr = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A ~ value) & 0xFF
    cpu:setZN(cpu.A)
    return 6
end

-- EOR ZeroPage (0x45)
OPS[0x45] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A ~ value) & 0xFF
    cpu:setZN(cpu.A)
    return 3
end

-- LSR ZeroPage (0x46)
OPS[0x46] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.C = (value & 0x01) ~= 0
    value = (value >> 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 5
end

-- PHA (0x48) - Push Accumulator
OPS[0x48] = function(cpu)
    cpu:pushStack(cpu.A)
    return 3
end

-- EOR Immediate (0x49)
OPS[0x49] = function(cpu)
    local operand = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.A = (cpu.A ~ operand) & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- LSR Accumulator (0x4A)
OPS[0x4A] = function(cpu)
    cpu.P.C = (cpu.A & 0x01) ~= 0
    cpu.A = (cpu.A >> 1) & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- JMP Absolute (0x4C)
OPS[0x4C] = function(cpu)
    cpu.PC = cpu:readu16(cpu.PC)
    return 3
end

-- EOR Absolute (0x4D)
OPS[0x4D] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A ~ value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- LSR Absolute (0x4E)
OPS[0x4E] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.C = (value & 0x01) ~= 0
    value = (value >> 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- BVC (0x50) - Branch if oVerflow Clear
OPS[0x50] = function(cpu)
    local offset = cpu:readu8(cpu.PC)
    if offset >= 0x80 then offset = offset - 0x100 end
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    if not cpu.P.V then
        local newPC = (cpu.PC + offset) & 0xFFFF
        if (cpu.PC & 0xFF00) ~= (newPC & 0xFF00) then
            cpu.skipCycles = cpu.skipCycles + 2
        else
            cpu.skipCycles = cpu.skipCycles + 1
        end
        cpu.PC = newPC
        return 3
    end
    return 2
end

-- EOR IndirectY (0x51)
OPS[0x51] = function(cpu)
    local zp_addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local base = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A ~ value) & 0xFF
    cpu:setZN(cpu.A)
    return 5
end

-- EOR ZeroPageX (0x55)
OPS[0x55] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A ~ value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- LSR ZeroPageX (0x56)
OPS[0x56] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.C = (value & 0x01) ~= 0
    value = (value >> 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- EOR AbsoluteY (0x59)
OPS[0x59] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A ~ value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- EOR AbsoluteX (0x5D)
OPS[0x5D] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local value = cpu:readu8(addr)
    cpu.A = (cpu.A ~ value) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- LSR AbsoluteX (0x5E)
OPS[0x5E] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:readu8(addr)
    cpu.P.C = (value & 0x01) ~= 0
    value = (value >> 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 7
end

-- RTS (0x60) - Return from Subroutine
OPS[0x60] = function(cpu)
    local lo = cpu:pullStack()
    local hi = cpu:pullStack()
    cpu.PC = ((lo | (hi << 8)) + 1) & 0xFFFF
    return 6
end

-- ADC IndirectX (0x61)
OPS[0x61] = function(cpu)
    local zp_addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local addr = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A + operand + carry) & 0xFFFF
    cpu.P.C = (result > 0xFF)
    setOverflow(cpu, cpu.A, operand, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 6
end

-- ADC ZeroPage (0x65)
OPS[0x65] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A + operand + carry) & 0xFFFF
    cpu.P.C = (result > 0xFF)
    setOverflow(cpu, cpu.A, operand, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 3
end

-- ROR ZeroPage (0x66)
OPS[0x66] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    local oldC = cpu.P.C
    cpu.P.C = (value & 0x01) ~= 0
    value = ((value >> 1) | (oldC and 0x80 or 0)) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 5
end

-- PLA (0x68) - Pull Accumulator
OPS[0x68] = function(cpu)
    cpu.A = cpu:pullStack()
    cpu:setZN(cpu.A)
    return 4
end

-- ADC Immediate (0x69)
OPS[0x69] = function(cpu)
    local operand = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A + operand + carry) & 0xFFFF
    cpu.P.C = (result > 0xFF)
    setOverflow(cpu, cpu.A, operand, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- ROR Accumulator (0x6A)
OPS[0x6A] = function(cpu)
    local oldC = cpu.P.C
    cpu.P.C = (cpu.A & 0x01) ~= 0
    cpu.A = ((cpu.A >> 1) | (oldC and 0x80 or 0)) & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- JMP Indirect (0x6C) - with 6502 indirect bug
OPS[0x6C] = function(cpu)
    local ptr = cpu:readu16(cpu.PC)
    local lo = cpu:readu8(ptr)
    -- 6502 bug: when pointer is at page boundary (e.g., $10FF), high byte reads from
    -- same page instead of next page (e.g., $1000 instead of $1100)
    local page = ptr & 0xFF00
    local hi = cpu:readu8(page | ((ptr + 1) & 0xFF))
    cpu.PC = (lo | (hi << 8)) & 0xFFFF
    return 5
end

-- ADC Absolute (0x6D)
OPS[0x6D] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A + operand + carry) & 0xFFFF
    cpu.P.C = (result > 0xFF)
    setOverflow(cpu, cpu.A, operand, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ROR Absolute (0x6E)
OPS[0x6E] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = cpu:readu8(addr)
    local oldC = cpu.P.C
    cpu.P.C = (value & 0x01) ~= 0
    value = ((value >> 1) | (oldC and 0x80 or 0)) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- BVS (0x70) - Branch if oVerflow Set
OPS[0x70] = function(cpu)
    local offset = cpu:readu8(cpu.PC)
    if offset >= 0x80 then offset = offset - 0x100 end
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    if cpu.P.V then
        local newPC = (cpu.PC + offset) & 0xFFFF
        if (cpu.PC & 0xFF00) ~= (newPC & 0xFF00) then
            cpu.skipCycles = cpu.skipCycles + 2
        else
            cpu.skipCycles = cpu.skipCycles + 1
        end
        cpu.PC = newPC
        return 3
    end
    return 2
end

-- ADC IndirectY (0x71)
OPS[0x71] = function(cpu)
    local zp_addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local base = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A + operand + carry) & 0xFFFF
    cpu.P.C = (result > 0xFF)
    setOverflow(cpu, cpu.A, operand, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 5
end

-- ADC ZeroPageX (0x75)
OPS[0x75] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A + operand + carry) & 0xFFFF
    cpu.P.C = (result > 0xFF)
    setOverflow(cpu, cpu.A, operand, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ROR ZeroPageX (0x76)
OPS[0x76] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = cpu:readu8(addr)
    local oldC = cpu.P.C
    cpu.P.C = (value & 0x01) ~= 0
    value = ((value >> 1) | (oldC and 0x80 or 0)) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- ADC AbsoluteY (0x79)
OPS[0x79] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A + operand + carry) & 0xFFFF
    cpu.P.C = (result > 0xFF)
    setOverflow(cpu, cpu.A, operand, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ADC AbsoluteX (0x7D)
OPS[0x7D] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A + operand + carry) & 0xFFFF
    cpu.P.C = (result > 0xFF)
    setOverflow(cpu, cpu.A, operand, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- ROR AbsoluteX (0x7E)
OPS[0x7E] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:readu8(addr)
    local oldC = cpu.P.C
    cpu.P.C = (value & 0x01) ~= 0
    value = ((value >> 1) | (oldC and 0x80 or 0)) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 7
end

-- NOP (0xEA) - Official NOP (most common)
OPS[0xEA] = function(cpu)
    return 2
end

-- STA IndirectX (0x81)
OPS[0x81] = function(cpu)
    local zp_addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local addr = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    cpu:writeu8(addr, cpu.A)
    return 6
end

-- STA ZeroPage (0x85)
OPS[0x85] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:writeu8(addr, cpu.A)
    return 3
end

-- STX ZeroPage (0x86)
OPS[0x86] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:writeu8(addr, cpu.X)
    return 3
end

-- STA ZeroPageX (0x95)
OPS[0x95] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:writeu8(addr, cpu.A)
    return 4
end

-- STX ZeroPageY (0x96)
OPS[0x96] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.Y) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:writeu8(addr, cpu.X)
    return 4
end

-- STA Absolute (0x8D)
OPS[0x8D] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    cpu:writeu8(addr, cpu.A)
    return 4
end

-- STA AbsoluteX (0x99)
OPS[0x99] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    cpu:writeu8(addr, cpu.A)
    return 5
end

-- STA AbsoluteY (0x91)
OPS[0x91] = function(cpu)
    local zp_addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local base = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    cpu:writeu8(addr, cpu.A)
    return 6
end

-- STX Absolute (0x8E)
OPS[0x8E] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    cpu:writeu8(addr, cpu.X)
    return 4
end

-- STY ZeroPage (0x84)
OPS[0x84] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:writeu8(addr, cpu.Y)
    return 3
end

-- STY ZeroPageX (0x94)
OPS[0x94] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:writeu8(addr, cpu.Y)
    return 4
end

-- STY Absolute (0x8C)
OPS[0x8C] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    cpu:writeu8(addr, cpu.Y)
    return 4
end

-- LDY Immediate (0xA0)
OPS[0xA0] = function(cpu)
    cpu.Y = cpu:readu8(cpu.PC) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:setZN(cpu.Y)
    return 2
end

-- LDA IndirectX (0xA1)
OPS[0xA1] = function(cpu)
    local zp_addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local addr = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    cpu.A = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.A)
    return 6
end

-- LDX Immediate (0xA2)
OPS[0xA2] = function(cpu)
    cpu.X = cpu:readu8(cpu.PC) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:setZN(cpu.X)
    return 2
end

-- LDY ZeroPage (0xA4)
OPS[0xA4] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.Y = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.Y)
    return 3
end

-- LDA ZeroPage (0xA5)
OPS[0xA5] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.A = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.A)
    return 3
end

-- LDX ZeroPage (0xA6)
OPS[0xA6] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.X = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.X)
    return 3
end

-- TAY (0xA8) - Transfer A to Y
OPS[0xA8] = function(cpu)
    cpu.Y = cpu.A
    cpu:setZN(cpu.Y)
    return 2
end

-- LDA Immediate (0xA9)
OPS[0xA9] = function(cpu)
    cpu.A = cpu:readu8(cpu.PC) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu:setZN(cpu.A)
    return 2
end

-- TAX (0xAA) - Transfer A to X
OPS[0xAA] = function(cpu)
    cpu.X = cpu.A
    cpu:setZN(cpu.X)
    return 2
end

-- LDY Absolute (0xAC)
OPS[0xAC] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    cpu.Y = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.Y)
    return 4
end

-- LDA Absolute (0xAD)
OPS[0xAD] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    cpu.A = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- LDX Absolute (0xAE)
OPS[0xAE] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    cpu.X = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.X)
    return 4
end

-- LDA IndirectY (0xB1)
OPS[0xB1] = function(cpu)
    local zp_addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local base = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    cpu.A = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.A)
    return 5
end

-- LDA ZeroPageX (0xB5)
OPS[0xB5] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.A = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- LDY ZeroPageX (0xB4)
OPS[0xB4] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    cpu.Y = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.Y)
    return 4
end

-- LDA AbsoluteY (0xB9)
OPS[0xB9] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    cpu.A = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- LDA AbsoluteX (0xBD)
OPS[0xBD] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    skipPageCross(cpu, base, addr)
    cpu.A = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- LDY AbsoluteX (0xBC)
OPS[0xBC] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    skipPageCross(cpu, base, addr)
    cpu.Y = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.Y)
    return 4
end

-- LDX AbsoluteY (0xBE)
OPS[0xBE] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    cpu.X = cpu:readu8(addr) & 0xFF
    cpu:setZN(cpu.X)
    return 4
end

-- CPY Immediate (0xC0)
OPS[0xC0] = function(cpu)
    local operand = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local result = (cpu.Y - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 2
end

-- CPY ZeroPage (0xC4)
OPS[0xC4] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local operand = cpu:readu8(addr)
    local result = (cpu.Y - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 3
end

-- CPY Absolute (0xCC)
OPS[0xCC] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local operand = cpu:readu8(addr)
    local result = (cpu.Y - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 4
end

-- DEC ZeroPage (0xC6)
OPS[0xC6] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = (cpu:readu8(addr) - 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 5
end

-- INY (0xC8) - Increment Y
OPS[0xC8] = function(cpu)
    cpu.Y = (cpu.Y + 1) & 0xFF
    cpu:setZN(cpu.Y)
    return 2
end

-- DEX (0xCA) - Decrement X
OPS[0xCA] = function(cpu)
    cpu.X = (cpu.X - 1) & 0xFF
    cpu:setZN(cpu.X)
    return 2
end

-- DEC Absolute (0xCE)
OPS[0xCE] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = (cpu:readu8(addr) - 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- BCC (0x90) - Branch if Carry Clear
OPS[0x90] = function(cpu)
    local offset = cpu:readu8(cpu.PC)
    if offset >= 0x80 then offset = offset - 0x100 end
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    if not cpu.P.C then
        local newPC = (cpu.PC + offset) & 0xFFFF
        if (cpu.PC & 0xFF00) ~= (newPC & 0xFF00) then
            cpu.skipCycles = cpu.skipCycles + 2
        else
            cpu.skipCycles = cpu.skipCycles + 1
        end
        cpu.PC = newPC
        return 3
    end
    return 2
end

-- BCS (0xB0) - Branch if Carry Set
OPS[0xB0] = function(cpu)
    local offset = cpu:readu8(cpu.PC)
    if offset >= 0x80 then offset = offset - 0x100 end
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    if cpu.P.C then
        local newPC = (cpu.PC + offset) & 0xFFFF
        if (cpu.PC & 0xFF00) ~= (newPC & 0xFF00) then
            cpu.skipCycles = cpu.skipCycles + 2
        else
            cpu.skipCycles = cpu.skipCycles + 1
        end
        cpu.PC = newPC
        return 3
    end
    return 2
end

-- BNE (0xD0) - Branch if Not Equal (Z=0)
OPS[0xD0] = function(cpu)
    local offset = cpu:readu8(cpu.PC)
    if offset >= 0x80 then offset = offset - 0x100 end
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    if not cpu.P.Z then
        local newPC = (cpu.PC + offset) & 0xFFFF
        if (cpu.PC & 0xFF00) ~= (newPC & 0xFF00) then
            cpu.skipCycles = cpu.skipCycles + 2
        else
            cpu.skipCycles = cpu.skipCycles + 1
        end
        cpu.PC = newPC
        return 3
    end
    return 2
end

-- BEQ (0xF0) - Branch if Equal (Z=1)
OPS[0xF0] = function(cpu)
    local offset = cpu:readu8(cpu.PC)
    if offset >= 0x80 then offset = offset - 0x100 end
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    if cpu.P.Z then
        local newPC = (cpu.PC + offset) & 0xFFFF
        if (cpu.PC & 0xFF00) ~= (newPC & 0xFF00) then
            cpu.skipCycles = cpu.skipCycles + 2
        else
            cpu.skipCycles = cpu.skipCycles + 1
        end
        cpu.PC = newPC
        return 3
    end
    return 2
end

-- CMP Immediate (0xC9)
OPS[0xC9] = function(cpu)
    local operand = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local result = (cpu.A - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)  -- Carry set if A >= operand
    cpu:setZN(result)
    return 2
end

-- CMP ZeroPage (0xC5)
OPS[0xC5] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local operand = cpu:readu8(addr)
    local result = (cpu.A - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 3
end

-- DEC ZeroPageX (0xD6)
OPS[0xD6] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = (cpu:readu8(addr) - 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- CMP IndirectX (0xC1)
OPS[0xC1] = function(cpu)
    local zp_addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local addr = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local operand = cpu:readu8(addr)
    local result = (cpu.A - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 6
end

-- CMP IndirectY (0xD1)
OPS[0xD1] = function(cpu)
    local zp_addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local base = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local result = (cpu.A - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 5
end

-- CMP ZeroPageX (0xD5)
OPS[0xD5] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local operand = cpu:readu8(addr)
    local result = (cpu.A - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 4
end

-- DEC AbsoluteX (0xDE)
OPS[0xDE] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    local value = (cpu:readu8(addr) - 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 7
end

-- CMP Absolute (0xCD)
OPS[0xCD] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local operand = cpu:readu8(addr)
    local result = (cpu.A - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 4
end

-- CMP AbsoluteX (0xDD)
OPS[0xDD] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local result = (cpu.A - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 4
end

-- CMP AbsoluteY (0xD9)
OPS[0xD9] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local result = (cpu.A - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 4
end

-- CPX Immediate (0xE0)
OPS[0xE0] = function(cpu)
    local operand = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local result = (cpu.X - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 2
end

-- CPX ZeroPage (0xE4)
OPS[0xE4] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local operand = cpu:readu8(addr)
    local result = (cpu.X - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 3
end

-- CPX Absolute (0xEC)
OPS[0xEC] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local operand = cpu:readu8(addr)
    local result = (cpu.X - operand) & 0xFFFF
    cpu.P.C = (result < 0x100)
    cpu:setZN(result)
    return 4
end

-- SBC IndirectX (0xE1)
OPS[0xE1] = function(cpu)
    local zp_addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local addr = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A - operand - (1 - carry)) & 0xFFFF
    cpu.P.C = (result < 0x100)  -- NOT borrow
    setOverflow(cpu, cpu.A, bit32.bnot(operand) & 0xFF, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 6
end

-- SBC ZeroPage (0xE5)
OPS[0xE5] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A - operand - (1 - carry)) & 0xFFFF
    cpu.P.C = (result < 0x100)
    setOverflow(cpu, cpu.A, bit32.bnot(operand) & 0xFF, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 3
end

-- SBC Immediate (0xE9)
OPS[0xE9] = function(cpu)
    local operand = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A - operand - (1 - carry)) & 0xFFFF
    cpu.P.C = (result < 0x100)
    setOverflow(cpu, cpu.A, bit32.bnot(operand) & 0xFF, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 2
end

-- SBC Absolute (0xED)
OPS[0xED] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A - operand - (1 - carry)) & 0xFFFF
    cpu.P.C = (result < 0x100)
    setOverflow(cpu, cpu.A, bit32.bnot(operand) & 0xFF, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- SBC IndirectY (0xF1)
OPS[0xF1] = function(cpu)
    local zp_addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local base = cpu:readu8(zp_addr) | (cpu:readu8((zp_addr + 1) & 0xFF) << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A - operand - (1 - carry)) & 0xFFFF
    cpu.P.C = (result < 0x100)
    setOverflow(cpu, cpu.A, bit32.bnot(operand) & 0xFF, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 5
end

-- SBC ZeroPageX (0xF5)
OPS[0xF5] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A - operand - (1 - carry)) & 0xFFFF
    cpu.P.C = (result < 0x100)
    setOverflow(cpu, cpu.A, bit32.bnot(operand) & 0xFF, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- SBC AbsoluteY (0xF9)
OPS[0xF9] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.Y) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A - operand - (1 - carry)) & 0xFFFF
    cpu.P.C = (result < 0x100)
    setOverflow(cpu, cpu.A, bit32.bnot(operand) & 0xFF, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- SBC AbsoluteX (0xFD)
OPS[0xFD] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    skipPageCross(cpu, base, addr)
    local operand = cpu:readu8(addr)
    local carry = cpu.P.C and 1 or 0
    local result = (cpu.A - operand - (1 - carry)) & 0xFFFF
    cpu.P.C = (result < 0x100)
    setOverflow(cpu, cpu.A, bit32.bnot(operand) & 0xFF, result)
    cpu.A = result & 0xFF
    cpu:setZN(cpu.A)
    return 4
end

-- INC ZeroPage (0xE6)
OPS[0xE6] = function(cpu)
    local addr = cpu:readu8(cpu.PC)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = (cpu:readu8(addr) + 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 5
end

-- INX (0xE8) - Increment X
OPS[0xE8] = function(cpu)
    cpu.X = (cpu.X + 1) & 0xFF
    cpu:setZN(cpu.X)
    return 2
end

-- INC Absolute (0xEE)
OPS[0xEE] = function(cpu)
    local addr = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local value = (cpu:readu8(addr) + 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- INC ZeroPageX (0xF6)
OPS[0xF6] = function(cpu)
    local addr = (cpu:readu8(cpu.PC) + cpu.X) & 0xFF
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local value = (cpu:readu8(addr) + 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 6
end

-- INC AbsoluteX (0xFE)
OPS[0xFE] = function(cpu)
    local base = cpu:readu16(cpu.PC)
    cpu.PC = (cpu.PC + 2) & 0xFFFF
    local addr = (base + cpu.X) & 0xFFFF
    local value = (cpu:readu8(addr) + 1) & 0xFF
    cpu:writeu8(addr, value)
    cpu:setZN(value)
    return 7
end

-- BEQ (0xF0) - Already defined above with other branches

-- TYA (0x98) - Transfer Y to A
OPS[0x98] = function(cpu)
    cpu.A = cpu.Y
    cpu:setZN(cpu.A)
    return 2
end

-- TXA (0x8A) - Transfer X to A
OPS[0x8A] = function(cpu)
    cpu.A = cpu.X
    cpu:setZN(cpu.A)
    return 2
end

-- TXS (0x9A) - Transfer X to SP
OPS[0x9A] = function(cpu)
    cpu.SP = cpu.X
    return 2
end

-- TAX (0xAA) - Transfer A to X (already defined above)

-- TSX (0xBA) - Transfer SP to X
OPS[0xBA] = function(cpu)
    cpu.X = cpu.SP
    cpu:setZN(cpu.X)
    return 2
end

-- CLV (0xB8) - Clear oVerflow
OPS[0xB8] = function(cpu)
    cpu.P.V = false
    return 2
end

-- CLD (0xD8) - Clear Decimal mode
OPS[0xD8] = function(cpu)
    cpu.P.D = false
    return 2
end

-- SED (0xF8) - Set Decimal mode
OPS[0xF8] = function(cpu)
    cpu.P.D = true
    return 2
end

-- DEY (0x88) - Decrement Y
OPS[0x88] = function(cpu)
    cpu.Y = (cpu.Y - 1) & 0xFF
    cpu:setZN(cpu.Y)
    return 2
end

-- INY (0xC8) - Already defined above

-- DEX (0xCA) - Already defined above

-- INX (0xE8) - Already defined above

return {
    OPS = OPS,
    OperationCycles = OperationCycles
}
