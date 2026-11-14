-- Additional configuration to be ran after all LOVE modules have been
-- initialized.

require("compat.love")

-- love.graphics initial setup --
Lg = love.graphics
Lg.setDefaultFilter("nearest")
Lg.setLineStyle("rough")

-- extra math functions --

---Normalize a 2D vector.
---@param x number
---@param y number
---@return number x, number y
function math.normalize(x, y)
    local len = math.sqrt(x * x + y * y)
    return x / len, y / len
end

---Returns the sign of the number, where 0 is considered positive.
function math.sign2(v)
    return v >= 0 and 1 or -1
end

-- library setup --
require("batteries"):export()

Sceneman = require("sceneman")
Sceneman.scenePrefix = "scenes."
Sceneman.setCallbackMode("manual")

local sprite = require("sprite")
sprite.fallbackAlignment = "center"

local has_tiled, tiled = pcall(require, "tiled")
if has_tiled then
    local tpath = require("tiled.path")
    function tiled.mapPath(cwd, path)
        -- change extension from .tsx to .lua
        if tpath.getExtension(path) == ".tsx" then
            path = tpath.join(tpath.getDirName(path),
                            tpath.getNameWithoutExtension(path) .. ".lua")
        end

        return tpath.normalize(tpath.join(cwd, path))
    end
end

-- set up jprof --
if Debug.enabled then
    local args = love.parsedGameArguments
    for i=1, #args do
        if args[i] == "--jprof" then
            local path = args[i+1]
            print( ("start love \"%s\" listen"):format(path) )
            local s = os.execute(("start love \"%s\" listen"):format(path))
            if s then
                PROF_CAPTURE = Debug.enabled
            else
                print("could not start profiler")
            end

            love.timer.sleep(1)
            love.window.requestAttention()

            break
        end
    end
end

local has_jprof, jprof = pcall(require, "jprof")
if has_jprof then
    Jprof = jprof
    if PROF_CAPTURE then
        Jprof.connect()
    end
else
    local noop = function() end
    Jprof = {
        push = noop,
        pop = noop,
        write = noop,
        enabled = noop,
        connect = noop,
        netFlush = noop,
    }
end

-- debug stuff --
require("dbgdraw")
Debug.console = require("console")