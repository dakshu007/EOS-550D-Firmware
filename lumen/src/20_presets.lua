-- LUMEN Presets
-- One-tap shooting setups: overlays, movie helpers and (in M mode) exposure.
--
-- Exposure values (ISO, shutter, aperture) are only changed when the mode
-- dial is on M (Cinema: also movie mode). In other modes, only the overlays
-- are changed. Presets never touch Canon custom functions (mirror lockup,
-- bracketing) and never start shooting (the intervalometer is never armed).
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.


-- ML menu settings per preset: { menu, entry, value }
local OVERLAYS_ON =
{
    { "Overlay", "Global Draw", 3 },   -- 3 = "ON, all modes"
    { "Overlay", "Zebras",      1 },
    { "Overlay", "Focus Peak",  1 },
    { "Overlay", "Spotmeter",   1 },
    { "Overlay", "Histogram",   1 },
}

local PRESETS =
{
    ["Everyday"] =
    {
        help = "Zebras, peaking, histogram, spotmeter. Exposure untouched.",
        menu =
        {
            { "Overlay", "Global Draw", 3 },   -- 3 = "ON, all modes"
            { "Overlay", "Zebras",      1 },
            { "Overlay", "Focus Peak",  1 },
            { "Overlay", "Magic Zoom",  0 },
            { "Overlay", "Spotmeter",   1 },
            { "Overlay", "Histogram",   1 },
            { "Overlay", "False color", 0 },
            { "Overlay", "Waveform",    0 },
            { "Overlay", "Vectorscope", 0 },
        },
    },
    ["Portrait"] =
    {
        help = "M mode: widest aperture, ISO 200, 1/200 s. Peaking on.",
        menu = OVERLAYS_ON,
        iso = 200, shutter = 1/200, aperture = "widest",
    },
    ["Landscape"] =
    {
        help = "M mode: f/8, ISO 100. Zebras and histogram for highlights.",
        menu = OVERLAYS_ON,
        iso = 100, aperture = 8.0,
    },
    ["Cinema"] =
    {
        help = "Movie: 1/50 s in M, zebras, peaking, auto-restart, logging.",
        menu =
        {
            { "Overlay", "Global Draw", 3 },   -- 3 = "ON, all modes"
            { "Overlay", "Zebras",      1 },
            { "Overlay", "Focus Peak",  1 },
            { "Overlay", "Magic Zoom",  0 },
            { "Movie Tweaks", "Movie Restart", 1 },
            { "Movie Tweaks", "Movie Logging", 1 },
        },
        shutter = 1/50,
        modes = { MODE.M, MODE.MOVIE },
    },
    ["Astro"] =
    {
        help = "M mode: ISO 1600, 20 s, widest aperture. Magic Zoom for focus.",
        menu =
        {
            { "Overlay", "Global Draw", 3 },   -- 3 = "ON, all modes"
            { "Overlay", "Zebras",      0 },
            { "Overlay", "Focus Peak",  0 },
            { "Overlay", "Magic Zoom",  1 },
            { "Overlay", "Spotmeter",   0 },
        },
        iso = 1600, shutter = 20, aperture = "widest",
    },
    ["Clean"] =
    {
        help = "Hide all overlays for a clean Live View.",
        menu =
        {
            { "Overlay", "Global Draw", 0 },
        },
    },
}

local ORDER = { "Everyday", "Portrait", "Landscape", "Cinema", "Astro", "Clean" }


local function set_exposure(p)
    if p.iso == nil and p.shutter == nil and p.aperture == nil then
        return 0, 0, ""
    end
    local allowed = false
    for _, m in ipairs(p.modes or { MODE.M }) do
        if camera.mode == m then allowed = true end
    end
    if not allowed then
        return 0, 0, " (exposure needs M mode)"
    end
    local ok, total = 0, 0
    local function try(fn)
        total = total + 1
        if pcall(fn) then ok = ok + 1 end
    end
    if p.iso ~= nil then
        try(function() camera.iso.value = p.iso end)
    end
    if p.shutter ~= nil then
        try(function() camera.shutter.value = p.shutter end)
    end
    if p.aperture == "widest" then
        try(function() camera.aperture.value = camera.aperture.min.value end)
    elseif p.aperture ~= nil then
        try(function() camera.aperture.value = p.aperture end)
    end
    return ok, total, ""
end

local function apply(name)
    local p = PRESETS[name]
    if p == nil then return end

    local ok, total = 0, 0
    for _, s in ipairs(p.menu) do
        total = total + 1
        local success, result = pcall(menu.set, s[1], s[2], s[3])
        if success and result then ok = ok + 1 end
    end

    local eok, etotal, note = set_exposure(p)
    ok, total = ok + eok, total + etotal

    beep(1, 40, 1568)
    display.notify_box(string.format("%s: %d of %d applied%s", name, ok, total, note), 3000)
end

lpreset_menu = menu.new
{
    parent  = "Shoot",
    name    = "LUMEN Presets",
    help    = "One-tap setups. Pick a preset, then Apply.",
    submenu =
    {
        {
            name    = "Preset",
            choices = ORDER,
            help    = "Everyday, Portrait, Landscape, Cinema, Astro, Clean.",
        },
        {
            name    = "Apply",
            help    = "Apply the selected preset now.",
            select  = function(this)
                local name = lpreset_menu.submenu["Preset"].value
                if not lumen.run(function() apply(name) end) then
                    display.notify_box("Presets: not enough free memory (turn off other scripts)", 5000)
                end
            end,
            info    = function(this)
                local p = PRESETS[lpreset_menu.submenu["Preset"].value]
                if p then return p.help end
            end,
        },
    },
    update = function(this)
        return this.submenu["Preset"].value
    end,
}

-- settings: only the chosen preset is saved; a missing or unknown value
-- falls back to Everyday, so future versions can add items safely
lpreset_cfg = lumen.config({ preset = "Everyday" })
local saved = lpreset_cfg.data.preset
lpreset_menu.submenu["Preset"].value = PRESETS[saved] and saved or "Everyday"
lpreset_cfg.saving = function(self)
    self.data = { preset = lpreset_menu.submenu["Preset"].value }
end
