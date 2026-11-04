---@class game.entities.GunSight: game.entities.Entity
local GunSight = batteries.class {
    extends = require("game.entities.base")
}

function GunSight:new(x, y)
    self:super(0, 0, 0, 0)

    self.maxLength = 400
    self.maxBounces = 4

    ---@type number[]
    self.lines = {}
end

function GunSight:updateSight(x, y, dx, dy)
    local dlen = math.length(dx, dy)
    dx, dy = dx / dlen, dy / dlen

    self.lines = {}

    local len = self.maxLength
    local bounces = 0
    while len > 0 do
        local rd, rnx, rny = self.world:raycast(x, y, dx * len, dy * len)
        if rd == 0 then
            warn("rd was zero")
            break
        end

        if not rd then
            rd = len
            rnx = 0
            rny = 0
        end

        local endX = x + dx * rd + rnx * 0.001
        local endY = y + dy * rd + rny * 0.001

        table.insert(self.lines, x)
        table.insert(self.lines, y)
        table.insert(self.lines, endX)
        table.insert(self.lines, endY)

        bounces = bounces + 1
        if bounces >= self.maxBounces then
            break
        end

        x, y = endX, endY
        len = len - rd 

        -- reflect:
        -- v' = v - 2r(v ⋅ r)
        dx = dx - 2 * (dx * rnx) * rnx
        dy = dy - 2 * (dy * rny) * rny
    end
end

function GunSight:render()
    Lg.setColor(1, 0, 0)
    Lg.setLineWidth(1.0)
    Lg.line(self.lines)
end

return GunSight