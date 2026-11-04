local scene = Sceneman.scene()
local World = require("game.world")
local self

function scene.load()
    self = {}
    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    self.world = World()
    Mark_perf_heavy_frame()
end

function scene.unload()
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