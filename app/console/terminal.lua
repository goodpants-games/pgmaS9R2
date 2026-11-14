-- this is copied from System Shutdown Immiment, hence the differing naming
-- convention :p

---@class console.Terminal
---@overload fun(process_env:table?, no_startup_msg:boolean?):console.Terminal
local Terminal = batteries.class {
    name = "console.Terminal"
}

local fontres = require("fontres")
local utf8 = require("utf8")

---@param process_env table?
---@param no_startup_msg boolean?
function Terminal:new(process_env, no_startup_msg)
    self.font = fontres.monogram

    local char_width = self.font:getWidth("X")
    local char_height = self.font:getBaseline()

    ---@type {[string]:console.CommandDescriptor}
    self.commands = {}

    self.cols = math.floor(App.scrW / char_width)
    self.rows = math.floor(App.scrH / char_height)

    self.input_buffer = ""
    self.cursor_pos = 1
    self.buffer = {}

    for i=1, self.cols * self.rows do
        self.buffer[i] = 32
    end

    self.cur_process = nil
    self.cur_process_time_accum = nil
    self.cur_process_wait_length = nil

    ---@type nil|"char"|"line"
    self.cur_process_wait_mode = nil

    ---@type table
    self.process_env = nil

    self.env_fields = {}
    self.env_fields.puts = function(...) self:puts(...) end
    self.env_fields.print = function(...) self:print(...) end
    self.env_fields.getchar = function() return coroutine.yield("CHAR") end
    self.env_fields.getline = function() return coroutine.yield("LINE") end
    self.env_fields.wait = function(sec) return coroutine.yield(sec) end
    self.env_fields.log = print
    self.env_fields.term = self

    self._cursor_time = 0.0

    if process_env then
        self.process_env = table.copy(process_env)
    else
        self.process_env = {}
    end

    for k,v in pairs(_G) do
        self.process_env[k] = v
    end
    for k,v in pairs(self.env_fields) do
        self.process_env[k] = v
    end

    if not no_startup_msg then
        local startup_msg =
[[
Welcome little Xquid
]]
        self:puts(startup_msg)
    end

    self:puts(">")
end

function Terminal:release()
end

---@private
function Terminal:_line_shift()
    local r, c = self.rows, self.cols
    local last_row = (r-1) * c + 1
    for i=1, last_row - 1 do
        self.buffer[i] = self.buffer[i+c]
    end

    for i=last_row, r*c do
        self.buffer[i] = 32
    end

    self.cursor_pos = self.cursor_pos - self.cols
end

function Terminal:_newline()
    local cx, cy = self:cpos()
    if cy == self.rows then
        print("Need line shift")
        self:_line_shift()
        cy=cy-1
    end
    self.cursor_pos = self:_idx(1, cy+1)
end

---@private
---@param x number
---@param y number
function Terminal:_idx(x, y)
    if x < 1 or y < 1 or x > self.cols or y > self.rows then
        error("given position is out of bounds", 2)
    end

    return (y-1) * self.cols + (x-1) + 1
end

---@return integer x, integer y
function Terminal:cpos()
    local cpos = self.cursor_pos - 1
    local x = cpos % self.cols + 1
    local y = math.floor(cpos / self.cols) + 1
    return x, y
end

---@private
---@param x integer
---@param y integer
---@param ch integer
function Terminal:set_char(x, y, ch)
    self.buffer[self:_idx(x, y)] = ch
end

---@param x integer
---@param y integer
function Terminal:go_to(x, y)
    self.cursor_pos = self:_idx(x, y)
end

---@param ch integer
function Terminal:_putc(ch)
    if ch == 10 then
        self:_newline()
    else
        self.buffer[self.cursor_pos] = ch
        self.cursor_pos = self.cursor_pos + 1

        if self.cursor_pos > self.rows * self.cols then
            self:_line_shift()
            self.cursor_pos = self:_idx(1, self.rows)
        end
    end
end

---@param ... string
function Terminal:puts(...)
    for i=1, select("#", ...) do
        local text = select(i, ...)
        for _, ch in utf8.codes(text) do
            self:_putc(ch)
        end
    end
end

---@param ... any
function Terminal:print(...)
    for i=1, select("#", ...) do
        if i > 1 then
            self:puts("    ")
        end

        local str = tostring(select(i, ...))
        self:puts(str)
    end

    self:puts("\n")
end

function Terminal:backspace()
    self.cursor_pos = math.max(1, self.cursor_pos - 1)
    self.buffer[self.cursor_pos] = 32
end

---@param no_prompt_string boolean?
function Terminal:clear(no_prompt_string)
    for i=1, self.rows * self.cols do
        self.buffer[i] = 32
    end

    self.cursor_pos = 1

    if not no_prompt_string then
        self:puts(">")
    end
end

---@private
---@param ... any
function Terminal:_resume_process(...)
    self.cur_process_time_accum = nil
    self.cur_process_wait_length = nil
    self.cur_process_wait_mode = nil

    local s, wait_time = coroutine.resume(self.cur_process, ...)
    if not s then
        local err = wait_time
        self:print(err)
        print(("%s\n\ntraceback: %s"):format(err, debug.traceback(self.cur_process)))
    end

    if coroutine.status(self.cur_process) == "dead" then
        self.cur_process = nil
        self:puts(">")
        return
    end

    if wait_time == "CHAR" then
        self.cur_process_wait_mode = "char"
    elseif wait_time == "LINE" then
        self.cur_process_wait_mode = "line"
    else
        self.cur_process_time_accum = 0.0
        self.cur_process_wait_length = wait_time or 0.0
    end
end

function Terminal:_show_help()
    local names = {}
    for k, _ in pairs(self.commands) do
        table.insert(names, k)
    end
    table.sort(names)

    self:print("available commands:")
    for _, name in ipairs(names) do
        local cmd = self.commands[name]
        self:puts(name)
        self:puts(" ")
        self:puts(cmd.help)
        self:puts("\n")
    end
end

---@return boolean
function Terminal:is_process_running()
    return self.cur_process ~= nil
end

---@param proc function
---@param ... any
function Terminal:execute_process(proc, ...)
    self.cur_process = coroutine.create(proc)
    self:_resume_process(...)
end

---@param cmd string
function Terminal:execute_command(cmd)
    local chunk ---@type function?
    local chunkArgs = {}

    if cmd:sub(1, 1) == "!" then
        -- execute lua string
        local err
        chunk, err = loadstring(cmd:sub(2), "=command")
        if not chunk then
            self:puts(err)
            self:puts("\n>")
            return
        end

        setfenv(chunk, self.process_env)
    else
        local args = {}
        for arg in string.gmatch(cmd, "[^%s]+") do
            table.insert(args, arg)
        end

        if not args[1] then
            self:puts(">")
            return
        end

        if args[1] == "clear" then
            self:clear()
            return
        end

        if args[1] == "help" then
            self:_show_help()
            self:puts(">")
            return
        end

        local desc = self.commands[args[1]]
        if not desc then
            self:puts(args[1], ": command not found\n")
            self:puts(">")
            return
        end

        chunk = desc.func
        chunkArgs = { self.env_fields, unpack(args, 2) }
    end

    self.cur_process = coroutine.create(chunk)
    self:_resume_process(unpack(chunkArgs))
end

---@param text string
function Terminal:text_input(text)
    if self.cur_process_wait_mode == "char" then
        local ti = 1
        local textcp = { utf8.codepoint(text, 1, -1) }
        local strlen = #textcp
        while ti <= strlen and self.cur_process_wait_mode == "char" do
            self:_resume_process(utf8.char(textcp[ti]))
            ti=ti+1
        end
        return
    end

    local text_start = 1
    while true do
        if text_start > text:len() then
            break
        end

        local text_end = string.find(text, "\n", text_start, true)
        if not text_end then
            text_end = text:len() + 1
        elseif text_end == text_start then
            self:puts("\n")
            if self.cur_process == nil then
                self:execute_command(self.input_buffer)
                self.input_buffer = ""
            elseif self.cur_process_wait_mode == "line" then
                self:_resume_process(self.input_buffer)
                self.input_buffer = ""
            end
            
            text_start = text_end + 1
            goto continue
        end

        local slice = string.sub(text, text_start, text_end - 1)
        self.input_buffer = self.input_buffer .. slice
        self:puts(slice)

        text_start = text_end
        ::continue::
    end

    self._cursor_time = 0.0
end

---@param key love.KeyConstant
function Terminal:key_pressed(key)
    if key == "v" and love.keyboard.isDown("lctrl", "rctrl") then
        local txt = love.system.getClipboardText()
        if txt then
            self:text_input(txt)
        end
        return
    end

    if key == "enter" or key == "return" then
        if self.cur_process_wait_mode == "char" then
            self:_resume_process("\n")
        else
            self:text_input("\n")
        end

        return
    end

    if key == "backspace" then
        if self.cur_process_wait_mode == "char" then
            self:_resume_process("backspace")
        else
            local len = utf8.len(self.input_buffer)
            if len > 0 then
                self:backspace()

                if len == 1 then
                    self.input_buffer = ""
                else
                    self.input_buffer = self.input_buffer:sub(1, utf8.offset(self.input_buffer, -1) - 1)
                end

                self._cursor_time = 0.0
            end
        end

        return
    end

    if LOVEJS and key == "space" then
        self:text_input(" ")
        return
    end

    if self.cur_process_wait_mode == "char" then
        if key == "left" or key == "right" or key == "up" or key == "down" then
            self:_resume_process(key)
        end
    end
end

---@param dt number
function Terminal:update(dt)
    if self.cur_process_time_accum then
        self.cur_process_time_accum = self.cur_process_time_accum + dt
        if self.cur_process_time_accum >= self.cur_process_wait_length then
            self:_resume_process(self.cur_process_time_accum)
        end
    end

    self._cursor_time = self._cursor_time + dt
end

---@param bg_opacity number?
function Terminal:draw(bg_opacity)
    Lg.push("all")

    Lg.setColor(0, 0, 0, bg_opacity or 1.0)
    Lg.rectangle("fill", 0, 0, App.scrW, App.scrH)
    
    Lg.setFont(self.font)
    Lg.setColor(1, 1, 1)

    local line_height = self.font:getBaseline()
    local char_w = self.font:getWidth("X")

    for row=1, self.rows do
        for col=1 , self.cols do
            local cp = self.buffer[self:_idx(col, row)]
            if cp ~= 32 then
                Lg.print(utf8.char(cp),
                         char_w * (col -1) + 1,
                         line_height * (row - 1))
            end
        end
        -- local rs = (row-1) * self.cols + 1
        -- local re = rs + self.cols - 1
        -- local line = utf8.char(unpack(self.buffer, rs, re))
    end

    if self._cursor_time % 1.0 < 0.5 then
        local cx, cy = self:cpos()
        Lg.rectangle("fill", (cx - 1) * char_w + 1, (cy - 1) * line_height + 1, 1, line_height)
    end

    Lg.pop()
end

return Terminal