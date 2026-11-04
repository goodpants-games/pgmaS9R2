local RectRenderer = require("game.util").RectRenderer
local centeredRect = require("game.util").centeredRect

---@class game.entities.Projectile: game.entities.Entity
local Projectile = batteries.class {
    extends = require("game.entities.base")
}

function Projectile:new(x, y)
    self:super(centeredRect(x, y, 1, 1))
    self.collision = true

    self.restitution = 1.0
    self.bouncesLeft = 4

    self.msg:subscribe("touched", self._touched)
end

function Projectile:_touched(oent, nx, ny)
    self.bouncesLeft = self.bouncesLeft - 1
    if self.bouncesLeft <= 0 then
        self:remove()
    end
end

function Projectile:render()
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    Lg.setColor(0, 0, 0)
    Lg.circle("fill", cx, cy, 2)
end

return Projectile