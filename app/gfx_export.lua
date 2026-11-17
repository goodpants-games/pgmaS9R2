local Json = require("json")
local World = require("game.world")

local function pathSplit(path)
    local res = {}
    local i = 1
    while true do
        local idx = string.find(path, "/", i, true)
        if idx == nil then
            table.insert(res, string.sub(path, i))
            break
        end
        table.insert(res, string.sub(path, i, idx-1))
        i = idx + 1
    end
    return res
end

local function pathNormalize(path)
    local stack = {}
    local depth = 0
    for _, v in pairs(path) do
        if v == ".." then
            if depth <= 0 then
                stack[#stack+1] = v
            else
                stack[#stack] = nil
            end
            depth = depth - 1
        elseif v ~= "." then
            stack[#stack+1] = v
            depth = depth + 1
        end
    end
    if #stack == 0 then
        return "."
    else
        return table.concat(stack, "/")
    end
end

local function readSpriteData(jsonPath)
    local jsonData = assert( love.filesystem.read("string", jsonPath) )
    local data = Json.decode(jsonData)
        
    local path = pathSplit(jsonPath)
    local imagePath = pathSplit(data.meta.image)
    table.remove(path)
    for _, v in ipairs(imagePath) do
        table.insert(path, v)
    end

    local pngPath = pathNormalize(path)
    local atlasImg = love.image.newImageData(pngPath)

    return data, atlasImg
end

---@param image love.ImageData
---@param filePath string
local function saveImageData(image, filePath)
    if image:getWidth() > 960 or image:getHeight() > 720 then
        error(("'%s': image size exceeds max scratch bitmap size"):format(filePath))
    end

    local pngData = image:encode("png")
    local outf = assert( io.open(filePath, "wb") )
    outf:write(pngData:getString())
    outf:close()
    pngData:release()
end

local function spriteExport(dir)
    dir = string.gsub(dir, "/", "\\")
    os.execute("rmdir /S /Q " .. dir)
    os.execute("mkdir " .. dir)

    local spritesDir = "/res/sprites"
    for _, fileName in ipairs(love.filesystem.getDirectoryItems(spritesDir)) do
        local filePath = spritesDir .. "/" .. fileName
        local name, ext = string.match(fileName, "^(.*)(%..+)$")
        if ext ~= ".json" then
            goto continue
        end
        if name == "tutorials" then
            goto continue
        end

        local data, atlas = readSpriteData(filePath)
        for i, celData in ipairs(data.frames) do
            local frame = celData.frame
            local celImg = love.image.newImageData(frame.w, frame.h)
            celImg:paste(atlas, 0, 0, frame.x, frame.y, frame.w, frame.h)

            local pngData = celImg:encode("png")
            local outFileName = ("%s/spr %s %i.png"):format(dir, name, i)
            local outf = assert( io.open(outFileName, "wb") )
            outf:write(pngData:getString())
            outf:close()
            pngData:release()
            celImg:release()
        end
        atlas:release()

        ::continue::
    end
end

local function mapExport(dir)
    dir = string.gsub(dir, "/", "\\")
    os.execute("rmdir /S /Q " .. dir)
    os.execute("mkdir " .. dir)

    ---@param mapName string
    ---@param layerIdx integer
    ---@param x integer
    ---@param y integer
    ---@return string
    local function getMapFileName(mapName, layerIdx, x, y)
        return ("%s/map %s %i %i %i.png"):format(dir, mapName, layerIdx, x, y)
    end
    
    local world = World()
    local mapsDir = "/res/maps"
    local canvas = Lg.newCanvas(960, 720, { dpiscale = 1.0 })

    for _, fileName in ipairs(love.filesystem.getDirectoryItems(mapsDir)) do
        local filePath = mapsDir .. "/" .. fileName
        local name, ext = string.match(fileName, "^(.*)(%..+)$")
        if ext ~= ".lua" then
            goto continue
        end

        world:reset(filePath)
        world:_clearEntities()

        local mapPixelWidth = world.mapWidth * 16
        local mapPixelHeight = world.mapHeight * 1

        for y=1, math.ceil(mapPixelHeight / 720) do
            for x=1, math.ceil(mapPixelWidth / 960) do
                Lg.push()
                Lg.translate(-(x-1) * 960, -(y-1) * 720)
                
                -- save first layer
                do
                    Lg.setCanvas(canvas)
                    Lg.clear(0, 0, 0, 0)

                    for _, layer in ipairs(world.map.layers) do
                        -- draw objects immediately before top layer
                        if layer.name == "__top" then
                            break
                        end
                        layer:draw()
                    end

                    Lg.setCanvas()

                    local imgData = canvas:newImageData()
                    local outFileName = getMapFileName(name, 1, x-1, y-1)
                    saveImageData(imgData, outFileName)
                    imgData:release()
                end

                -- save second layer
                do
                    Lg.setCanvas(canvas)
                    Lg.clear(0, 0, 0, 0)

                    local top = false
                    for _, layer in ipairs(world.map.layers) do
                        -- draw objects immediately before top layer
                        if layer.name == "__top" then
                            top = true
                        end

                        if top then
                            layer:draw()
                        end
                    end

                    Lg.setCanvas()

                    local imgData = canvas:newImageData()
                    local outFileName = getMapFileName(name, 2, x-1, y-1)
                    saveImageData(imgData, outFileName)
                    imgData:release()
                end

                Lg.pop()
            end
        end

        ::continue::
    end

    canvas:release()
end

return {
    gfx = spriteExport,
    map = mapExport
}