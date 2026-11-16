local Sprite = require("sprite")

local scene = Sceneman.scene()
local self

local function addObject(costumeName)
    local sprite = Sprite.new(self.sprRes)
    sprite:play(costumeName)

    local obj = {
        spr = sprite,
        x = 0.0,
        y = 0.0,
        rotation = 0.0
    }
    table.insert(self.objects, obj)
    return obj
end

local function removeObject(object)
    return table.remove_value(self.objects, object)
end

function scene.load()
    self = {}
    self.sprRes = Sprite.loadResource("/res/intro_stuff.json")
    self.objects = {}

    self.script = coroutine.create(function()
        local wait = coroutine.yield
        Lg.setBackgroundColor(0, 0, 0)

        local ufo = addObject("ufo")
        ufo.x = App.scrW / 2
        ufo.y = App.scrH / 2
        ufo._time = 0
        function ufo:update()
            ufo._time = ufo._time + 1
            ufo.y = ufo.y + math.sin(ufo._time * 0.1) * 0.2
            ufo.rotation = math.sin(ufo._time * 0.2) * math.rad(3)
        end
        
        for _=1, 240 do
            
        end


        
    end)
end

function scene.unload()
    self.sprRes:release()
    self = nil
end

function scene.update()
    if not coroutine.sresume(self.script) then
        Sceneman.switchScene("game")
    end

    for _, obj in ipairs(self.objects) do
        if obj.update then
            obj:update()
        end
    end
end

function scene.draw()
    for _, obj in ipairs(self.objects) do
        obj.spr:draw(obj.x, obj.y, obj.rotation)
    end
end

return scene