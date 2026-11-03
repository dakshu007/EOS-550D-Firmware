-- LUMEN Focus
-- Focus chime and Auto AF for Live View.
--
-- Focus Chime: plays a short, pleasant tone when Canon autofocus finishes
--              in Live View (half-shutter, * or AF-ON).
--              In the viewfinder, use Canon's own beep: Canon menu > Beep > Enable.
-- Auto AF:     in Live View, re-runs autofocus every few seconds while you
--              are not recording, so a still subject stays sharp.
--              Safety: only runs when the Canon Live View AF method is known
--              to be Live mode or Face detection (never Quick mode, which
--              flips the mirror), and switches itself off after 10 minutes.
--
-- Only one task (monitor) ever calls task.yield: ML does not allow
-- task.yield from two tasks of the same script at once.
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.

require("config")

-- tone sequences: { frequency (Hz), duration (ms) }
local CHIMES =
{
    ["Soft"]    = { {1047, 45} },                         -- C6, short and quiet
    ["Bright"]  = { {1568, 35}, {2093, 70} },             -- G6 -> C7, rising
    ["Crystal"] = { {2093, 30}, {2637, 30}, {3136, 60} }, -- C7 -> E7 -> G7
    ["Classic"] = { {2700, 50}, {2700, 50} },             -- double beep
}
local CHIME_CHOICES = { "OFF", "Soft", "Bright", "Crystal", "Classic" }

local AUTO_AF_MS =
{
    ["Every 2 s"]  = 2000,
    ["Every 5 s"]  = 5000,
    ["Every 10 s"] = 10000,
}
local AUTO_CHOICES = { "OFF", "Every 2 s", "Every 5 s", "Every 10 s" }
local AUTO_AF_LIMIT_MS = 10 * 60 * 1000

-- Canon Live View AF method: 0 = Quick, 1 = Live, 2 = Face detection, nil = unknown
lfocus_af_system = nil
lfocus_test_pending = false

-- called from the monitor task only (it yields)
local function play_chime(name)
    local seq = CHIMES[name]
    if seq == nil then return end
    for i, tone in ipairs(seq) do
        beep(1, tone[2], tone[1])
        if i < #seq then task.yield(tone[2] + 20) end
    end
end

local function af_system_ok()
    return lfocus_af_system == 1 or lfocus_af_system == 2
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
            choices = CHIME_CHOICES,
            help    = "Tone played when autofocus finishes in Live View.",
            help2   = "Viewfinder: enable Canon menu > Beep instead.",
        },
        {
            name    = "Test Chime",
            help    = "Play the selected chime now.",
            select  = function(this) lfocus_test_pending = true end,
        },
        {
            name    = "Auto AF",
            choices = AUTO_CHOICES,
            help    = "Live View: refocus automatically while not recording.",
            help2   = "Stops by itself after 10 minutes. Not for fast subjects.",
            depends_on = DEPENDS_ON.AUTOFOCUS + DEPENDS_ON.LIVEVIEW,
            warning = function(this)
                if this.value ~= "OFF" and not af_system_ok() then
                    return "Set Canon Live View AF mode to Live mode or Face detection."
                end
            end,
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

-- settings: only the two choice items are saved; unknown or missing
-- values fall back to defaults, so future versions can add items safely
local function valid(choices, v)
    for _, c in ipairs(choices) do if c == v then return true end end
    return false
end

lfocus_cfg = config.create({ chime = "Bright", auto = "OFF" })
lfocus_menu.submenu["Focus Chime"].value =
    valid(CHIME_CHOICES, lfocus_cfg.data.chime) and lfocus_cfg.data.chime or "Bright"
lfocus_menu.submenu["Auto AF"].value = "OFF"   -- Auto AF always starts OFF after boot
lfocus_cfg.saving = function(self)
    self.data = { chime = lfocus_menu.submenu["Focus Chime"].value, auto = "OFF" }
end

-- Canon reports the Live View AF method here (initially and on every change)
function property.PROP_LIVE_VIEW_AF_SYSTEM:handler(value)
    lfocus_af_system = value
end

local function auto_af_allowed()
    return lv.enabled and lv.running
        and lens.af
        and af_system_ok()
        and not movie.recording
        and not menu.visible
        and not lens.autofocusing
end

local function monitor()
    local was_focusing = false
    local next_af = dryos.ms_clock + 3000
    local auto_started = nil

    while true do
        local now = dryos.ms_clock
        local focusing = false

        if lfocus_test_pending then
            lfocus_test_pending = false
            play_chime(lfocus_menu.submenu["Focus Chime"].value)
        end

        -- Auto AF time limit
        local auto_value = lfocus_menu.submenu["Auto AF"].value
        if auto_value == "OFF" then
            auto_started = nil
        elseif auto_started == nil then
            auto_started = now
        elseif now - auto_started > AUTO_AF_LIMIT_MS then
            lfocus_menu.submenu["Auto AF"].value = "OFF"
            auto_value = "OFF"
            auto_started = nil
            display.notify_box("Auto AF switched off after 10 minutes", 3000)
        end

        if lv.enabled then
            focusing = lens.autofocusing

            -- chime when a user-triggered AF run ends
            if was_focusing and not focusing then
                play_chime(lfocus_menu.submenu["Focus Chime"].value)
            end

            -- Auto AF
            local interval = AUTO_AF_MS[auto_value]
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
