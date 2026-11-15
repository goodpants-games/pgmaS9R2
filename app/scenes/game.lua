local scene = Sceneman.scene()
local World = require("game.world")
local gameProgression = require("game.progression")

local self

local function loadMap(mapName)
    self.mapName = mapName
    self.world:reset(("/res/maps/%s.lua"):format(mapName))
end

function scene.load(initLevel)
    self = {}
    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    self.world = World()
    loadMap(initLevel or gameProgression.levels[1])
    Mark_perf_heavy_frame()

    self.darken = 0.0

    Debug.console.setVariable("world", self.world)

    Debug.console.addCommand({
        name = "godmode",
        help = "[<on|off>]",
        func = function (term_env, status)
            if status == "on" then
                self.world.player.godMode = true
            elseif status == "off" then
                self.world.player.godMode = false
            elseif not status then
                term_env.print(self.world.player.godMode and "on" or "off")
            else
                term_env.print("arg error")
            end
        end
    })

    Debug.console.addCommand({
        name = "noclip",
        help = "[<on|off>]",
        func = function(term_env, status)
            if status == "on" then
                self.world.player.collision = false
                self.world.player.moveSpeed = self.world.player.moveSpeed * 3
            elseif status == "off" then
                self.world.player.collision = true
                self.world.player.moveSpeed = self.world.player.moveSpeed / 3
            elseif not status then
                term_env.print(self.world.player.collision and "off" or "on")
            else
                term_env.print("arg error")
            end
        end
    })

    Debug.console.addCommand({
        name = "spawn",
        help = "<object name>",
        func = function(term_env, itemName)
            local plr = self.world.player
            if not plr then return end

            local ent = self.world:newEntity(itemName, plr:getCenterPos())
            if ent then
                self.world:addEntity(ent)
            else
                term_env.print("could not create object")
            end
        end
    })

    Debug.console.addCommand({
        name = "give_ammo",
        help = "",
        func = function (term_env, ...)
            local plr = self.world.player
            if not plr then return end
            plr.ammo = plr.ammo + 1
        end
    })

    Debug.console.addCommand({
        name = "load_map",
        help = "<map name>",
        func = function (term_env, mapName)
            local path = ("/res/maps/%s.lua"):format(mapName)
            if not love.filesystem.getInfo(path) then
                term_env.print("map does not exist")
                return
            end

            self.world:reset(path)
        end
    })

    Debug.console.addCommand({
        name = "rewind",
        help = "",
        func = function(term_env)
            self.world:reset()
        end
    })

    Debug.console.addCommand({
        name = "reload",
        help = "",
        func = function(term_env)
            self.world:clearSaveData()
            self.world:reset()
        end
    })

    Debug.console.addCommand({
        name = "next_level",
        help = "",
        func = function()
            scene.transitionToNextLevel()
        end
    })
end

function scene.unload()
    Debug.console.setVariable("world", nil)
    Debug.console.removeCommand("godmode")
    Debug.console.removeCommand("noclip")
    Debug.console.removeCommand("spawn")
    Debug.console.removeCommand("give_ammo")
    Debug.console.removeCommand("load_map")
    Debug.console.removeCommand("rewind")
    Debug.console.removeCommand("reload")
    Debug.console.removeCommand("next_level")
    
    self.world:release()
    self = nil
end

---@diagnostic disable-next-line
function scene.rawUpdate(dt)
    self.world:rawUpdate(dt)
end

function scene.update()
    self.world:update()

    if self.transitionCoro then
        if not coroutine.sresume(self.transitionCoro) then
            self.transitionCoro = nil
        end
    end
end

function scene.draw()
    self.world:draw()

    Lg.push("all")
    Lg.setBlendMode("multiply", "premultiplied")
    local mul = 1.0 - self.darken
    Lg.setColor(mul, mul, mul, 10)
    Lg.rectangle("fill", 0, 0, App.scrW, App.scrH)

    Lg.pop()
end

function scene.transitionToNextLevel()
    if self.transitionCoro then
        return
    end

    self.transitionCoro = coroutine.create(function()
        local yield = coroutine.yield

        for i=1, 60 do
            self.darken = (i-1) / 60
            yield()
        end
        self.darken = 1.0

        local idx = table.index_of(gameProgression.levels, self.mapName)
        loadMap(gameProgression.levels[idx + 1])
        Mark_perf_heavy_frame()
        yield()

        for i=1, 60 do
            self.darken = 1.0 - (i / 60)
            yield()
        end
        self.darken = 0.0
    end)
end

return scene