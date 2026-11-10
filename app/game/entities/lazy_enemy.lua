local Util = require("game.util")
local Resmgr = require("game.resmgr")

---@class game.entities.LazyEnemy: game.entities.Enemy
local LazyEnemy = batteries.class {
    extends = require("game.entities.base_enemy")
}

function LazyEnemy:new(x, y)
    self:super(Util.centeredRect(x, y, 13, 12))
    self:addTag("enemy")

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/enemy2.json"))
    self.render.sprite.alignment = "topleft"
    self.render.oy = -24
    self.render.ox = -2

    self.aiBehavior.chasePlayer = false
    self.aiBehavior.investigateKills = false
end

return LazyEnemy