local FontRes = require "fontres"

---@class game.entities.TextPopup: game.entities.Entity
local TextPopup = batteries.class {
    extends = require("game.entities.base")
}

---@param x number
---@param y number
---@param text string
function TextPopup:new(x, y, text)
    self:super(x, y, 0, 0)
    self.text = text
    self.life = 30

    self.zIndex = 1000
    self.alwaysDrawOverTilemap = true
end

function TextPopup:update()
    self.y = self.y - 0.5
    self.life = self.life - 1
    if self.life <= 0 then
        self:remove()
    end
end

function TextPopup:render()
    local font = FontRes.monogram
    local textOx = math.round(font:getWidth(self.text) / -2)
    
    Lg.setFont(font)
    Lg.setColor(0, 0, 0)
    Lg.print(self.text, self.x + textOx + 1, self.y + 1)
    Lg.setColor(1, 1, 1)
    Lg.print(self.text, self.x + textOx, self.y)
end

return TextPopup