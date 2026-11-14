local Resmgr = require("game.resmgr")
local Util = require("game.util")

---@class game.entities.Tutorial: game.Entity
local Tutorial = batteries.class {
    extends = require("game.entity")
}

---@param x number
---@param y number
function Tutorial:new(x, y)
    self:super(x, y, 0, 0)
    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/tutorials.json"))

    self.alwaysDrawOverTilemap = true
    self.zIndex = 1000
end

function Tutorial:loadProperties(id, props)
    local animName = Util.propCheck(props, "id", "string", id, self.typeName)
    if not animName then return end

    self.render.sprite:play(animName)
end

function Tutorial:update()
    self.render.sprite:update(App.tickLength)
end

return Tutorial