local module = {}
local Terminal = require("console.terminal")
local terminal = Terminal()

local isEnabled = false

---@class console.TerminalEnv
---@field puts fun(...:string)
---@field print fun(...)
---@field getchar fun()
---@field getline fun()
---@field wait fun(secs:number)
---@field term console.Terminal

---@class console.CommandDescriptor
---@field name string
---@field help string
---@field func fun(term_env:console.TerminalEnv, ...)

---@param value boolean
function module.setEnabled(value)
    if value == isEnabled then
        return
    end

    if value then
        love.keyboard.setTextInput(true)
        love.keyboard.setKeyRepeat(true)
        isEnabled = true
    else
        love.keyboard.setTextInput(false)
        love.keyboard.setKeyRepeat(false)
        isEnabled = false
    end
end

function module.isEnabled()
    return isEnabled
end

function module.textInput(text)
    if not isEnabled then
        return
    end

    terminal:text_input(text)
end

---@param desc console.CommandDescriptor
function module.addCommand(desc)
    terminal.commands[desc.name] = desc
end

---@param name string
function module.removeCommand(name)
    terminal.commands[name] = nil
end

function module.keyPressed(key)
    if not isEnabled then
        return
    end
    
    terminal:key_pressed(key)
end

function module.draw()
    if not isEnabled then
        return
    end

    terminal:draw(0.5)
end

return module