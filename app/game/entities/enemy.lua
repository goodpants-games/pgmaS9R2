local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect

---@class game.entities.Enemy: game.entities.Entity
local Enemy = batteries.class {
    extends = require("game.entities.base")
}

function Enemy:new(x, y)
    self:super(centeredRect(x, y, 14, 14))
    self.collision = true
    self.render = RectRenderer(1.0, 0.0, 0.0)
end

return Enemy