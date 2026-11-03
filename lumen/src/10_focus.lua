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
-- The AF chime and Auto AF run in the shared LUMEN background task
-- (a ticker); Test Chime plays directly from the menu action.
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.


-- tone sequences: { frequency (Hz), duration (ms) }
-- long enough to be clearly audible on the 550D's small speaker
-- (louder: Audio > Speaker Volume)
local CHIMES =
{
    ["Soft"]    = { {1047, 120} },                           -- C6, one gentle note
    ["Bright"]  = { {1568, 90}, {2093, 160} },               -- G6 -> C7, rising
    ["Crystal"] = { {2093, 80}, {2637, 80}, {3136, 160} },   -- C7 -> E7 -> G7
    ["Classic"] = { {2700, 100}, {2700, 100} },              -- double beep
}
local NOTE_GAP_MS = 60   -- pause between notes, so the beep task never drops one
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

-- called from a menu action: plays at once, without task.yield
-- (msleep keeps it independent of the background task)
local function play_chime_now(name)
    local seq = CHIMES[name]
    if seq == nil then return end
    for i, tone in ipairs(seq) do
        beep(1, tone[2], tone[1])
        if i < #seq then msleep(tone[2] + NOTE_GAP_MS) end
    end
end

local function monitor_status()
    return lumen.status()
end

-- called from the background task only (it yields)
local function play_chime(name)
    local seq = CHIMES[name]
    if seq == nil then return end
    for i, tone in ipairs(seq) do
        beep(1, tone[2], tone[1])
        if i < #seq then task.yield(tone[2] + NOTE_GAP_MS) end
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
            help2   = "Louder: Audio > Speaker Volume. Viewfinder: Canon Beep.",
        },
        {
            name    = "Test Chime",
            help    = "Play the selected chime now.",
            select  = function(this)
                local name = lfocus_menu.submenu["Focus Chime"].value
                if name == "OFF" then
                    display.notify_box("Focus Chime is OFF: pick a sound first", 2000)
                    return
                end
                display.notify_box("Chime: " .. name .. " (Audio > Speaker Volume = louder)", 1500)
                play_chime_now(name)
            end,
        },
        {
            name    = "Status",
            help    = "Is the background part (AF chime, Auto AF) running?",
            icon_type = ICON_TYPE.ACTION,
            rinfo   = function(this) return monitor_status() end,
            select  = function(this)
                display.notify_box("LUMEN Focus: " .. monitor_status()
                    .. (lumen.last_error and (" - " .. lumen.last_error) or ""), 5000)
            end,
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

lfocus_cfg = lumen.config({ chime = "Bright", auto = "OFF" })
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

-- Runs on every pass of the shared LUMEN background task (see 00_core.lua):
-- chime when a user-triggered AF run ends, and Auto AF. Returns the sleep it
-- wants until the next pass (short while focusing, for a snappy chime).
local lf_was_focusing = false
local lf_next_af = nil
local lf_auto_started = nil

lumen.add_ticker(function(now)
    if lf_next_af == nil then lf_next_af = now + 3000 end
    local focusing = false


    -- Auto AF time limit
    local auto_value = lfocus_menu.submenu["Auto AF"].value
    if auto_value == "OFF" then
        lf_auto_started = nil
    elseif lf_auto_started == nil then
        lf_auto_started = now
    elseif now - lf_auto_started > AUTO_AF_LIMIT_MS then
        lfocus_menu.submenu["Auto AF"].value = "OFF"
        auto_value = "OFF"
        lf_auto_started = nil
        display.notify_box("Auto AF switched off after 10 minutes", 3000)
    end

    if lv.enabled then
        focusing = lens.autofocusing

        -- chime when a user-triggered AF run ends
        if lf_was_focusing and not focusing then
            play_chime(lfocus_menu.submenu["Focus Chime"].value)
        end

        -- Auto AF
        local interval = AUTO_AF_MS[auto_value]
        if interval ~= nil and auto_af_allowed() then
            if now >= lf_next_af then
                pcall(lens.autofocus)
                focusing = false          -- no chime for automatic runs
                lf_next_af = dryos.ms_clock + interval
            end
        else
            lf_next_af = now + (interval or 3000)
        end
    end
    lf_was_focusing = focusing
    return focusing and 20 or 60
end)
