local Util = require("game.util")
local Resmgr = require("game.resmgr")
local Const = require("game.consts")
local TILE_SIZE = require("game.consts").TILE_SIZE

---@class game.entities.KeycardReader: game.Entity
local KeycardReader = batteries.class {
    extends = require("game.entity")
}

function KeycardReader:new(x, y)
    self:super(x - 7, y, 15, 16)
    self:addTag("interactable")

    self.collision = true
    self.monitorOnly = true
    self.colGroup = Const.COLGROUP_INTERACT_AREA
    self.colMask = 0
    self.auth = nil ---@type integer?

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/keycard_reader.json"))
    self.render.sprite.alignment = "topleft"
    self.render.ox = -1
    self.render.oy = -7

    ---@type game.entities.Door[]
    self.targets = {}

    self.hasFocus = false

    self.msg:subscribe("interactFocusChanged", self._interactFocusChanged)
    self.msg:subscribe("interact", self._interact)
end

function KeycardReader:loadProperties(id, props, entLookup)
    local dir = Util.propCheck(props, "direction", "string", id, "keycard_reader")
    if not dir then return end

    if props.target then
        local target = Util.propCheck(props, "target", "object", id, "keycard_reader")
        if target == nil then return end

        local obj = entLookup(target)
        if obj then
            self.targets[1] = obj --[[@as any]]
        else
            warn(("{object id %i 'keycard_reader'}: ent lookup failed"):format(id))
        end
    end

    if props.targets then
        local targets = Util.propCheck(props, "targets", "list[object]", id, "keycard_reader")
        if targets == nil then return end

        for _, target in ipairs(targets) do
            table.insert(self.targets, softassert(entLookup(target)))
        end
    end

    print(("read %i targets"):format(#self.targets))

    if props.auth then
        local auth = Util.propCheck(props, "auth", "integer", id, "keycard_reader")
        if auth == nil then return end

        if auth ~= -1 then
            self.auth = auth
        end
    end

    local frameOfs
    if dir == "down" then
        frameOfs = 0
    elseif dir == "right" then
        frameOfs = 1
    elseif dir == "left" then
        frameOfs = 2
    else
        warn(("{object %i '%s'}': 'direction' property must be 'down', 'left', or 'right'"):format(id, "keycard_reader"))
    end

    local color = (self.auth or -1) + 1
    self.render.sprite.cel = color * 3 + frameOfs + 1
end

---@param status boolean
function KeycardReader:_interactFocusChanged(status)
    if status then
        print("computer Touche")
    else
        print("computer touch ende")
    end

    self.hasFocus = status
end

---@param plr game.entities.Player
function KeycardReader:_interact(plr)
    if self.auth then
        local card = plr.equippedItem --[[@as any]]
        if card and not card:hasTag("keycard") then
            card = nil
        end

        if not card then
            self:_popupText("AUTH REQUIRED")
            return
        end
        if card.auth ~= self.auth then
            self:_popupText("AUTH FAILED")
            return
        end
    end

    for _, target in ipairs(self.targets) do
        target:activate()
    end
end

---@param txt string
function KeycardReader:_popupText(txt)
    local x = self:getCenterX()
    local y = self:getCenterY() - 32
    local ent = Util.newEntity("text_popup", x, y, txt)
    if not ent then return end

    self.world:addEntity(ent)
end

return KeycardReader