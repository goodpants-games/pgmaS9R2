--[[
    sceneman: scene manager

    scene management
    ----
    from the main script, call sceneman.update(dt) and sceneman.draw() on every
    update and draw, respectively (obviously).

    if you want to switch scene, call sceneman.switchScene(path, ...):
        - path is the require path to the lua script.
        - ... are the args to pass to the scene's load function.

    you can set sceneman.scenePrefix if all scenes are organized under a common
    folder, and you want to save typing. this scene prefix will be directly
    inserted before the path given in switchScene. also, sceneman.currentScene
    can be read to return the current scene. it is not advised to write to it.


    scene creation
    ----
    each scene should belong in its own script.
    to create a scene, call `sceneman.scene()`. it will return a scene object
    where you can then assign callbacks such as "load", "update(dt)", and "draw"
    (among others). the script must then return this scene object.


    callback modes
    ----
    there are three available callback modes, used to control how LOVE events
    are dispatched to each scene:
    - manual: you must call sceneman.dispatch(eventName, ...) when the LOVE
              event occurs.
    - set:    when a scene is loaded, it automatically assigns the scene's
              callbacks to the love table. but this prevents you from setting up
              LOVE callbacks directly, since it will be overwritten when a scene
              changes.
    - hook:   this attaches a metatable to the love table to make LOVE event
              callbacks go through the current scene. to call the relevant event
              callback defined in the love table, you call
              sceneman.rawCallback(eventName, ...).
    
    to set the callback mode, you must call sceneman.setCallbackMode(mode) on
    project initialization. if not called, it will fall back to the "manual"
    callback mode.

    note that the scene's load, update, and draw functions are automatically
    called by sceneman.update and sceneman.draw. also note that event callbacks
    are not called during transitions.

    for the "set" and "hook" callback modes, you can override the event
    injection process by setting the sceneman.setLoveCallback property. it
    should be assigned a function of this form:
    
        function(eventName, scene):void
    
    where eventName is the name of the event, and scene is the scene table being
    loaded. with the "set" mode, this overrides the process of assigning the
    callback to the love table, meaning that you can cancel the process by
    simply not making an assignment to the love table in your function. but for
    the "hook" mode, the hook process will occur regardless.


    transitions
    ----
    you can switch to a scene with a transition by calling
    sceneman.useTransition(transitionPath, ...) before calling switchScene. the
    arguments work similarly to switchScene.

    it will use the given transition only for the next switchScene call.
    afterwards, it will be reset.

    there is also a sceneman.transitionPrefix that functions similarly to
    sceneman.scenePrefix, but for transitions.

    to create a transition, make a script and call sceneman.transition(). it
    will return a transition object where you will then assign the callbacks
    "load" (optional), "update(dt)", and "draw". the script must then return
    this transition object.

    additionally, each transition object will have three fields related to the
    current state of the transition, which are set before load is called:
        - oldScene: the scene that is being transitioned from. can be set to nil
                    when the scene can be unloaded.
        - newScene: the scene that is being transitioned to. do not set.
        - done:     set to false before load is called, when set to true the
                    transition will end on the next sceneman.update call

    while the transition is in progress, scene.currentScene will be nil and
    scene.currentTransition will be set to the transition object.

    
    copyright notice
    ----
    
    Copyright (c) 2025 pkhead

    This software is provided 'as-is', without any express or implied
    warranty. In no event will the authors be held liable for any damages
    arising from the use of this software.

    Permission is granted to anyone to use this software for any purpose,
    including commercial applications, and to alter it and redistribute it
    freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
       claim that you wrote the original software. If you use this software
       in a product, an acknowledgment in the product documentation would be
       appreciated but is not required.
    2. Altered source versions must be plainly marked as such, and must not be
       misrepresented as being the original software.
    3. This notice may not be removed or altered from any source distribution.
--]]

local sceneman = {}
sceneman._version = "0.2.0"

local unpack = table.unpack or unpack  ---@diagnostic disable-line

-- placeholder functions
local function functionNoOp() end

---@alias sceneman.CallbackMode
---|    "manual"
---|    "set"
---|    "hook"

---@class sceneman.Scene
---@field load fun(args...: any)|nil
---@field unload fun()|nil
---@field update fun(dt: number)|nil
---@field draw fun()|nil
local Scene = {}
Scene.__index = Scene

Scene.load = functionNoOp
Scene.unload = functionNoOp
Scene.update = functionNoOp
Scene.draw = functionNoOp

---@class sceneman.Transition
---@field load fun(args...: any)|nil
---@field update fun(dt: number)|nil
---@field draw fun()|nil
---@field oldScene sceneman.Scene?
---@field newScene sceneman.Scene
---@field done boolean
local Transition = {}
Transition.__index = Transition

Transition.load = functionNoOp
Transition.update = functionNoOp
Transition.draw = functionNoOp

---Let this module define a new scene. The calling module must then define
---callbacks in and return the scene object.
---@return sceneman.Scene
function sceneman.scene()
    if sceneman.callbackMode == nil then
        sceneman.setCallbackMode("manual")
    end

    local scene = setmetatable({}, Scene)
    return scene
end

---Let this module define a new transition. The calling module must then define
---callbacks in and return the transition object.
---@return sceneman.Transition
function sceneman.transition()
    local trans = setmetatable({}, Transition)
    return trans
end

local sceneLoad = nil
local transitionLoad = nil

local loveCallbacks = {}
for _, v in ipairs({
    "errorhandler",
    "lowmemory",
    "quit",
    "threaderror",

    "directorydropped",
    "displayrotated",
    "filedropped",
    "focus",
    "mousefocus",
    "resize",
    "visible",

    "keypressed",
    "keyreleased",
    "textedited",
    "textinput",

    "mousemoved",
    "mousepressed",
    "mousereleased",
    "wheelmoved",

    "gamepadaxis",
    "gamepadpressed",
    "gamepadreleased",
    "joystickadded",
    "joystickaxis",
    "joystickhat",
    "joystickpressed",
    "joystickreleased",
    "joystickremoved",

    "touchmoved",
    "touchpressed",
    "touchreleased",

    -- love 12 callbacks
    "localechanged",
    "dropbegan",
    "dropmoved",
    "dropcompleted",
    "audiodisconnected",

    "sensorupdated",
    "joysticksensorupdated",

    "exposed",
    "occluded",
}) do
    loveCallbacks[v] = true
end

local function defaultSetLoveCallback(callbackName, func)
    love[callbackName] = func
end

local function defaultSetLoveCallbackMt()
    -- no-op
end

---**For the "set" and "hook" callback modes.**
---
---User-provided function that is called when a scene wants to hook into a LOVE
---callback, excluding load, update and draw. If nil (the default), it will hook
---it into the proper callback itself.
---@type fun(callbackName: string, func: function)
sceneman.setLoveCallback = nil

---**For the "hook" callback mode.**
---
---Call the LOVE callback defined in the love table instead of the the scene
---table.
---@type fun(name: string, ...)|nil
sceneman.rawCallback = nil

---(Read-only)
---@type sceneman.Scene?
sceneman.currentScene = nil

---(Read-only)
---@type sceneman.Transition?
sceneman.currentTransition = nil

---The string to prepend to scenePath when sceneman.loadScene is called.
sceneman.scenePrefix = ""

---The string to prepend to transitionPath when sceneman.useTransition is called
sceneman.transitionPrefix = ""

---(Read-only) The current callback mode. To change, call
---sceneman.setCallbackMode
---@type string
sceneman.callbackMode = nil

---Load a scene from a Lua script. It will be loaded on the next scene.update
---call.
---@param scenePath string The path to the scene script.
---@param ... any Arguments to pass to the scene.
function sceneman.switchScene(scenePath, ...)
    scenePath = sceneman.scenePrefix .. scenePath
    local scene = require(scenePath)

    sceneLoad = {
        scene = scene,
        args = {...}
    }
end

---Load a transition from a Lua script. It will be used for the next switchScene
---call.
---@param transitionPath string The path to the transition script.
---@param ... any Arguments to pass to the transition.
function sceneman.useTransition(transitionPath, ...)
    transitionPath = sceneman.transitionPrefix .. transitionPath
    local transition = require(transitionPath)

    transitionLoad = {
        transition = transition,
        args = {...}
    }
end

---Enable a callback-hooking plan that assigns a metatable to the LOVE global,
---allowing LOVE callback functions to be "intercepted" by the active scene's
---equivalenty-named callback function. The callback function may then call
---sceneman.rawCallback to call the original LOVE callback function.
local function enableCallbackHook()
    local rawCallbacks = {}

    for cbName, _ in pairs(loveCallbacks) do
        rawCallbacks[cbName] = love[cbName]
        love[cbName] = nil
    end

    setmetatable(love, {
        __index = function(t, k)
            if not loveCallbacks[k] then
                return rawget(t, k)
            end

            if sceneman.currentScene ~= nil and sceneman.currentScene[k] then
                return sceneman.currentScene[k]
            else
                return rawCallbacks[k]
            end
        end,

        __newindex = function(t, k, v)
            if loveCallbacks[k] then
                rawCallbacks[k] = v
            else
                rawset(t, k, v)
            end
        end
    })

    function sceneman.rawCallback(name, ...)
        local f = rawCallbacks[name]
        if f ~= nil then
            return f(...)
        end
    end
end

---Use a callback mode. If called, must be before any scenes or transitions are
---created.
---@param mode sceneman.CallbackMode
function sceneman.setCallbackMode(mode)
    if sceneman.callbackMode ~= nil then
        error("cannot set callback mode more than once or after a scene was created.", 2)
    end

    if mode == "manual" then
        sceneman.callbackMode = "manual" 
    elseif mode == "set" then
        sceneman.callbackMode = "set"
    elseif mode == "hook" then
        sceneman.callbackMode = "hook"
        enableCallbackHook()
    else
        error(("invalid callback mode '%s'. must be 'manual', 'set', or 'hook'."):format(tostring(mode)), 2)
    end
end

local function assignLoveCallbacks(scene)
    if sceneman.callbackMode == "manual" then return end

    local setCallback = sceneman.setLoveCallback or (sceneman.callbackMode == "hook" and defaultSetLoveCallbackMt or defaultSetLoveCallback)
    for k, v in pairs(scene) do
        if loveCallbacks[k] then
            setCallback(k, v)
        end
    end
end

---Update the current scene.
---@param dt number
function sceneman.update(dt)
    if sceneman.currentTransition ~= nil then
        sceneman.currentTransition.update(dt)

        if sceneman.currentTransition.done then
            local oldScene = sceneman.currentTransition.oldScene
            if oldScene ~= nil and oldScene.unload ~= nil then
                oldScene.unload()
            end

            sceneman.currentScene = sceneman.currentTransition.newScene
            sceneman.currentTransition = nil
            assignLoveCallbacks(sceneman.currentScene)
        end
    elseif sceneLoad then
        -- load scene with transition
        if transitionLoad then
            ---@type sceneman.Transition
            local inst = transitionLoad.transition
            sceneman.currentTransition = inst

            inst.done = false
            inst.oldScene = sceneman.currentScene
            inst.newScene = sceneLoad.scene
            inst.newScene.load(unpack(sceneLoad.args))
            inst.load(unpack(transitionLoad.args))

            transitionLoad = nil
            sceneLoad = nil
            sceneman.currentScene = nil
        
        -- load scene without transition
        else
            if sceneman.currentScene ~= nil and sceneman.currentScene.unload ~= nil then
                sceneman.currentScene.unload()
            end

            sceneman.currentScene = sceneLoad.scene
            assignLoveCallbacks(sceneman.currentScene)
            sceneman.currentScene.load(unpack(sceneLoad.args))

            sceneLoad = nil
        end
    end
        
    if sceneman.currentScene then
        sceneman.currentScene.update(dt)
    end
end

---Draw the current scene.
function sceneman.draw()
    if sceneman.currentTransition then
        sceneman.currentTransition.draw()
    elseif sceneman.currentScene then
        sceneman.currentScene.draw()
    end
end

---Dispatch an event to the current scene.
---
---This simply calls the function of the same name in the current scene table
---with the given arguments.
---@param name string
---@param ... any
function sceneman.dispatch(name, ...)
    if not sceneman.currentScene then
        return
    end

    if sceneman.currentScene[name] then
        sceneman.currentScene[name](...)
    end
end

return sceneman