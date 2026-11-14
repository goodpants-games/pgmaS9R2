local scene = Sceneman.scene()
local World = require("game.world")
local self

function scene.load()
    self = {}
    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    self.world = World()
    Mark_perf_heavy_frame()

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
            elseif status == "off" then
                self.world.player.collision = true
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
end

function scene.unload()
    Debug.console.removeCommand("godmode")
    Debug.console.removeCommand("noclip")
    Debug.console.removeCommand("spawn")
    Debug.console.removeCommand("give_ammo")
    Debug.console.removeCommand("load_map")
    Debug.console.removeCommand("rewind")
    Debug.console.removeCommand("reload")
    
    self.world:release()
    self = nil
end

---@diagnostic disable-next-line
function scene.rawUpdate(dt)
    self.world:rawUpdate(dt)
end

function scene.update()
    self.world:update()
end

function scene.draw()
    self.world:draw()
end

return scene