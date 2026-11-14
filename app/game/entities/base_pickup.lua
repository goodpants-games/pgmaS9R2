local Const = require("game.consts")

---@class game.entities.BasePickup: game.Entity
local BasePickup = batteries.class {
    extends = require("game.entity")
}

function BasePickup:new(x, y, w, h)
    self:super(x, y, w, h)
    self:addTag("interactable")

    self.zVel = 0.0
    self.zGrav = -0.3
    self.zIndex = -20

    self.collision = true
    self.restitution = 0.5
    self.colGroup = Const.COLGROUP_INTERACT_AREA
    self.colMask = bit.bor(Const.COLGROUP_DEFAULT, Const.COLGROUP_PLAYER)

    self.msg:subscribe("interact", self._interact)

    self.persistentData = true
end

function BasePickup:launch(dirX, dirY)
    dirX, dirY = math.normalize(dirX, dirY)

    self.xVel = dirX * 1.5
    self.yVel = dirY * 1.5
    self.zVel = 3
    self.zOffset = 4
end

function BasePickup:update()
    self.zVel = self.zVel + self.zGrav
    self.zOffset = self.zOffset + self.zVel
    if self.zOffset < 0 then
        self.xVel = self.xVel * 0.7
        self.yVel = self.yVel * 0.7
        self.zOffset = 0
        self.zVel = self.zVel * -0.5
    end

    if self.zOffset < 2 then
        self.zIndex = -20
    else
        self.zIndex = 0
    end
end

---@param plr game.entities.Player
function BasePickup:_interact(plr)
    if not softassert(plr:hasTag("player")) then
        return
    end
    
    print("player picked up keycard")
    plr:pickUpItem(self)
end

function BasePickup:savePersistentData(data)
    BasePickup.__super.savePersistentData(self, data)
    data.x, data.y = self:getCenterPos()
end

function BasePickup:loadPersistentData(data)
    BasePickup.__super.loadPersistentData(self, data)
    self.x = data.x - self.width / 2
    self.y = data.y - self.height / 2
end

return BasePickup