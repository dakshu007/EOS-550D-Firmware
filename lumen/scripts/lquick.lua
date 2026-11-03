-- LUMEN Quick
-- Quick toggles: one screen with the overlays you switch most often.
--
-- Open it from Overlay > LUMEN Quick (tip: star it so it appears in My Menu).
-- Arrows move, SET toggles, Q / MENU / Trash closes.
--
-- Only one task (the screen loop) ever calls task.yield: ML does not allow
-- task.yield from two tasks of the same script at once.
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.

require("keys")

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

lquick = { sel = 1, open = false }

local function tile_state(t)
    local ok, v = pcall(menu.get, t[2], t[3], 0)
    if not ok or v == nil then return nil end
    return v ~= 0
end

local function tile_value(t)
    local ok, v = pcall(menu.get, t[2], t[3])
    if not ok or v == nil then return "n/a" end
    return tostring(v)
end

local function toggle(t)
    local on = tile_state(t)
    if on == nil then return false end
    local ok, result = pcall(menu.set, t[2], t[3], on and 0 or 1)
    return ok and result ~= nil
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
            local on = tile_state(t)
            local bg = on and COLOR.gray(20) or COLOR.gray(8)
            local border = COLOR.gray(25)
            if i == self.sel then border = COLOR.ORANGE end

            display.rect(x, y, TILE_W, TILE_H, border, bg)
            if i == self.sel then
                display.rect(x + 1, y + 1, TILE_W - 2, TILE_H - 2, COLOR.ORANGE)
            end
            display.print(t[1], x + 14, y + 16, FONT.MED, COLOR.WHITE, bg, TILE_W - 28)
            local fg = on and COLOR.ORANGE or COLOR.gray(55)
            local text = (on == nil) and "n/a" or (on and tile_value(t) or "OFF")
            display.print(text, x + 14, y + TILE_H - 44, FONT.MED, fg, bg, TILE_W - 28)
        end

        display.print("Arrows: move    SET: toggle    Q / MENU: close",
            MARGIN, 420, FONT.MED, COLOR.gray(60), COLOR.BLACK)
    end)
end

function lquick:handle_key(key)
    if key == KEY.Q or key == KEY.MENU or key == KEY.TRASH then
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
    end
    return true
end

function lquick:run()
    if self.open then return end
    self.open = true
    local ok, err = pcall(function()
        menu.block(true)
        keys:start()
        self:draw()
        while menu.visible do
            local key = keys:getkey()
            if key ~= nil then
                if self:handle_key(key) == false then break end
                self:draw()
            end
            task.yield(80)
        end
    end)
    keys:stop()
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
        task.create(function() lquick:run() end)
    end,
}
