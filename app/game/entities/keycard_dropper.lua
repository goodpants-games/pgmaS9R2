local Util = require("game.util")

---@class game.entities.KeycardDropper: game.entities.Entity
local KeycardDropper = batteries.class {
    extends = require("game.entities.base")
}

function KeycardDropper:new(x, y)
    self:super(0, 0, 0, 0)

    self.holders = {}
    self.auth = 0
end

function KeycardDropper:loadProperties(id, props, entLookup)
    local holders = Util.propCheck(props, "holders", "list[object]", id, "keycard_dropper")
    if not holders then return end

    local auth = Util.propCheck(props, "auth", "int", id, "keycard_dropper")
    if not auth then return end

    self.auth = auth

    local function onHolderDied(holder)
        self:_holderDied(holder)
    end

    for _, objId in ipairs(holders) do
        local ent = entLookup(objId)
        if ent then
            table.insert(self.holders, ent)
            ent.msg:subscribe("died", onHolderDied)
        end
    end
end

---@param holder game.entities.Entity
function KeycardDropper:_holderDied(holder)
    print("holder die :(")
    table.remove_value(self.holders, holder)

    if #self.holders == 0 then
        print("eek! no more holders!")

        local keycard = Util.newEntity("keycard", holder:getCenterPos()) --[[@as game.entities.Keycard]]
        keycard.auth = self.auth
        keycard.xVel = -holder.xVel * 0.4
        keycard.yVel = -holder.yVel * 0.4
        keycard.zVel = 3
        keycard.zOffset = 4

        self.world:addEntity(keycard)
    end
end

return KeycardDropper