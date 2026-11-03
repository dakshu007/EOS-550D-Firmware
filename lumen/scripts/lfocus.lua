-- LUMEN Focus
-- Focus chime and Auto AF for Live View.
--
-- Focus Chime: plays a short, pleasant tone when Canon autofocus finishes
--              in Live View (half-shutter, * or AF-ON).
--              In the viewfinder, use Canon's own beep: Canon menu > Beep > Enable.
-- Auto AF:     in Live View, re-runs autofocus every few seconds while you
--              are not recording, so a still subject stays sharp.
--              Works best with Canon AF method "Live mode" (not "Quick mode",
--              which flips the mirror every time).
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.

require("config")

-- tone sequences: { frequency (Hz), duration (ms) }
local CHIMES =
{
    ["Soft"]    = { {1047, 45} },                       -- C6, short and quiet
    ["Bright"]  = { {1568, 35}, {2093, 70} },           -- G6 -> C7, rising
    ["Crystal"] = { {2093, 30}, {2637, 30}, {3136, 60} }, -- C7 -> E7 -> G7
    ["Classic"] = { {2700, 50}, {2700, 50} },           -- double beep
}

local AUTO_AF_MS =
{
    ["Every 2 s"]  = 2000,
    ["Every 5 s"]  = 5000,
    ["Every 10 s"] = 10000,
}

local function play_chime(name)
    local seq = CHIMES[name]
    if seq == nil then return end
    for i, tone in ipairs(seq) do
        beep(1, tone[2], tone[1])
        if i < #seq then task.yield(tone[2] + 20) end
    end
end

lfocus_menu = menu.new
{
    parent  = "Focus",
    name    = "LUMEN Focus",
    help    = "Focus chime and Auto AF for Live View.",
    submenu =
    {
        {
            name    = "Focus Chime",
            choices = { "OFF", "Soft", "Bright", "Crystal", "Classic" },
            help    = "Tone played when autofocus finishes in Live View.",
            help2   = "Viewfinder: enable Canon menu > Beep instead.",
        },
        {
            name    = "Test Chime",
            help    = "Play the selected chime now.",
            select  = function(this)
                task.create(function() play_chime(lfocus_menu.submenu["Focus Chime"].value) end)
            end,
        },
        {
            name    = "Auto AF",
            choices = { "OFF", "Every 2 s", "Every 5 s", "Every 10 s" },
            help    = "Live View: refocus automatically while not recording.",
            help2   = "Use Canon AF method 'Live mode'. Not for fast subjects.",
            depends_on = DEPENDS_ON.AUTOFOCUS + DEPENDS_ON.LIVEVIEW,
        },
    },
    update = function(this)
        local c = this.submenu["Focus Chime"].value
        local a = this.submenu["Auto AF"].value
        if c == "OFF" and a == "OFF" then return "OFF" end
        if a == "OFF" then return "Chime: " .. c end
        return a
    end,
}

-- defaults: a chime on, Auto AF off
lfocus_menu.submenu["Focus Chime"].value = "Bright"
lfocus_cfg = config.create_from_menu(lfocus_menu)

local function auto_af_allowed()
    return lv.enabled and lv.running
        and lens.af
        and not movie.recording
        and not menu.visible
        and not lens.autofocusing
end

local function monitor()
    local was_focusing = false
    local next_af = dryos.ms_clock + 3000

    while true do
        local now = dryos.ms_clock
        local focusing = false

        if lv.enabled then
            focusing = lens.autofocusing

            -- chime when a user-triggered AF run ends
            if was_focusing and not focusing then
                play_chime(lfocus_menu.submenu["Focus Chime"].value)
            end

            -- Auto AF
            local interval = AUTO_AF_MS[lfocus_menu.submenu["Auto AF"].value]
            if interval ~= nil and auto_af_allowed() then
                if now >= next_af then
                    pcall(lens.autofocus)
                    focusing = false          -- no chime for automatic runs
                    next_af = dryos.ms_clock + interval
                end
            else
                next_af = now + (interval or 3000)
            end
        end

        was_focusing = focusing
        task.yield(focusing and 20 or 60)
    end
end

task.create(monitor)
