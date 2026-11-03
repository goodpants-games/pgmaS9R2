-- Debug drawing: queued in love.update and flushed in love.draw.

---@class DebugDraw
---@field private _draw_list function[]
---@overload fun():DebugDraw
local DebugDraw = batteries.class({ name = "DebugDraw" })
local fontres = require("fontres")

function DebugDraw:new()
    self.enabled = true
    self._draw_list = {}
end

function DebugDraw:color(r, g, b, a)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.setColor(r, g, b, a)
    end)
end

function DebugDraw:push()
    if not self.enabled then return end
    table.insert(self._draw_list, Lg.push)
end

function DebugDraw:pop()
    if not self.enabled then return end
    table.insert(self._draw_list, Lg.pop)
end

function DebugDraw:translate(x, y)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.translate(math.round(x), math.round(y))
    end)
end

function DebugDraw:scale(x, y)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.scale(x, y)
    end)
end

function DebugDraw:point(x, y)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.points(math.round(x) + 0.5, math.round(y) + 0.5)
    end)
end

function DebugDraw:rectLines(x, y, w, h)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.rectangle("line", math.round(x) + 0.5, math.round(y) + 0.5, math.round(w), math.round(h))
    end)
end

function DebugDraw:line(x0, y0, x1, y1)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.line(math.round(x0) + 0.5, math.round(y0) + 0.5, math.round(x1) + 0.5, math.round(y1) + 0.5)
    end)
end

function DebugDraw:circleLines(x, y, r)
    if not self.enabled then return end
    table.insert(self._draw_list, function()
        Lg.circle("line", math.round(x), math.round(y), r)
    end)
end

function DebugDraw:text(text, x, y)
    if not self.enabled then return end
    text = tostring(text)
    table.insert(self._draw_list, function()
        Lg.print(text, math.round(x), math.round(y))
    end)
end

function DebugDraw:flush()
    Lg.push("all")
    Lg.origin()
    Lg.setColor(1, 1, 1)
    Lg.setLineWidth(1)
    Lg.setLineStyle("rough")
    Lg.setFont(fontres.monogram)
    for _, v in ipairs(self._draw_list) do
        v()
    end
    table.clear(self._draw_list)
    Lg.pop()
end

Debug.draw = DebugDraw()

return DebugDraw