-- LUMEN Timelapse
-- Status for Magic Lantern's intervalometer: frames taken, countdown to
-- the next frame and elapsed time, in the Live View info bar and in the
-- Shoot menu. Optional soft tick on every frame.
--
-- LUMEN never starts the intervalometer by itself: set it up in
-- Shoot > Intervalometer as usual. "Stop now" stops it.
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.

ltlapse = { started = nil, last_shot = nil }

local function fmt_time(s)
    s = math.max(0, math.floor(s))
    local h, m = s // 3600, (s % 3600) // 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s % 60) end
    return string.format("%d:%02d", m, s % 60)
end

-- returns frames, seconds to next frame (or nil), elapsed seconds; nil if not running
function ltlapse.status()
    if not interval.running then
        ltlapse.started, ltlapse.last_shot = nil, nil
        return nil
    end
    local now = dryos.ms_clock
    if ltlapse.started == nil then ltlapse.started = now end
    local next_in = nil
    if ltlapse.last_shot ~= nil and interval.time > 0 then
        next_in = math.max(0, interval.time - (now - ltlapse.last_shot) / 1000)
    end
    return interval.count, next_in, (now - ltlapse.started) / 1000
end

function ltlapse.summary()
    local frames, next_in, elapsed = ltlapse.status()
    if frames == nil then return nil end
    if next_in ~= nil then
        return string.format("TL %d  next %ds  %s", frames, math.ceil(next_in), fmt_time(elapsed))
    end
    return string.format("TL %d  %s", frames, fmt_time(elapsed))
end

ltlapse_menu = menu.new
{
    parent  = "Shoot",
    name    = "LUMEN Timelapse",
    help    = "Intervalometer status: frames, next frame, elapsed time.",
    help2   = "Set up the timelapse in Shoot > Intervalometer.",
    submenu =
    {
        {
            name    = "Status",
            help    = "Frames taken, countdown to the next frame, elapsed time.",
            icon_type = ICON_TYPE.ACTION,
            rinfo   = function(this) return ltlapse.summary() or "not running" end,
        },
        {
            name    = "Frame Tick",
            choices = { "OFF", "ON" },
            help    = "A short, soft tick after every timelapse frame.",
        },
        {
            name    = "Stop now",
            help    = "Stop the running intervalometer.",
            icon_type = ICON_TYPE.ACTION,
            select  = function(this)
                if interval.running then
                    interval.stop()
                    display.notify_box("Timelapse stopped", 2000)
                end
            end,
        },
    },
    update = function(this)
        return ltlapse.summary() or "OFF"
    end,
}

-- called by ML after every intervalometer frame
event.intervalometer = function(count)
    ltlapse.last_shot = dryos.ms_clock
    if ltlapse.started == nil then ltlapse.started = ltlapse.last_shot end
    if ltlapse_menu.submenu["Frame Tick"].value == "ON" then
        beep(1, 40, 1047)
    end
    -- returning nothing lets the intervalometer continue
end

lv.info
{
    name     = "LUMEN Timelapse",
    value    = "",
    priority = 60,
    update   = function(this)
        this.value = ltlapse.summary() or ""
    end,
}
