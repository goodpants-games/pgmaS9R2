local Util = require("game.util")
local Resmgr = require("game.resmgr")

---@class game.entities.BasicEnemy: game.entities.Enemy
local BasicEnemy = batteries.class {
    extends = require("game.entities.base_enemy")
}

function BasicEnemy:new(x, y)
    self:super(Util.centeredRect(x, y, 13, 12))
    self:addTag("enemy")

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/enemy1.json"))
    self.render.sprite.alignment = "topleft"
    self.render.oy = -24
    self.render.ox = -2
end

return BasicEnemy