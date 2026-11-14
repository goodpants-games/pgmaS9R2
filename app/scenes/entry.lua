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
                term_env.print("god mode enabled")
            elseif status == "off" then
                self.world.player.godMode = false
                term_env.print("god mode disabled")
            elseif not status then
                term_env.print(self.world.player.godMode and "on" or "off")
            else
                term_env.print("unknown status")
            end
        end
    })
end

function scene.unload()
    Debug.console.removeCommand("godmode")
    
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