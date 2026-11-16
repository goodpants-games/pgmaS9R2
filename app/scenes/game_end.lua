local scene = Sceneman.scene()
local img
local music

function scene.load()
    Lg.setBackgroundColor(0, 0, 0)

    img = Lg.newImage("/res/win.png")
    music = love.audio.newSource("/res/music/i_definitely_spent_20_dollars_on_this.ogg", "stream")
    music:play()
    music:setLooping(true)
end

function scene.unload()
    img:release()
    music:stop()
    music:release()
    img = nil
    music = nil
end

function scene.draw()
    Lg.draw(img, 0, 0)
end

return scene