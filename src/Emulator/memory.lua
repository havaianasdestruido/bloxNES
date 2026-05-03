--!native
-- Memory Bus for 6502 CPU
-- Ports SimpleNES C++ MainBus.h to Luau
-- Uses buffer type per D-01, D-02 (verified 3x faster than tables)

local MemoryBus = {}

-- 64KB address space using buffer (D-01, D-02)
MemoryBus.buffer = buffer.create(0x10000)

-- Memory read with proper address mirroring
function MemoryBus:read(addr)
    addr = addr & 0xFFFF  -- Mask to 16-bit address

    if addr < 0x2000 then
        -- Internal RAM: $0000-$07FF, mirrored every $800 bytes
        return buffer.readu8(self.buffer, addr & 0x07FF)

    elseif addr < 0x4000 then
        -- PPU registers: $2000-$2007, mirrored every 8 bytes to $3FFF
        -- Phase 1: return 0 (stub for PPU phase 2)
        return 0

    elseif addr < 0x4020 then
        -- APU and I/O: $4000-$4017 (APU registers + controller ports)
        -- Phase 1: handle $4017 (frame counter), rest are stubs
        if addr == 0x4017 then
            return buffer.readu8(self.buffer, addr)
        end
        return 0

    else
        -- Cartridge space: $4020-$FFFF (PRG-ROM, mappers)
        -- Phase 1: return 0 (stub for phase 5 mappers)
        return 0
    end
end

-- Memory write with proper address mirroring
function MemoryBus:write(addr, value)
    addr = addr & 0xFFFF
    value = value & 0xFF  -- Mask to 8-bit

    if addr < 0x2000 then
        -- Internal RAM with mirroring
        buffer.writeu8(self.buffer, addr & 0x07FF, value)

    elseif addr < 0x4000 then
        -- PPU registers (Phase 2 implementation)
        -- Phase 1: stub, ignore writes

    elseif addr < 0x4020 then
        -- APU and I/O
        buffer.writeu8(self.buffer, addr, value)

    else
        -- Cartridge space (Phase 5 mappers)
        -- Phase 1: stub, ignore writes
    end
end

-- Initialize RAM to random values (NES power-up behavior, PITFALLS.md §Pitfall 7)
function MemoryBus:powerUp()
    for i = 0, 0x07FF do
        buffer.writeu8(self.buffer, i, math.random(0, 255))
    end
    -- Clear APU registers
    for i = 0x4000, 0x4017 do
        buffer.writeu8(self.buffer, i, 0)
    end
end

return MemoryBus
