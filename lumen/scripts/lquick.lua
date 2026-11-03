-- LUMEN Quick
-- Quick toggles: one screen with the overlays you switch most often.
--
-- Open it from Overlay > LUMEN Quick (tip: star it so it appears in My Menu).
-- Arrows move, SET toggles, Q closes, Trash / MENU close the menu.
--
-- Only one task (the screen loop) ever calls task.yield: ML does not allow
-- task.yield from two tasks of the same script at once.
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.

-- { label, ML menu, ML entry }
local TILES =
{
    { "Overlays",    "Overlay", "Global Draw" },
    { "Zebras",      "Overlay", "Zebras"      },
    { "Focus Peak",  "Overlay", "Focus Peak"  },
    { "Magic Zoom",  "Overlay", "Magic Zoom"  },
    { "Cropmarks",   "Overlay", "Cropmarks"   },
    { "Spotmeter",   "Overlay", "Spotmeter"   },
    { "False Color", "Overlay", "False color" },
    { "Histogram",   "Overlay", "Histogram"   },
}
local COLS, ROWS = 4, 2

-- layout (720 x 480)
local MARGIN, GAP = 32, 16
local TILE_W = (720 - 2 * MARGIN - (COLS - 1) * GAP) // COLS   -- 152
local TILE_H = 120
local GRID_Y = 120

lquick = { sel = 1, open = false, states = {}, values = {} }

-- responsiveness: keys every 20 ms, all queued keys handled before one
-- redraw, tile states cached (only the toggled tile is re-read)
local KEY_POLL_MS = 20

-- Start a task with a small stack. The 550D has very little memory for
-- task stacks: 32-64 KB requests fail with "task not started". Try 16 KB,
-- then 8 KB (ML's own C tasks use 4-8 KB). Returns true if started.
local function start_task(fn)
    for _, stack in ipairs({ 0x4000, 0x2000 }) do
        if pcall(task.create, fn, 0x1c, stack) then return true end
    end
    return false
end

local function tile_state(t)
    local ok, v = pcall(menu.get, t[2], t[3], 0)
    if not ok or v == nil then return nil end
    return v ~= 0
end

-- main part of the value only ("Percent, AFbox" -> "Percent"), so it fits a tile
local function tile_value(t)
    local ok, v = pcall(menu.get, t[2], t[3])
    if not ok or v == nil then return "n/a" end
    v = tostring(v)
    return v:match("^([^,]+)") or v
end

-- switching OFF remembers the mode; switching ON restores it
-- (Global Draw: 3 = "ON, all modes", the Magic Lantern default)
local ON_DEFAULT = { ["Global Draw"] = 3 }
lquick.last_on = {}

local function toggle(t)
    local ok0, v = pcall(menu.get, t[2], t[3], 0)
    if not ok0 or v == nil then return false end
    local new
    if v ~= 0 then
        lquick.last_on[t[3]] = v
        new = 0
    else
        new = lquick.last_on[t[3]] or ON_DEFAULT[t[3]] or 1
    end
    local ok, result = pcall(menu.set, t[2], t[3], new)
    return ok and result ~= nil
end

-- Key capture while the screen is open. Trash and MENU are NOT blocked, so
-- Magic Lantern closes its menu at once as usual (and this screen with it).
-- Half/full shutter also pass. Everything else is queued for this screen.
-- The previous key handler is restored only if it was replaced.
local function capture_start(self)
    self.queue, self.leaving = {}, false
    self.old_keypress = event.keypress
    event.keypress = function(key)
        if key == 0 then return true end
        if key == KEY.TRASH or key == KEY.MENU then
            self.leaving = true
            return true
        end
        if key <= KEY.UNPRESS_FULLSHUTTER then return true end
        table.insert(self.queue, key)
        return false
    end
    self.capturing = true
end

local function capture_stop(self)
    if self.capturing then
        event.keypress = self.old_keypress
        self.capturing = false
    end
    self.queue = {}
end


function lquick:refresh(i)
    local from, to = i or 1, i or #TILES
    for k = from, to do
        self.states[k] = tile_state(TILES[k])
        self.values[k] = self.states[k] and tile_value(TILES[k]) or nil
    end
end

function lquick:draw()
    display.draw(function()
        display.rect(0, 0, 720, 480, COLOR.BLACK, COLOR.BLACK)
        display.print("Quick toggles", MARGIN, 44, FONT.LARGE, COLOR.WHITE, COLOR.BLACK)
        display.rect(MARGIN, 92, 60, 3, COLOR.ORANGE, COLOR.ORANGE)

        for i, t in ipairs(TILES) do
            local col = (i - 1) % COLS
            local row = (i - 1) // COLS
            local x = MARGIN + col * (TILE_W + GAP)
            local y = GRID_Y + row * (TILE_H + GAP)
            local on = self.states[i]
            local bg = on and COLOR.gray(20) or COLOR.gray(8)
            local border = COLOR.gray(25)
            if i == self.sel then border = COLOR.ORANGE end

            display.rect(x, y, TILE_W, TILE_H, border, bg)
            if i == self.sel then
                display.rect(x + 1, y + 1, TILE_W - 2, TILE_H - 2, COLOR.ORANGE)
            end
            display.print(t[1], x + 14, y + 16, FONT.MED, COLOR.WHITE, bg, TILE_W - 28)
            local fg = on and COLOR.ORANGE or COLOR.gray(55)
            local text = (on == nil) and "n/a" or (on and (self.values[i] or "ON") or "OFF")
            display.print(text, x + 14, y + TILE_H - 44, FONT.MED, fg, bg, TILE_W - 28)
        end

        display.print("Arrows: move    SET: toggle    Q: back    Trash: close",
            MARGIN, 420, FONT.MED, COLOR.gray(60), COLOR.BLACK)
    end)
end

function lquick:handle_key(key)
    if key == KEY.Q then
        return false
    elseif key == KEY.LEFT or key == KEY.WHEEL_LEFT then
        self.sel = (self.sel - 2) % #TILES + 1
    elseif key == KEY.RIGHT or key == KEY.WHEEL_RIGHT then
        self.sel = self.sel % #TILES + 1
    elseif key == KEY.UP or key == KEY.WHEEL_UP or key == KEY.DOWN or key == KEY.WHEEL_DOWN then
        self.sel = (self.sel - 1 + COLS) % #TILES + 1
    elseif key == KEY.SET then
        if toggle(TILES[self.sel]) then
            beep(1, 60, 1568)
        end
        self:refresh(self.sel)
    end
    return true
end

function lquick:run()
    if self.open then return end
    self.open = true
    local ok, err = pcall(function()
        self:refresh()
        menu.block(true)
        capture_start(self)
        self:draw()
        local running = true
        while running and menu.visible and not self.leaving do
            -- handle every key that arrived, then draw once
            local changed = false
            local key = table.remove(self.queue, 1)
            while key ~= nil do
                if self:handle_key(key) == false then running = false; break end
                changed = true
                key = table.remove(self.queue, 1)
            end
            if running and changed then self:draw() end
            task.yield(KEY_POLL_MS)
        end
    end)
    capture_stop(self)
    menu.block(false)
    self.open = false
    if not ok then
        display.notify_box("LUMEN Quick: " .. tostring(err), 4000)
    end
end

lquick_menu = menu.new
{
    parent = "Overlay",
    name   = "LUMEN Quick",
    help   = "Quick toggles for overlays. Arrows move, SET toggles, Q closes.",
    help2  = "Tip: star it (Prefs > Customize Menus) to put it in My Menu.",
    icon_type = ICON_TYPE.ACTION,
    select = function(this)
        if not start_task(function() lquick:run() end) then
            display.notify_box("LUMEN Quick: not enough free memory to open (turn off other scripts)", 5000)
        end
    end,
}
