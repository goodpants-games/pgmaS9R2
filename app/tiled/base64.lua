--[[
Copyright (c) 2025 pkhaed

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
--]]

local module_root = (...):gsub("%.base64$", "")
local bit = require(module_root .. ".bitcompat")
local tablecompat = require(module_root .. ".tablecompat")
local table_clear, table_unpack = tablecompat.clear, tablecompat.unpack

local digits = {}
local digitStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
for i=1, string.len(digitStr) do
    digits[string.byte(digitStr, i)] = i-1
end
    
local function readBase64(str)
    local strlen = string.len(str)
    if strlen % 4 ~= 0 then
        local oldLen = strlen
        strlen = math.ceil(strlen / 4) * 4
        str = str .. string.rep("=", strlen - oldLen)

        --error("base64 string is not byte-aligned", 1)
    end
    
    local out = {}
    local byteBuf = {}
    
    for i=1, strlen, 4 do
        local a, b, c, d =
            digits[string.byte(str, i)],
            digits[string.byte(str, i+1)],
            digits[string.byte(str, i+2)],
            digits[string.byte(str, i+3)]
            
        if a == nil then
            error(("%i: invalid character"):format(i, str:sub(i, i)), 2)
        end

        if b == nil then
            error(("%i: invalid character"):format(i+1, str:sub(i+1, i+1)), 2)
        end

        if c == nil then
            error(("%i: invalid character"):format(i+2, str:sub(i+2, i+2)), 2)
        end

        if d == nil then
            error(("%i: invalid character"):format(i+3, str:sub(i+3, i+3)), 2)
        end

        -- bytes:  AAAAAA AA|BBBB BBBB|CC CCCCCC
        -- base64: aaaaaa|bb bbbb|cccc cc|dddddd
        byteBuf[#byteBuf+1] = bit.band( bit.bor(bit.lshift(a, 2), bit.rshift(b, 4)), 0xFF )

        if c < 64 then
            byteBuf[#byteBuf+1] = bit.band( bit.bor(bit.lshift(b, 4), bit.rshift(c, 2)), 0xFF )
        end

        if d < 64 then
            byteBuf[#byteBuf+1] = bit.band( bit.bor(bit.lshift(c, 6), d), 0xFF )
        end

        if #byteBuf >= 512 then
            table.insert(out, string.char(table_unpack(byteBuf)))
            table_clear(byteBuf)
        end
    end
    
    if #byteBuf > 0 then
        table.insert(out, string.char(table_unpack(byteBuf)))
    end
    
    return table.concat(out)
end

local text = readBase64("SGVsbG8sIHdvcmxkIQ==")
assert(text == "Hello, world!", "readBase64 test failed: " .. text)

local text = readBase64("SGVsbG8sIHdvcmxkIQ")
assert(text == "Hello, world!", "readBase64 test failed: " .. text)

return readBase64