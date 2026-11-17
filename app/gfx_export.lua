local Json = require("json")

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

return function(dir)
    dir = string.gsub(dir, "/", "\\")
    os.execute("rmdir /S /Q " .. dir)
    os.execute("mkdir " .. dir)

    local spritesDir = "/res/sprites"
    for _, fileName in ipairs(love.filesystem.getDirectoryItems("/res/sprites")) do
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