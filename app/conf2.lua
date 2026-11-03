-- Additional configuration to be ran after all LOVE modules have been
-- initialized.

require("compat.love")

Lg = love.graphics

require("batteries"):export()
Lg.setDefaultFilter("nearest")

Sceneman = require("sceneman")
Sceneman.scenePrefix = "scenes."
Sceneman.setCallbackMode("manual")

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

local sprite = require("sprite")
sprite.fallbackAlignment = "center"

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

require("dbgdraw")