local scene = Sceneman.scene()
local World = require("game.world")
local Input = require("input")
local gameProgression = require("game.progression")
local Menu = require("menu")

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
    self.paused = false
    self.hitPause = false

    self.menu = Menu()
    do
        local pausedLabel = self.menu:addLabel("Paused")
        pausedLabel.scale = 2.0
    end

    self.menu:addButton("resume", "Resume", {
        hint = "Resume the game."
    })
    self.menu:addButton("respawn", "Respawn", {
        hint = "Respawn at the last checkpoint."
    })
    self.menu:addButton("restart", "Restart", {
        hint = "Restart from the beginning of the level."
    })

    self.imgMouseCursor = Lg.newImage("/res/graphics/mouse_cursor.png")

    scene._debugSetup()
end

function scene.unload()
    scene._debugRelease()

    self.world:release()
    self.imgMouseCursor:release()
    self = nil
end

---@diagnostic disable-next-line
function scene.rawUpdate(dt)
    self.world:rawUpdate(dt)
    if self.paused then
        self.menu:rawUpdate(dt)
    end

    if Input.players[1]:pressed("pause") then
        self.hitPause = true
    end
end

function scene.update()
    if not self.paused then
        self.world:update()

        if self.transitionCoro then
            if not coroutine.sresume(self.transitionCoro) then
                self.transitionCoro = nil
            end
        end
    else
        local signal = self.menu:update()
        if signal then
            if signal == "resume" then
                scene._unpause()     
            elseif signal == "respawn" then
                self.world:reset()
                scene._unpause()
            elseif signal == "restart" then
                self.world:clearSaveData()
                self.world:reset()
                scene._unpause()
            end
        end
    end

    if self.hitPause and not self.transitionCoro then
        self.hitPause = false
        if self.paused then
            scene._unpause()
        else
            scene._pause()
        end
    end
end

function scene._pause()
    self.paused = true
    self.world.sndmgr:pause()
    self.menu:resetCursor()
end

function scene._unpause()
    self.paused = false
    self.world.sndmgr:resume()
end

function scene.draw()
    self.world:draw()

    Lg.push("all")
    Lg.setBlendMode("multiply", "premultiplied")
    local mul = 1.0 - self.darken
    Lg.setColor(mul, mul, mul, 1)
    Lg.rectangle("fill", 0, 0, App.scrW, App.scrH)

    if self.paused then
        Lg.setColor(0.3, 0.3, 0.4, 1.0)
        Lg.rectangle("fill", 0, 0, App.scrW, App.scrH)
    end

    Lg.pop()

    if self.paused then
        self.menu:draw(math.round(App.scrH/2))
    elseif Input.players[1]:getActiveDevice() == "kbm" then
        -- draw mouse cursor
        local mouseX = math.round(App.mouseX)
        local mouseY = math.round(App.mouseY)
        Lg.setColor(1, 1, 1)
        Lg.draw(self.imgMouseCursor, mouseX - 4, mouseY - 4)
    end
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

function scene.transitionToGameEnd()
    if self.transitionCoro then
        return
    end

    self.transitionCoro = coroutine.create(function()
        local yield = coroutine.yield

        for i=1, 240 do
            self.darken = (i-1) / 240
            yield()
        end
        self.darken = 1.0

        Sceneman.switchScene("game_end")
    end)
end

function scene._debugSetup()
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
        func = function(term_env, itemName, ...)
            local plr = self.world.player
            if not plr then return end

            local spawnX, spawnY = plr:getCenterPos()
            local ent = self.world:newEntity(itemName, spawnX, spawnY, ...)
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

            self.mapName = mapName
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

function scene._debugRelease()
    Debug.console.setVariable("world", nil)
    Debug.console.removeCommand("godmode")
    Debug.console.removeCommand("noclip")
    Debug.console.removeCommand("spawn")
    Debug.console.removeCommand("give_ammo")
    Debug.console.removeCommand("load_map")
    Debug.console.removeCommand("rewind")
    Debug.console.removeCommand("reload")
    Debug.console.removeCommand("next_level")
end


return scene