local OutsideScript = batteries.class {
    extends = require("game.entity")
}

function OutsideScript:new()
    self:super(0, 0, 0, 0)
    self.msg:subscribe("addedToWorld", self._added)
end

function OutsideScript:_added()
    self.world.music:stop()
end

function OutsideScript:update()
    local world = self.world
    local plr = world.player

    if plr.y > (world.mapHeight+3) * 16 then
        plr.y = 999999 -- lol
        Sceneman.currentScene.transitionToGameEnd()
        self:remove()
    end
end

return OutsideScript