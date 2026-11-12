local Util = require("game.util")
local Resmgr = require("game.resmgr")
local Const = require("game.consts")
local TILE_SIZE = require("game.consts").TILE_SIZE

---@class game.entities.Computer: game.entities.Entity
local Computer = batteries.class {
    extends = require("game.entities.base")
}

function Computer:new(x, y)
    self:super(x - 7, y, 15, 16)
    self:addTag("interactable")

    self.collision = true
    self.monitorOnly = true
    self.colGroup = Const.COLGROUP_INTERACT_AREA
    self.colMask = 0
    self.auth = nil ---@type integer?

    self.tileX = math.floor((x - 8) / TILE_SIZE)
    self.tileY = math.floor((y - 8) / TILE_SIZE)

    self.render = Util.SpriteRenderer(Resmgr.newSprite("/res/sprites/computer.json"))
    self.render.sprite.alignment = "topleft"

    self.render.oy = -24

    ---@type game.entities.Door[]
    self.targets = {}

    self.hasFocus = false

    self.msg:subscribe("addedToWorld", self._added)
    self.msg:subscribe("interactFocusChanged", self._interactFocusChanged)
    self.msg:subscribe("interact", self._interact)
end

function Computer:loadProperties(id, props, entLookup)
    if props.target then
        local target = Util.propCheck(props, "target", "object", id, "computer")
        if target == nil then return end

        self.targets[1] = softassert( entLookup(target) ) --[[@as any]]
    end

    if props.targets then
        local targets = Util.propCheck(props, "targets", "list[object]", id, "computer")
        if targets == nil then return end

        for _, target in ipairs(targets) do
            table.insert(self.targets, softassert(entLookup(target)))
        end
    end

    print(("read %i targets"):format(#self.targets))

    if props.auth then
        local auth = Util.propCheck(props, "auth", "integer", id, "computer")
        if auth == nil then return end

        self.auth = auth
    end
end

function Computer:_added()
    self.world:setCol(self.tileX, self.tileY, 1)
end

---@param status boolean
function Computer:_interactFocusChanged(status)
    if status then
        print("computer Touche")
    else
        print("computer touch ende")
    end

    self.hasFocus = status
end

---@param plr game.entities.Player
function Computer:_interact(plr)
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
function Computer:_popupText(txt)
    local x = self:getCenterX()
    local y = self:getCenterY() - 32
    local ent = Util.newEntity("text_popup", x, y, txt)
    if not ent then return end

    self.world:addEntity(ent)
end

return Computer