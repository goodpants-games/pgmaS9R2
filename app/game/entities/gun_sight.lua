local const = require("game.consts")
local Util = require("game.util")

---@class game.entities.GunSight: game.Entity
local GunSight = batteries.class {
    extends = require("game.entity")
}

function GunSight:new(x, y)
    self:super(0, 0, 0, 0)

    self.zIndex = -100
    self.zOffset = 3

    self.maxLength = 1000
    self.maxBounces = 4
    self.r = 1.0
    self.g = 1.0
    self.b = 1.0
    self.a = 1.0

    ---@type number[]
    self.lines = {}
end

---@param r number
---@param g number
---@param b number
function GunSight:setColor(r, g, b)
    self.r, self.g, self.b = r, g, b
end

function GunSight:clearSight()
    self.lines = {}
end

function GunSight:updateSight(x, y, dx, dy)
    local dlen = math.length(dx, dy)
    dx, dy = dx / dlen, dy / dlen

    self.lines = {}

    local len = self.maxLength
    local bounces = 0
    while len > 0 do
        local rd, rnx, rny = self.world:raycast(
            x, y, dx * len, dy * len,
            const.COLGROUP_DEFAULT)
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

        table.insert(self.lines, math.round(x) + 0.5)
        table.insert(self.lines, math.round(y) + 0.5)
        table.insert(self.lines, math.round(endX) + 0.5)
        table.insert(self.lines, math.round(endY) + 0.5)

        bounces = bounces + 1
        if bounces >= self.maxBounces then
            break
        end

        x, y = endX, endY
        len = len - rd 

        -- reflect:
        -- v' = v - 2r(v ⋅ r)
        local dot = dx * rnx + dy * rny
        dx = dx - 2 * rnx * dot
        dy = dy - 2 * rny * dot
    end
end

function GunSight:render()
    if self.lines[1] then
        Lg.setColor(self.r, self.g, self.b, self.a)
        Lg.setLineWidth(1.0)
        Lg.setLineJoin("none")
        Lg.line(self.lines)
    end
end

function GunSight:recordDraw(cmdList)
    local rgbInt = batteries.colour.pack_rgb(self.r, self.g, self.b)
    local colorString = ("#%x"):format(rgbInt)

    table.insert(cmdList, "pen_color")
    table.insert(cmdList, colorString)
    table.insert(cmdList, "pen_transparency")
    table.insert(cmdList, (1.0 - self.a) * 100.0)

    local polyline = self.lines
    for i=1, #polyline, 2 do
        local x, y = Lg.transformPoint(polyline[i], polyline[i+1])
        x, y = Util.convertToScratchCoords(x, y)
        
        table.insert(cmdList, "goto")
        table.insert(cmdList, x)
        table.insert(cmdList, y)

        if i == 1 then
            table.insert(cmdList, "pen_down")
        end
    end

    table.insert(cmdList, "pen_up")
end

return GunSight