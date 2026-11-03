local scene = Sceneman.scene()
local fontres = require("fontres")
local Tiled = require("tiled")
local Input = require("input")
local self

function scene.load()
    self = {}
    Lg.setBackgroundColor(0.5, 0.5, 0.5)

    self.map = Tiled.loadMap("/res/maps/test.lua")
    self.camX = 0
    self.camY = 0
end

function scene.unload()
    self = nil
end

function scene.update()
    local device = Input.players[1]
    if device:down("left") then
        self.camX = self.camX - 2
    end
    if device:down("right") then
        self.camX = self.camX + 2
    end
    if device:down("up") then
        self.camY = self.camY - 2
    end
    if device:down("down") then
        self.camY = self.camY + 2
    end
end

function scene.draw()
    Lg.push("all")
    Lg.translate(-math.round(self.camX), -math.round(self.camY))

    self.map:draw(0, 0)

    Lg.pop()
end


return scene