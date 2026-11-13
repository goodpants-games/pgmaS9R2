local Util = require("game.util")
local Resmgr = require("game.resmgr")
local DirAnim = require("game.util.dir_anim")

---@class game.entities.BasicEnemy: game.entities.Enemy
local BasicEnemy = batteries.class {
    extends = require("game.entities.base_enemy")
}

function BasicEnemy:new(x, y)
    self:super(Util.centeredRect(x, y, 13, 12))
    self:addTag("enemy")

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/enemy1.json"))
    self.render.sprite.alignment = "center"
    self.render.ox = 6
    self.render.oy = 8
end

return BasicEnemy