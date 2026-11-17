---@class game.SoundManager: batteries.Class
---@overload fun():game.SoundManager
local SoundManager = batteries.class {
    name = "game.SoundManager"
}

local MAX_SIMULTANEOUS_SOURCES = 16

---@class game.Sound
---@field package _mgr game.SoundManager
---@field package _is_released boolean
---@field src love.Source
---@field positional boolean
---@field posX number?
---@field posY number?
---@field entity any?
---@overload fun(mgr:game.SoundManager, source:love.Source):game.Sound
local Sound = batteries.class {
    name = "game.Sound"
}

function Sound:new(mgr, source)
    self._mgr = mgr
    self._is_released = false

    self.src = source
    self.positional = false
end

---@param x number
---@param y number
function Sound:setPosition(x, y)
    self.entity = nil
    self.posX = x
    self.posY = y
    self.positional = true
    
    self:_update_pos()
end

function Sound:attachTo(ent)
    self.entity = ent
    self.positional = true

    self:_update_pos()
end

---@package
function Sound:_update_pos()
    if self.positional then
        if self.entity then
            local ent = self.entity
            self.src:setPosition(ent.x, 0.0, ent.y)
        else
            self.src:setPosition(self.posX, 0.0, self.posY)
        end

        self.src:setRelative(false)
    else
        self.src:setRelative(true)
    end
end

function Sound:release()
    self._is_released = true
end

function SoundManager:new()
    self.listenerX = 0
    self.listenerY = 0

    ---@private
    ---@type {[string]:love.Source}
    self._source_cache = {}

    ---@private
    ---@type game.Sound[]
    self._active = {}

    ---@private
    self._overlap_exclude = {}

    ---@private
    self._pausedSounds = nil ---@type game.Sound[]?
    ---@private
    self._isPaused = false
end

function SoundManager:release()
    if self._active then
        for _, snd in ipairs(self._active) do
            snd.src:release()
        end
        self._active = nil
    end

    if self._source_cache then
        for _, src in ipairs(self._source_cache) do
            src:release()
        end
        self._source_cache = nil
    end
end

function SoundManager:stopAll()
    for _, snd in ipairs(self._active) do
        snd.src:stop()
    end
end

function SoundManager:pause()
    if self._isPaused then return end
    self._isPaused = true

    local paused = {}
    self._pausedSounds = paused

    for _, snd in ipairs(self._active) do
        if snd.src:isPlaying() then
            snd.src:pause()
            table.insert(paused, snd)
        end
    end
end

function SoundManager:resume()
    if not self._isPaused then return end
    self._isPaused = false

    if self._pausedSounds then
        for _, snd in ipairs(self._pausedSounds) do
            snd.src:play()
        end
        self._pausedSounds = nil
    end
end

---can be used for preloading
---@param snd_name string
function SoundManager:loadSource(snd_name)
    local source = self._source_cache[snd_name]
    if not source then
        local snd_path = ("res/sounds/%s.wav"):format(snd_name)
        source = love.audio.newSource(snd_path, "static")
        self._source_cache[snd_name] = source
    end

    return source
end

---@param snd_name string
---@return game.Sound
function SoundManager:newSound(snd_name)
    local source = self:loadSource(snd_name)
    local source_clone = source:clone()
    source_clone:setAttenuationDistances(80.0, 320.0)

    ---@type game.Sound
    local sound = Sound(self, source_clone)

    table.insert(self._active, sound)

    if #self._active > MAX_SIMULTANEOUS_SOURCES then
        print("sound overflow!")
        self._active[1].src:stop()
        self._active[1]:release()
        table.remove(self._active, 1)
    end

    return sound
end

---@param snd_name string
---@param ent any
function SoundManager:play(snd_name, ent)
    local snd = self:newSound(snd_name)
    if ent then
        snd:attachTo(ent)
    end
    snd.src:play()
    snd:release()
    return snd
end

---Play a sound, unless the same sound ID has been queued on the same frame.
---@param snd_name string
---@param ent any
function SoundManager:playNoOverlap(snd_name, ent)
    if self._overlap_exclude[snd_name] then
        return
    end

    self._overlap_exclude[snd_name] = true
    self:play(snd_name, ent)
end

function SoundManager:update()
    if self._isPaused then return end
    
    table.clear(self._overlap_exclude)

    love.audio.setPosition(self.listenerX, 70.0, self.listenerY)
    -- love.audio.setOrientation(
    --     0, 0, 1,
    --     0, 1, 0
    -- )

    for i=#self._active, 1, -1 do
        local snd = self._active[i]

        if snd._is_released and not snd.src:isPlaying() then
            snd.src:release()
            table.remove(self._active, i)
        else
            snd:_update_pos()
        end
    end
end

SoundManager.Sound = Sound
return SoundManager