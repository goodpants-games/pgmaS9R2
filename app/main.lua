require("conf2")

local fontres = require("fontres")
local Input = require("input")

App.mouseX = 0
App.mouseY = 0
App.frame = 0

-- this is the canvas the entire game is rendered into
local display_canvas = Lg.newCanvas(App.scrW, App.scrH, { dpiscale = 1.0 })

local display_ox = 0.0
local display_oy = 0.0
local display_scale = 1.0
local game_focused = true
local dt_accum = 0.0

-- make sure draw is not ever called without a previous call to tick
local did_tick = false

-- this class is used for analyzing the windowed average and max of a discrete
-- "signal" (in this application, the update time, draw time, total frame time,
-- and Lua memory usage through the program's runtime). the window size is
-- hardcoded to 0.5 seconds.
local WindowedAnalyzer = batteries.class()
local anl_update, anl_draw, anl_total, anl_mem
local dbgDisplayPrint ---@type fun(txt:string, x:number, y:number)

local perf_heavy_frame = false
-- call this on every frame whenever major loading is performed
function Mark_perf_heavy_frame()
    perf_heavy_frame = true
end

local function update_display_fit()
    display_scale = math.min(Lg.getHeight() / App.scrH, Lg.getWidth() / App.scrW)
    display_scale = math.max(1, display_scale)
    -- display_scale = math.floor(display_scale)
    display_ox = (Lg.getWidth() - App.scrW * display_scale) / 2
    display_oy = (Lg.getHeight() - App.scrH * display_scale) / 2
    display_ox = math.floor(display_ox)
    display_oy = math.floor(display_oy)
end

--------------------------------------------------------------------------------

---@diagnostic disable-next-line duplicate-set-field
function love.load(args)
    love.keyboard.setTextInput(false)

    -- parse comamnd-line arguments
    if Debug.enabled then
        local argi = 1
        while argi <= #args do
            local arg = args[argi]
            argi = argi + 1
        end
    end

    anl_update = WindowedAnalyzer()
    anl_draw = WindowedAnalyzer()
    anl_total = WindowedAnalyzer()
    anl_mem = WindowedAnalyzer()

    Input.init()
    Lg.setFont(fontres.monogram)
    Sceneman.switchScene("entry")
end

---@diagnostic disable-next-line duplicate-set-field
function love.keypressed(key, _, isrepeat)
    if Debug.console.isEnabled() then
        Debug.console.keyPressed(key)
    else
        if isrepeat then return end
        Sceneman.dispatch("keypressed", key)
    end

    -- toggle debug mode when f1 is pressed
    if key == "f1" then
        Debug.enabled = not Debug.enabled
        if not Debug.enabled then
            Debug.console.setEnabled(false)
        end
    end

    if Debug.enabled then
        if key == "f2" then
            Debug.console.setEnabled(not Debug.console.isEnabled())
        end
    end

    -- capture a screenshot of the window when f12 is pressed. the resolution of
    -- the output image is the same as the internal rendering resolution.
    if not IS_PACKAGED and key == "f12" then
        Lg.captureScreenshot(function(data)
            ---@cast data love.ImageData
            local fdata = data:encode("png")

            local file = assert(io.open("screenshot.png", "wb"), "could not open screenshot.png")
            file:write(fdata:getString())
            file:close()

            fdata:release()
            data:release()
        end)
    end
end

---@diagnostic disable-next-line duplicate-set-field
function love.textinput(...)
    if Debug.console.isEnabled() then
        Debug.console.textInput(...)
    else
        Sceneman.dispatch("textinput", ...)
    end
end

---@diagnostic disable-next-line duplicate-set-field
function love.update(dt)
    Jprof.push("frame")
    local start = love.timer.getTime()

    -- always step the GC for a small fraction of the frame. this should help
    -- amortize GC pressure.
    Jprof.push("manual gc")
    batteries.manual_gc(1e-1)
    Jprof.pop()
    anl_mem:add_sample(collectgarbage("count"))

    if not Debug.console.isEnabled() then
        Input.update()
    end

    Debug.draw.enabled = Debug.enabled

    update_display_fit()
    App.mouseX = (love.mouse.getX() - display_ox) / display_scale
    App.mouseY = (love.mouse.getY() - display_oy) / display_scale
    App.mouseX = math.max(0, math.min(App.scrW, App.mouseX))
    App.mouseY = math.max(0, math.min(App.scrH, App.mouseY))

    -- rawUpdate is used primarily for input polling; game logic should not
    -- occur here.
    Jprof.push("rawUpdate")
    Sceneman.dispatch("rawUpdate", dt)
    Jprof.pop("rawUpdate")

    -- dt snap calculation
    -- https://medium.com/@tglaiel/how-to-make-your-game-run-at-60fps-24c61210fe75
    local dt_to_accum = dt
    local DT_SNAP_EPSILON = 0.002
    local tick_len = App.tickLength

    if math.abs(dt - tick_len) < DT_SNAP_EPSILON then -- 60 fps?
        dt_to_accum = tick_len
    elseif math.abs(dt - tick_len * 0.5) < DT_SNAP_EPSILON then -- 120 fps?
        dt_to_accum = tick_len * 0.5
    end

    local iter = 1

    if perf_heavy_frame then
        perf_heavy_frame = false
    else
        dt_accum = dt_accum + dt_to_accum
    end

    while dt_accum >= tick_len do
        if iter > 8 then
            print("too many ticks in one frame!")
            dt_accum = dt_accum % tick_len
            break
        end
        
        Jprof.push("update")
        Sceneman.update(App.tickLength)
        did_tick = true
        Jprof.pop("update")

        dt_accum = dt_accum - tick_len
        iter=iter+1
        App.frame = App.frame + 1
    end

    anl_update:update(dt)
    anl_draw:update(dt)
    anl_total:update(dt)
    anl_mem:update(dt)

    anl_update:add_sample(love.timer.getTime() - start)
    anl_total:add_sample(dt)
end

---@diagnostic disable-next-line duplicate-set-field
function love.draw()
    local draw_ts = love.timer.getTime()
    Jprof.push("draw")

    if did_tick then
        Lg.setCanvas(display_canvas)
        local bg_r, bg_g, bg_b, bg_a = Lg.getBackgroundColor()
        Lg.clear(bg_r, bg_g, bg_b, bg_a)

        Sceneman.draw()
        Debug.draw:flush()
        Debug.console.draw()

        Lg.setCanvas()
    end
    
    -- draw display onto window
    Jprof.push("display")
    Lg.clear(0, 0, 0, 1)
    Lg.setColor(1, 1, 1)
    Lg.origin()
    if did_tick then
        Lg.draw(display_canvas, display_ox, display_oy, 0, display_scale, display_scale)
    end
    Lg.setShader()

    Jprof.pop("display")
    Jprof.pop("draw")

    local draw_frametime = love.timer.getTime() - draw_ts
    anl_draw:add_sample(draw_frametime)

    -- debug text
    if Debug.enabled then
        Lg.push("all")
        Lg.setFont(fontres.monogram)

        dbgDisplayPrint(
            ("mem: %.2f MiB / %.2f MiB"):format(anl_mem.dt_avg / 1000, anl_mem.dt_max / 1000),
            1, 1)
        dbgDisplayPrint(
            ("update: %.1f ms / %.1f ms"):format(anl_update.dt_avg * 1000, anl_update.dt_max * 1000),
            1, 11)
        dbgDisplayPrint(
            ("draw: %.1f ms / %.1f ms"):format(anl_draw.dt_avg * 1000, anl_draw.dt_max * 1000),
            1, 21)
        dbgDisplayPrint(
            ("frame: %.1f ms / %.1f ms"):format(anl_total.dt_avg * 1000, anl_total.dt_max * 1000),
            1, 31)
        
        Lg.pop()
    end

    Jprof.pop("frame")
end

--------------------------------------------------------------------------------

---@diagnostic disable
function love.run()
	if love.load then
        love.load(love.parsedGameArguments, love.rawGameArguments)
    end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

    if love.graphics then
        print(love.graphics.getRendererInfo())
    end

	local dt = 0

	-- Main loop time.
	return function()
        assert(love.event)
        assert(love.window)

		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

        if game_focused then
            -- Call update and draw
            if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

            if love.graphics and love.graphics.isActive() then
                love.graphics.origin()
                love.graphics.clear(love.graphics.getBackgroundColor())

                if love.draw then love.draw() end

                love.graphics.present()
            end
        end

		if not LOVEJS and love.timer then love.timer.sleep(0.001) end
	end
end

--------------------------------------------------------------------------------

function WindowedAnalyzer:new()
    ---@private
    self._time_passed = 0.0
    ---@private
    self._dt_accum = 0.0
    ---@private
    self._dt_max = 0.0
    ---@private
    self._samples = 0

    self.dt_max = 0.0
    self.dt_avg = 0.0
end

---@param elapsed number
function WindowedAnalyzer:add_sample(elapsed)
    self._dt_accum = self._dt_accum + elapsed
    if elapsed > self._dt_max then
        self._dt_max = elapsed
    end

    self._samples = self._samples + 1.0
end

---@param dt number
function WindowedAnalyzer:update(dt)
    self._time_passed = self._time_passed + dt
    if self._time_passed > 0.5 then
        self._time_passed = self._time_passed % 0.5

        self.dt_max = self._dt_max
        self.dt_avg = self._dt_accum / self._samples

        self._dt_accum = 0.0
        self._dt_max = 0.0
        self._samples = 0
    end
end

function dbgDisplayPrint(txt, x, y)
    Lg.setColor(0, 0, 0)
    Lg.print(txt, x+1, y+1)
    Lg.setColor(1, 1, 1)
    Lg.print(txt, x, y)
end