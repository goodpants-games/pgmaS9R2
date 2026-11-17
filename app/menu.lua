local FontRes = require("fontres")
local Input = require("input")

---@class Menu: batteries.Class
---@overload fun():Menu
local Menu = batteries.class()

---@alias Menu.ItemKind
---| "button"
---| "label"

---@class Menu.Item
---@field kind Menu.ItemKind
---@field text string
---@field signal string?
---@field hint string?
---@field colR number
---@field colG number
---@field colB number
---@field scale number

function Menu:new()
    ---@type Menu.Item[]
    self.items = {}
    self.selectedItem = 0
    self.font = FontRes.monogram

    self._pressed = {
        down = false,
        up = false,
        uiConfirm = false,
    }

    self._selectionTimer = 0
    self._selectedColor = { 1.0, 1.0, 1.0, 1.0 }
end

---@param kind Menu.ItemKind
---@return Menu.Item
function Menu:_initItem(kind, text)
    return {
        kind = kind,
        text = text,
        signal = nil,
        colR = 1.0,
        colG = 1.0,
        colB = 1.0,
        scale = 1.0
    }
end

---@param text string
---@param extraData table?
function Menu:addLabel(text, extraData)
    local item = self:_initItem("label", text)
    if extraData then
        table.shallow_overlay(item, extraData)
    end
    table.insert(self.items, item)
    return item
end

---@param signal string
---@param text string?
---@param extraData table?
function Menu:addButton(signal, text, extraData)
    local item = self:_initItem("button", text or signal)
    item.signal = signal
    if extraData then
        table.shallow_overlay(item, extraData)
    end
    table.insert(self.items, item)
    return item
end

---@param dt number
function Menu:rawUpdate(dt)
    local device = Input.players[1]

    for k in pairs(self._pressed) do
        if device:pressed(k) then
            self._pressed[k] = true
        end
    end
end

---@param dir any
---@return integer
function Menu:_getDir(dir)
    if dir > 0.5 then
        return 1
    elseif dir < -0.5 then
        return -1
    else
        return 0
    end
end

---@param dir integer
function Menu:_moveCursor(dir)
    local itemCount = #self.items
    for _=1, itemCount do
        self.selectedItem = math.wrap(self.selectedItem + dir, 1, itemCount+1)
        if self.items[self.selectedItem].kind == "button" then
            break
        end
    end
end

function Menu:resetCursor()
    self.selectedItem = 0
    self._selectionTimer = 0
    for i, item in ipairs(self.items) do
        if item.kind == "button" then
            self.selectedItem = i
            break
        end
    end
end

---@return string? signal
function Menu:update()
    local returnValue

    if self.selectedItem == 0 then
        self:resetCursor()
    else
        if self._pressed.down then
            self:_moveCursor(1)
            self._selectionTimer = 0
        elseif self._pressed.up then
            self:_moveCursor(-1)
            self._selectionTimer = 0
        end
    end

    -- update color of selected item
    do
        -- local lerpT = math.cos((self._selectionTimer / 10) * math.tau)
        local lerpT = 1.0
        local col = self._selectedColor
        col[1], col[2], col[3] = batteries.colour.unpack_rgb(0x78caff)
        col[4] = lerpT
    end

    if self._pressed.uiConfirm then
        local item = self.items[self.selectedItem]
        returnValue = item.signal
    end

    self._selectionTimer = self._selectionTimer + 1
    for k in pairs(self._pressed) do
        self._pressed[k] = false
    end

    return returnValue
end

---@param text string
---@param ypos number
---@param scale number?
function Menu:_drawCenteredText(text, ypos, scale)
    scale = scale or 1.0
    Lg.printf(text, 8, ypos, (App.scrW - 16) / scale, "center", 0, scale, scale)
end

---@param centerY number
function Menu:draw(centerY)
    local centerX = App.scrW / 2.0
    local lineHeight = self.font:getHeight() * self.font:getLineHeight()
    local totalHeight = 0.0
    for _, item in ipairs(self.items) do
        totalHeight = totalHeight + lineHeight * item.scale
    end

    local drawY = math.round(centerY - totalHeight / 2.0)
    Lg.setFont(FontRes.monogram)
    for i, item in ipairs(self.items) do
        if self.selectedItem == i then
            Lg.setColor(unpack(self._selectedColor))
            Lg.rectangle("fill", centerX - 30.0, drawY + 2, 60.0, 11)
            Lg.setColor(0.0, 0.0, 0.0)
        else
            Lg.setColor(item.colR, item.colG, item.colB)
        end

        self:_drawCenteredText(item.text, drawY, item.scale)
        drawY = drawY + lineHeight * item.scale
    end

    local hint = self.items[self.selectedItem].hint
    if hint then
        Lg.setColor(0.5, 0.5, 0.5)
        self:_drawCenteredText(hint, App.scrH - 32)
    end
end

return Menu