--[[
    Copyright (c) 2025 pkhead

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

local path = {}
local strmatch = string.match
local strgmatch = string.gmatch

---Get the file extension of a path
---@param path string
---@return string? ext The file extension, or nil if non-existent.
function path.getExtension(path)
    return strmatch(path, "%.[^.]+$")
end

---Get the file name of a path
---@param path string
---@return string?
function path.getName(path)
    return strmatch(path, "[^/]+$")
end

---Get the path to the containing directory of the path
---@param path string
---@return string?
function path.getDirName(path)
    local idx = strmatch(path, "()[^/]+$")
    if idx == nil or idx == 1 then
        return nil
    end

    return string.sub(path, 1, idx - 1)
end

function path.split(path)
    local res = {}
    for v in strgmatch(path, "[^/]+") do
        res[#res+1] = v
    end
    return res
end

function path.splitIterator(path)
    return strgmatch(path, "[^/]+")
end

---Get the file name of a path without its extension
---@param path string
---@return string
function path.getNameWithoutExtension(path)
    path = strmatch(path, "[^/]+$")
    return strmatch(path, "(.*)%.[^.]+$")
end

function path.join(...)
    local t = ...
    if type(t) == "table" then
        return table.concat(t, "/")
    else
        return table.concat({...}, "/")
    end
end

function path.normalize(path)
    local stack = {}
    local depth = 0

    for v in strgmatch(path, "[^/]+") do
        if v == ".." then
            if depth <= 0 then
                stack[#stack+1] = v
            else
                stack[#stack] = nil
            end

            depth = depth - 1
        elseif v ~= "." then
            stack[#stack+1] = v
            depth = depth + 1
        end
    end

    if #stack == 0 then
        return "."
    else
        return table.concat(stack, "/")
    end
end

return path