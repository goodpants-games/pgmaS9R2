local Input = {}
local baton = require("input.baton")
local UserPref = require("userpref")

local base_controls = {
    pause = {'key:escape', 'key:`', 'button:start'},

    left = {'axis:leftx-', 'button:dpleft'},
    right = {'axis:leftx+', 'button:dpright'},
    up = {'axis:lefty-', 'button:dpup'},
    down = {'axis:lefty+', 'button:dpdown'},

    fire = {"mouse:1", "button:a"}
}

local function get_new_baton_config()
    local input_mode = UserPref.input_mode

    local controls = table.deep_copy(base_controls) --[[@as table]]
    local tinsert = table.insert

    tinsert(controls.left, "key:left")
    tinsert(controls.right, "key:right")
    tinsert(controls.up, "key:up")
    tinsert(controls.down, "key:down")

    if input_mode == "wasd" then
        tinsert(controls.left, "key:a")
        tinsert(controls.right, "key:d")
        tinsert(controls.up, "key:w")
        tinsert(controls.down, "key:s")
    end

    return controls
end

Input.players = {}

function Input.init()
    Input.players[1] = baton.new {
        controls = get_new_baton_config(),
        pairs = {
            move = {'left', 'right', 'up', 'down'}
        },
        joystick = love.joystick.getJoysticks()[1],
    }
end

function Input.update_config()
    local new_config = get_new_baton_config()
    local active_config = Input.players[1].config.controls

    for k, sources in pairs(active_config) do
        table.clear(sources)
        for i,v in pairs(new_config[k]) do
            sources[i] = v
        end
    end
    -- .controls = 
end

function Input.update()
    for _, p in pairs(Input.players) do
        p:update()
    end
end

return Input