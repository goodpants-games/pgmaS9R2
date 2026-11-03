local scene = Sceneman.scene()
local fontres = require("fontres")
local self

function scene.load()
    Lg.setBackgroundColor(1, 1, 1)
    self = {}
end

function scene.unload()
    self = nil
end

function scene.update()

end

function scene.draw()
    Lg.setFont(fontres.monogram)
    Lg.setColor(0, 0, 0)
    Lg.print("Hello, world!", 10, 10)
end


return scene