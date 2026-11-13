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
    self.render.sprite.alignment = "center"
    self.render.ox = 6
    self.render.oy = 8

    self.aiBehavior.chasePlayer = false
    self.aiBehavior.investigateKills = false
end

return LazyEnemy