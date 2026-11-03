-- LUMEN
-- Custom interface for the Canon EOS 550D, built on Magic Lantern.
--
-- All LUMEN features run in this ONE script, so they share one Lua state.
-- (Six separate scripts used up the Lua memory pool on the 550D:
-- "PANIC: not enough memory".)
--
-- One background task (the monitor) does all work that waits or repeats:
--   * jobs:    one-off work queued by menu actions (open LUMEN Menu or
--              Quick, apply a preset, Star Focus). They may call task.yield.
--   * tickers: small functions called every loop (AF chime, Auto AF).
-- Only the monitor ever calls task.yield (ML allows one yielding task per
-- script). Menu actions themselves never yield.
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.

require("config")

-- collect garbage early: the 550D has very little memory to spare
collectgarbage("setpause", 100)
collectgarbage("setstepmul", 200)

lumen =
{
    jobs = {},           -- functions to run once in the monitor
    tickers = {},        -- functions(now) called every loop; may return a sleep in ms
    heartbeat = nil,     -- ms clock of the monitor's last loop (nil = never ran)
    start_failed = false,
    last_error = nil,
}

-- queue work for the monitor; false if the monitor couldn't start
function lumen.run(fn)
    if lumen.start_failed then return false end
    table.insert(lumen.jobs, fn)
    return true
end

function lumen.add_ticker(fn)
    table.insert(lumen.tickers, fn)
end

function lumen.status()
    if lumen.start_failed then return "not started (memory)" end
    if lumen.heartbeat == nil then return "starting" end
    if dryos.ms_clock - lumen.heartbeat > 3000 then return "stopped" end
    if lumen.last_error then return "running (had an error)" end
    return "running"
end

-- Buttons. Magic Lantern keeps ONE key handler per script, and a script
-- can't read it back (event.keypress always reads as nil), so LUMEN sets
-- it once here and never changes it again:
--   * while a full-screen LUMEN page is open (capture_start), keys go to
--     that page. Trash and MENU are NOT blocked, so Magic Lantern closes its
--     menu at once as usual (and the page with it). Half/full shutter also
--     pass. Everything else is queued for the page.
--   * otherwise the key hooks run (e.g. the Trash shortcut) and the key is
--     always passed on.
lumen.key_hooks = {}     -- functions(key), called when no page is open
lumen.capturer = nil     -- the page that has the buttons, or nil

function lumen.add_key_hook(fn)
    table.insert(lumen.key_hooks, fn)
end

event.keypress = function(key)
    local page = lumen.capturer
    if page ~= nil then
        if key == 0 then return true end
        if key == KEY.TRASH or key == KEY.MENU then
            page.leaving = true
            return true
        end
        if key <= KEY.UNPRESS_FULLSHUTTER then return true end
        table.insert(page.queue, key)
        return false
    end
    for _, hook in ipairs(lumen.key_hooks) do
        local ok, err = pcall(hook, key)
        if not ok then lumen.last_error = tostring(err) end
    end
    return true
end

function lumen.capture_start(self)
    self.queue, self.leaving = {}, false
    lumen.capturer = self
    self.capturing = true
end

function lumen.capture_stop(self)
    if lumen.capturer == self then lumen.capturer = nil end
    self.capturing = false
    self.queue = {}
end

-- One settings file for all of LUMEN (ML/SETTINGS/LUMEN.CFG).
-- Each feature asks for its own keys with defaults; missing or old values
-- fall back to those defaults.
lumen_cfg = config.create({})
lumen.cfg_parts = {}

function lumen.config(defaults)
    local saved = (type(lumen_cfg.data) == "table") and lumen_cfg.data or {}
    local part = { data = {} }
    for k, v in pairs(defaults) do
        if saved[k] ~= nil then part.data[k] = saved[k] else part.data[k] = v end
    end
    table.insert(lumen.cfg_parts, part)
    return part
end

lumen_cfg.saving = function(self)
    local all = {}
    for _, part in ipairs(lumen.cfg_parts) do
        if part.saving then pcall(part.saving, part) end
        for k, v in pairs(part.data) do all[k] = v end
    end
    self.data = all
end
