local Sprite = require("sprite")
local Fontres = require("fontres")

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
    self.music = love.audio.newSource("/res/music/guess_of_descension.ogg", "stream")
    self.music:setVolume(0.5)
    self.music:play()
    self.gameLogo = Lg.newImage("/res/title.png")
    self.teamLogo = Lg.newImage("/res/graphics/firebeetle.png")
    self.pgmaLogo = Lg.newImage("/res/graphics/pgma_logo.png")
    self.presentsImg = Lg.newImage("/res/graphics/presents.png")
    self.curImage = nil
    self.imageOpacity = 0.0
    self.timer = 0
    self.showSkipText = true
    Mark_perf_heavy_frame()

    local function rand()
        return love.math.random() * 2.0 - 1.0
    end

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

        while self.music:tell() == 0.0 do
            print("wai....")
            wait()
        end
        self.timer = 0
        
        while self.music:tell() < 12.314 - 4/60 - 0.4 do
            if self.timer == 60 then
                self.curImage = self.pgmaLogo
                self.imageOpacity = 0.0
                for _=1, 60 do
                    self.imageOpacity = self.imageOpacity + 1/60
                    wait()
                end
                for _=1, 60 do wait() end
                for _=1, 60 do
                    self.imageOpacity = self.imageOpacity - 1/60
                    wait()
                end
                self.curImage = nil
            end

            if self.timer == 300 then
                self.curImage = self.teamLogo
                self.imageOpacity = 0.0
                for _=1, 60 do
                    self.imageOpacity = self.imageOpacity + 1/60
                    wait()
                end
                for _=1, 60 do wait() end
                for _=1, 60 do
                    self.imageOpacity = self.imageOpacity - 1/60
                    wait()
                end
                self.curImage = nil
            end

            if self.timer == 540 then
                self.curImage = self.presentsImg
                self.imageOpacity = 0.0
                for _=1, 60 do
                    self.imageOpacity = self.imageOpacity + 1/60
                    wait()
                end
                for _=1, 60 do wait() end
                for _=1, 60 do
                    self.imageOpacity = self.imageOpacity - 1/60
                    wait()
                end
                self.curImage = nil
            end

            wait() 
        end

        local rock = addObject("rock")
        rock.x = -40
        rock.y = -40
        local rockVx = ufo.x - rock.x
        local rockVy = ufo.y - rock.y
        rockVx, rockVy = math.normalize(rockVx, rockVy)
        rockVx = rockVx * 8
        rockVy = rockVy * 8
        while rock.y < ufo.y - 30 do
            wait()
            rock.x = rock.x + rockVx
            rock.y = rock.y + rockVy
        end

        rockVx = -3
        rockVy = 0.5
        ufo.spr:play("ufo_struck")
        ufo.update = nil
        ufo.rotation = math.rad(20)
        while self.music:tell() < 14.262 - 4/60 do
            wait()
            rock.x = rock.x + rockVx
            rock.y = rock.y + rockVy
            ufo.x = ufo.x + 1.2
            ufo.y = ufo.y + 4
        end

        removeObject(rock)
        Lg.setBackgroundColor(batteries.colour.unpack_rgb(0x58a5ff))
        ufo.spr:play("ufo_fall")
        ufo.x = App.scrW / 2
        ufo.y = App.scrH / 2
        ufo.rotation = 0

        while self.music:isPlaying() do
            ufo.x = App.scrW / 2 + rand() * 4 + 10
            ufo.y = App.scrH / 2 + rand() * 4 - 10
            ufo.rotation = rand() * math.rad(10)
            wait()
        end

        self.showSkipText = false
        
        self.drawCallback = function()
            Lg.setColor(0, 0, 0)
            Lg.rectangle("fill", 0, 0, App.scrW, App.scrH)

            local logo = self.gameLogo
            local logoDrawX = (App.scrW - logo:getWidth()) / 2
            local logoDrawY = (App.scrH - logo:getHeight()) / 2
            Lg.setColor(1, 1, 1)
            Lg.draw(logo, math.round(logoDrawX), math.round(logoDrawY))
        end

        for _=1, 240 do wait() end

        self.drawCallback = function()
            Lg.setColor(0, 0, 0)
            Lg.rectangle("fill", 0, 0, App.scrW, App.scrH)

            Lg.setFont(Fontres.monogram)
            Lg.setColor(1, 1, 1)
            Lg.printf("Escape Area 51!\n\nPress SPACE to start!", 0, App.scrH / 3 + 10, App.scrW, "center")
        end
    end)
end

function scene.unload()
    self.sprRes:release()
    self.music:stop()
    self.music:release()
    self.gameLogo:release()
    self.teamLogo:release()
    self.pgmaLogo:release()
    self.presentsImg:release()
    self = nil
end

function scene.keypressed(k)
    if k == "space" then
        Sceneman.switchScene("game")
        print("Skip..")
    end
end

function scene.update()
    if self.script then
        if not coroutine.sresume(self.script) then
            self.script = nil
        end
    end

    for _, obj in ipairs(self.objects) do
        if obj.update then
            obj:update()
        end
    end

    self.timer = self.timer + 1
end

function scene.draw()
    for _, obj in ipairs(self.objects) do
        Lg.setColor(1, 1, 1)
        obj.spr:draw(obj.x, obj.y, obj.rotation)
    end

    if self.curImage and self.imageOpacity > 0 then
        local a = self.imageOpacity
        Lg.setColor(a, a, a, a)
        Lg.draw(self.curImage, 0, 0)
    end

    if self.drawCallback then
        self.drawCallback()
    end

    if self.showSkipText then
        Lg.setColor(1, 1, 1)
        Lg.setFont(Fontres.quinque)
        Lg.print("SPACE to skip", 2, 2)
    end
end

return scene