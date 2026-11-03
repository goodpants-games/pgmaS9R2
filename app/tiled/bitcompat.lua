local has_bit, bit = pcall(require, "bit")
if has_bit then
    return bit
end

local has_bit32, bit32 = pcall(require, "bit32")
if has_bit32 then
    return bit32
end

error(bit .. "\n\n" .. bit32)