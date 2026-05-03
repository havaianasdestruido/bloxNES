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
    self.pendingNMI = false
    self.pendingIRQ = false

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

-- Load opcode table (initialized at module load per D-09)
local opcodesModule = require(script.Parent.opcodes)
local OPS = opcodesModule.OPS
local OperationCycles = opcodesModule.OperationCycles

-- NMI vector address
local NMIVector = 0xFFFA
local IRQVector = 0xFFFE

-- Interrupt sequence (for NMI, IRQ, BRK)
function CPU:interruptSequence(interruptType)
    -- Push PC (high byte first)
    self:pushStack((self.PC >> 8) & 0xFF)
    self:pushStack(self.PC & 0xFF)

    -- Push status register
    local flags = (self.P.N and 0x80 or 0) |
                 (self.P.V and 0x40 or 0) |
                 0x20 |  -- Bit 5 always 1
                 (interruptType == "BRK" and 0x10 or 0) |  -- B flag only for BRK
                 (self.P.D and 0x08 or 0) |
                 0x04 |  -- I flag set when entering interrupt
                 (self.P.Z and 0x02 or 0) |
                 (self.P.C and 0x01 or 0)
    self:pushStack(flags)

    self.P.I = true

    -- Read interrupt vector
    if interruptType == "NMI" then
        self.PC = self:readu16(NMIVector)
    else
        self.PC = self:readu16(IRQVector)
    end

    self.skipCycles = self.skipCycles + 7
end

-- NMI (Non-Maskable Interrupt)
function CPU:triggerNMI()
    self.pendingNMI = true
end

-- Log CPU state in nestest format
-- Format: "PC  A  X  Y  P  SP CYC"
-- Example: "C5C8  A9 00 00  20 FD  0"
function CPU:log()
    -- Calculate P register as single byte (same as C++ logging)
    local psw = (self.P.N and 0x80 or 0) |
                (self.P.V and 0x40 or 0) |
                0x20 |  -- Bit 5 always 1
                (self.P.B and 0x10 or 0) |
                (self.P.D and 0x08 or 0) |
                (self.P.I and 0x04 or 0) |
                (self.P.Z and 0x02 or 0) |
                (self.P.C and 0x01 or 0)

    -- Calculate cycle count (based on C++: (m_cycles - 1) * 3 % 341)
    local cycle = ((self.cycles - 1) * 3) % 341

    -- Format: "PC  A  X  Y  P  SP CYC"
    return string.format("%04X %02X %02X %02X %02X %02X %3d",
        self.PC, self.A, self.X, self.Y, psw, self.SP, cycle)
end

-- Load nestest ROM (iNES format)
-- Header: 16 bytes, PRG-ROM starts at offset 16
function CPU:loadROM(romData)
    -- Verify iNES header: starts with "NES\x1a"
    if #romData < 16 then
        return false, "ROM too small for iNES header"
    end

    local header = string.sub(romData, 1, 4)
    if header ~= "NES\x1a" then
        return false, "Not a valid iNES ROM (missing NES header)"
    end

    -- Parse header
    local prgSize = romData:byte(5) * 16384  -- PRG-ROM size in 16KB units
    local chrSize = romData:byte(6) * 8192    -- CHR-ROM size in 8KB units
    local flags6 = romData:byte(7)
    local mapper = (flags6 >> 4) | (romData:byte(8) >> 4) << 4

    -- Load PRG-ROM into cartridge space ($4020-$FFFF)
    local prgStart = 17  -- After 16-byte header
    for i = 0, prgSize - 1 do
        local addr = 0x4020 + i
        if addr <= 0xFFFF then
            self.mem:write(addr, romData:byte(prgStart + i))
        end
    end

    -- For nestest, PRG-ROM is 16KB or 32KB
    -- If 16KB, mirror to $C000-$FFFF
    if prgSize == 16384 then
        for i = 0, 16383 do
            local addr = 0xC000 + i
            self.mem:write(addr, romData:byte(17 + i))
        end
    end

    return true, {prgSize = prgSize, chrSize = chrSize, mapper = mapper}
end

-- Step: execute one instruction
function CPU:step()
    self.cycles = self.cycles + 1

    -- Check if we need to skip cycles (from DMA or previous instructions)
    if self.skipCycles > 1 then
        self.skipCycles = self.skipCycles - 1
        return 0
    end
    self.skipCycles = 0

    -- Handle NMI (higher priority than IRQ)
    if self.pendingNMI then
        self:interruptSequence("NMI")
        self.pendingNMI = false
        return 7
    end

    -- Handle IRQ (if I flag not set)
    if not self.P.I and self.pendingIRQ then
        self:interruptSequence("IRQ")
        self.pendingIRQ = false
        return 7
    end

    -- Fetch opcode
    local opcode = self:readu8(self.PC)
    self.PC = (self.PC + 1) & 0xFFFF

    -- Dispatch via function table (D-08, fast dispatch)
    local handler = OPS[opcode]
    if handler then
        local cycles = handler(self)
        self.skipCycles = cycles
        return cycles
    else
        -- Unofficial/undefined opcode - treat as NOP with 1 cycle
        -- Phase 1 only implements official 56 opcodes
        return 1
    end
end

-- Signal IRQ
function CPU:signalIRQ()
    self.pendingIRQ = true
end

-- Clear IRQ
function CPU:clearIRQ()
    self.pendingIRQ = false
end

return CPU
