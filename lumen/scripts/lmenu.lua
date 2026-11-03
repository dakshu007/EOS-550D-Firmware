-- LUMEN Menu
-- The LUMEN menu layout: tab names in a rail on the left, settings with
-- their current values on the right, a short description at the bottom.
-- It shows and changes the real Magic Lantern settings.
--
--   Up / Down     move between settings     Left / Right   change tab
--   SET           switch ON/OFF items, or open the item in Magic Lantern
--   Q             open the selected item in the Magic Lantern menu
--   INFO (DISP)   switch to the classic Magic Lantern menu
--   Trash / MENU  close (passed straight to Magic Lantern, so it is instant)
--
-- Open it from Prefs > LUMEN Menu > Open LUMEN Menu, or set
-- "Trash button opens" to LUMEN Menu.
--
-- Safety: only items marked `toggle` are ever changed from this screen,
-- and only between OFF and ON. Everything else opens in the normal
-- Magic Lantern menu. Settings that don't exist on this camera are hidden.
-- Only one task (monitor) ever calls task.yield.
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.

require("config")

-- { ML entry name, short description, toggle? }
local TABS =
{
    { name = "Shoot", items = {
        { "LUMEN Presets",     "One-tap setups: Everyday, Portrait, Landscape, Cinema, Astro, Clean." },
        { "LUMEN Astro",       "Star-trail limit for your focal length, and 10x Star Focus." },
        { "LUMEN Timelapse",   "Intervalometer status: frames, next frame, elapsed time." },
        { "Advanced Bracket",  "HDR exposure bracketing." },
        { "Intervalometer",    "Timelapse: take a picture every N seconds." },
        { "Bulb Timer",        "Long exposures with a set duration in Bulb mode." },
        { "Motion Detect",     "Shoot automatically when something moves." },
        { "Mirror Lockup",     "Raise the mirror first to avoid vibration." },
        { "LCDsensor Remote",  "Wave a hand near the viewfinder sensor to shoot." },
        { "Audio RemoteShot",  "Clap or make a loud sound to take a picture." },
        { "Flash Tweaks",      "Flash exposure options." },
        { "Shoot Preferences", "Shooting preferences." },
    }},
    { name = "Expo", items = {
        { "White Balance",     "White balance in Kelvin, with fine-tuning." },
        { "ISO",               "Full, 1/3 or digital ISO steps." },
        { "Shutter",           "Fine shutter speed control." },
        { "Aperture",          "Fine aperture control." },
        { "Picture Style",     "Picture style and its sharpness, contrast, saturation." },
        { "Expo. Lock",        "Keep exposure constant when changing ISO or aperture." },
        { "Expo. Presets",     "Save and recall exposure settings." },
    }},
    { name = "Overlay", items = {
        { "LUMEN Quick",       "Quick toggles screen for the overlays below." },
        { "Global Draw",       "Master switch for all overlays.", toggle = true },
        { "Zebras",            "Stripes on overexposed areas.", toggle = true },
        { "Focus Peak",        "Highlights the edges that are in focus.", toggle = true },
        { "Magic Zoom",        "Zoom window to check focus.", toggle = true },
        { "Cropmarks",         "Frame guides for cinema aspect ratios.", toggle = true },
        { "Ghost image",       "Transparent overlay of a previous photo." },
        { "Spotmeter",         "Brightness of the center spot.", toggle = true },
        { "False color",       "Shows exposure levels as colors.", toggle = true },
        { "Histogram",         "Brightness distribution with clipping warnings.", toggle = true },
        { "Waveform",          "Brightness across the frame.", toggle = true },
        { "Vectorscope",       "Color saturation and hue.", toggle = true },
    }},
    { name = "Movie", items = {
        { "Movie Tweaks",      "Auto-restart, logging, time indicator, force Live View." },
        { "Bit Rate",          "H.264 bit rate. Higher can stop recording on slow cards." },
        { "FPS override",      "Custom frame rates." },
        { "HDR video",         "Alternates ISO between frames, for HDR in post." },
        { "REC key",           "Start recording with the shutter button." },
        { "Gradual Exposure",  "Smooth exposure changes while recording." },
        { "Image Fine-tuning", "Advanced image settings." },
        { "Creative Effects",  "Black-and-white Live View and other effects." },
        { "Vignetting",        "Darkens the corners as an effect." },
    }},
    { name = "Focus", items = {
        { "LUMEN Focus",       "Focus chime and Auto AF for Live View." },
        { "Trap Focus",        "Shoots when the subject comes into focus.", toggle = true },
        { "Follow Focus",      "Move focus with the arrow keys in Live View.", toggle = true },
        { "Rack Focus",        "Smooth focus pull between two points." },
        { "Focus Stacking",    "Photos at different focus distances, for macro." },
        { "Focus End Point",   "Target for rack focus." },
        { "Focus Settings",    "Focus step size and timing." },
        { "DOF Settings",      "Depth of field calculation options." },
        { "Focus Patterns",    "Custom autofocus point patterns." },
    }},
    { name = "Audio", items = {
        { "Speaker Volume",    "Volume for beeps and the LUMEN chime." },
        { "Beep, test tones",  "Enable beeps and play test tones." },
        { "Audio Meters",      "Show audio levels on screen.", toggle = true },
        { "Analog Gain",       "Microphone input level." },
        { "Digital Gain",      "Digital boost per channel." },
        { "Input source",      "Built-in, external or balanced microphone." },
        { "Wind Filter",       "Reduce wind noise." },
        { "Mic Power",         "Power for external microphones." },
        { "Headphone Mon.",    "Listen through the AV-out port." },
    }},
    { name = "Display", items = {
        { "LV brightness",     "Live View brightness. Does not affect the photo." },
        { "LV contrast",       "Live View contrast. Does not affect the photo." },
        { "LV saturation",     "Live View saturation. Grayscale helps focusing." },
        { "Clear overlays",    "Hide overlays while shooting." },
        { "Defishing",         "Preview fisheye lenses as rectilinear." },
        { "Anamorphic",        "Stretch Live View for anamorphic lenses." },
        { "Advanced settings", "More display options." },
    }},
    { name = "Prefs", items = {
        { "LUMEN Boot Logo",   "Show the LUMEN logo when the camera starts.", toggle = true },
        { "Image Review",      "QuickZoom and review options." },
        { "Arrow/SET shortcuts", "Assign arrow keys to your favorite settings." },
        { "Powersave in LiveView", "Dim or turn off the screen to save battery." },
        { "Customize Menus",   "Hide items and build My Menu." },
        { "Config options",    "Save, load and reset settings." },
        { "Warning for bad settings", "Warn about risky settings." },
    }},
    { name = "Debug", items = {
        { "Shutter Count",     "Total shutter actuations." },
        { "Internal Temp",     "Sensor temperature." },
        { "Battery level",     "Battery charge." },
        { "Free Memory",       "Available camera memory." },
        { "Show CPU usage",    "Current processor load." },
        { "Screenshot - 10s",  "Save a screenshot of the display after 10 seconds." },
    }},
}

-- layout (720 x 480)
local HEADER_H, FOOTER_Y = 44, 416
local RAIL_W = 150
local LIST_X, LIST_W = 162, 546
local ROW_H, ROWS_VISIBLE = 36, 10
local LIST_Y = HEADER_H + 4

lmenu = { tab = 1, row = 1, top = 1, open = false, pending = false, tabs = {}, built = false }

-- responsiveness: keys are checked every 20 ms, queued keys are all handled
-- before one redraw, and values are cached (only the changed item is re-read)
local KEY_POLL_MS = 20

-- which tab a setting really lives in (LUMEN items live in other tabs)
local REAL_TAB =
{
    ["LUMEN Quick"] = "Overlay", ["LUMEN Focus"] = "Focus", ["LUMEN Presets"] = "Shoot",
    ["LUMEN Astro"] = "Shoot", ["LUMEN Timelapse"] = "Shoot",
    ["LUMEN Boot Logo"] = "Prefs",
}

local function real_tab(tab_name, item_name)
    return REAL_TAB[item_name] or tab_name
end

local function get_str(tab, name)
    local ok, v = pcall(menu.get, real_tab(tab, name), name)
    if ok and v ~= nil then return tostring(v) end
    return nil
end

local function get_int(tab, name)
    local ok, v = pcall(menu.get, real_tab(tab, name), name, 0)
    if ok then return v end
    return nil
end

-- keep only tabs and items this camera has (done once; values are cached)
function lmenu:build()
    if self.built and #self.tabs > 0 then return end
    self.tabs = {}
    for _, t in ipairs(TABS) do
        local items, values = {}, {}
        for _, it in ipairs(t.items) do
            local v = get_str(t.name, it[1])
            if v ~= nil then
                table.insert(items, it)
                table.insert(values, v)
            end
        end
        if #items > 0 then table.insert(self.tabs, { name = t.name, items = items, values = values }) end
    end
    self.built = true
    if self.tab > #self.tabs then self.tab = 1 end
end

-- re-read the values of one tab (on open and on tab change)
function lmenu:refresh_tab(i)
    local tab = self.tabs[i]
    for k, it in ipairs(tab.items) do
        tab.values[k] = get_str(tab.name, it[1]) or ""
    end
end


-- Key capture while the screen is open. Trash and MENU are NOT blocked, so
-- Magic Lantern closes its menu at once as usual (and this screen with it).
-- Half/full shutter also pass. Everything else is queued for this screen.
-- The previous key handler (the Trash hook) is restored only if replaced.
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

local function clamp_rows(self)
    local items = self.tabs[self.tab].items
    if self.row < 1 then self.row = #items end
    if self.row > #items then self.row = 1 end
    if self.row < self.top then self.top = self.row end
    if self.row >= self.top + ROWS_VISIBLE then self.top = self.row - ROWS_VISIBLE + 1 end
end

function lmenu:draw()
    local tab = self.tabs[self.tab]
    display.draw(function()
        display.rect(0, 0, 720, 480, COLOR.BLACK, COLOR.BLACK)

        -- header
        display.rect(0, 0, 720, HEADER_H, COLOR.gray(5), COLOR.gray(5))
        display.print("LUMEN", 20, 10, FONT.MED, COLOR.WHITE, COLOR.gray(5))
        display.print("/ " .. tab.name, 110, 10, FONT.MED, COLOR.ORANGE, COLOR.gray(5))
        display.print("INFO: classic menu", 520, 14, FONT.SMALL, COLOR.gray(55), COLOR.gray(5))

        -- tab rail
        for i, t in ipairs(self.tabs) do
            local y = HEADER_H + 8 + (i - 1) * 34
            if y + 30 <= FOOTER_Y then
                local sel = (i == self.tab)
                local bg = sel and COLOR.gray(14) or COLOR.BLACK
                display.rect(8, y, RAIL_W - 16, 30, bg, bg)
                if sel then display.rect(8, y + 5, 3, 20, COLOR.ORANGE, COLOR.ORANGE) end
                display.print(t.name, 20, y + 4, FONT.MED, sel and COLOR.ORANGE or COLOR.gray(60), bg, RAIL_W - 32)
            end
        end
        display.rect(RAIL_W, HEADER_H, 1, FOOTER_Y - HEADER_H, COLOR.gray(10), COLOR.gray(10))

        -- settings list
        for i = self.top, math.min(#tab.items, self.top + ROWS_VISIBLE - 1) do
            local it = tab.items[i]
            local y = LIST_Y + (i - self.top) * ROW_H
            local sel = (i == self.row)
            local bg = sel and COLOR.gray(14) or COLOR.BLACK
            display.rect(LIST_X, y, LIST_W, ROW_H - 2, bg, bg)
            if sel then display.rect(LIST_X, y + 7, 3, ROW_H - 16, COLOR.ORANGE, COLOR.ORANGE) end
            display.print(it[1], LIST_X + 14, y + 6, FONT.MED, COLOR.WHITE, bg, 300)
            local v = tab.values[i] or ""
            local fg = sel and COLOR.ORANGE or ((v == "OFF") and COLOR.gray(50) or COLOR.WHITE)
            local w = math.min(FONT.MED:width(v), 220)
            display.print(v, LIST_X + LIST_W - 12 - w, y + 6, FONT.MED, fg, bg, 220)
        end
        if #tab.items > ROWS_VISIBLE then
            local h = (FOOTER_Y - LIST_Y - 8) * ROWS_VISIBLE // #tab.items
            local y = LIST_Y + (FOOTER_Y - LIST_Y - 8 - h) * (self.top - 1) // math.max(1, #tab.items - ROWS_VISIBLE)
            display.rect(714, y, 3, h, COLOR.ORANGE, COLOR.ORANGE)
        end

        -- footer: description and key hints
        local it = tab.items[self.row]
        display.rect(0, FOOTER_Y, 720, 480 - FOOTER_Y, COLOR.gray(5), COLOR.gray(5))
        display.print(it[2], 20, FOOTER_Y + 8, FONT.SMALL, COLOR.gray(70), COLOR.gray(5), 680)
        local hint = it.toggle and "SET: on/off    Q: details    Trash: close"
                                or "SET / Q: open in Magic Lantern    Trash: close"
        display.print(hint, 20, FOOTER_Y + 34, FONT.SMALL, COLOR.gray(55), COLOR.gray(5), 680)
    end)
end

-- open the selected item in the normal Magic Lantern menu; ends this screen
function lmenu:open_in_ml()
    local tab = self.tabs[self.tab]
    local it = tab.items[self.row]
    pcall(menu.select, real_tab(tab.name, it[1]), it[1])
    return false
end

-- switching OFF remembers the mode; switching ON restores it
-- (Global Draw: 3 = "ON, all modes", the Magic Lantern default)
local ON_DEFAULT = { ["Global Draw"] = 3 }
lmenu.last_on = {}

function lmenu:toggle()
    local tab = self.tabs[self.tab]
    local it = tab.items[self.row]
    local v = get_int(tab.name, it[1])
    if v == nil then return end
    local new
    if v ~= 0 then
        self.last_on[it[1]] = v
        new = 0
    else
        new = self.last_on[it[1]] or ON_DEFAULT[it[1]] or 1
    end
    pcall(menu.set, real_tab(tab.name, it[1]), it[1], new)
    tab.values[self.row] = get_str(tab.name, it[1]) or ""
    beep(1, 50, 1568)
end

-- returns false to leave the LUMEN Menu
function lmenu:handle_key(key)
    local tab = self.tabs[self.tab]
    if key == KEY.INFO then
        return false                                  -- classic ML menu stays open
    elseif key == KEY.UP or key == KEY.WHEEL_UP then
        self.row = self.row - 1
    elseif key == KEY.DOWN or key == KEY.WHEEL_DOWN then
        self.row = self.row + 1
    elseif key == KEY.LEFT or key == KEY.WHEEL_LEFT then
        self.tab = (self.tab - 2) % #self.tabs + 1; self.row, self.top = 1, 1
        self:refresh_tab(self.tab)
    elseif key == KEY.RIGHT or key == KEY.WHEEL_RIGHT then
        self.tab = self.tab % #self.tabs + 1; self.row, self.top = 1, 1
        self:refresh_tab(self.tab)
    elseif key == KEY.Q then
        return self:open_in_ml()
    elseif key == KEY.SET then
        if tab.items[self.row].toggle then
            self:toggle()
        else
            return self:open_in_ml()
        end
    end
    clamp_rows(self)
    return true
end

-- the LUMEN Menu screen; runs inside the monitor task (it yields)
function lmenu:run()
    if self.open then return end
    self.open = true
    local ok, err = pcall(function()
        self:build()
        if #self.tabs == 0 then error("no settings found") end
        self:refresh_tab(self.tab)
        clamp_rows(self)
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
        display.notify_box("LUMEN Menu: " .. tostring(err), 4000)
    end
end

-- Prefs > LUMEN Menu
local TRASH_CHOICES = { "Magic Lantern menu", "LUMEN Menu" }

lmenu_menu = menu.new
{
    parent  = "Prefs",
    name    = "LUMEN Menu",
    help    = "The LUMEN menu layout: tab rail, settings and descriptions.",
    submenu =
    {
        {
            name    = "Open LUMEN Menu",
            help    = "Open the LUMEN Menu now.",
            icon_type = ICON_TYPE.ACTION,
            select  = function(this) lmenu.pending = true end,
        },
        {
            name    = "Trash button opens",
            choices = TRASH_CHOICES,
            help    = "What the Trash button opens. INFO in LUMEN Menu = classic menu.",
        },
    },
    update = function(this)
        return this.submenu["Trash button opens"].value == "LUMEN Menu" and "Trash" or "OFF"
    end,
}

lmenu_cfg = config.create({ trash = "Magic Lantern menu" })
lmenu_menu.submenu["Trash button opens"].value =
    (lmenu_cfg.data.trash == "LUMEN Menu") and "LUMEN Menu" or "Magic Lantern menu"
lmenu_cfg.saving = function(self)
    self.data = { trash = lmenu_menu.submenu["Trash button opens"].value }
end

-- Trash: let Magic Lantern open its menu as usual, then show LUMEN on top
event.keypress = function(key)
    if key == KEY.TRASH and not menu.visible and not lmenu.open
       and lmenu_menu.submenu["Trash button opens"].value == "LUMEN Menu" then
        lmenu.pending = true
    end
    -- never block the key here
end

local function monitor()
    while true do
        if lmenu.pending then
            lmenu.pending = false
            -- wait (up to 2 s) for the Magic Lantern menu to be on screen
            local waited = 0
            while not menu.visible and waited < 2000 do
                task.yield(50); waited = waited + 50
            end
            if menu.visible then lmenu:run() end
        end
        task.yield(100)
    end
end

task.create(monitor, 0x1c, 0x8000)   -- 32 KB stack is plenty for this loop
