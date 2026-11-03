-- Minimal mock of the Magic Lantern Lua API, enough to load and exercise
-- the LUMEN scripts on a PC. Not a camera simulator.
log = {}
local function L(...) table.insert(log, string.format(...)) end

clock = 0
dryos = { config_dir = { path = "ML/SETTINGS/" } }
setmetatable(dryos, { __index = function(t, k) if k == "ms_clock" then return clock end end })

beep = function(times, dur, freq) L("beep %d %d %d", times, dur or 0, freq or 0) end
msleep = function(ms) clock = clock + ms end

tasks = {}
task = {
    create = function(fn) table.insert(tasks, coroutine.create(fn)) end,
    yield = function(ms) clock = clock + (ms or 0); coroutine.yield() end,
}
function run_tasks(steps)
    for _ = 1, steps do
        for i = #tasks, 1, -1 do
            local co = tasks[i]
            if coroutine.status(co) == "dead" then table.remove(tasks, i)
            else
                local ok, err = coroutine.resume(co)
                if not ok then error("task error: " .. tostring(err)) end
            end
        end
    end
end

DEPENDS_ON = { AUTOFOCUS = 1, LIVEVIEW = 2, MOVIE_MODE = 4 }
MODE = { M = 3, MOVIE = 20, P = 0 }
UNIT = { TIME = 1 }
COLOR = {}

menu_set_calls = {}
menu = {
    visible = false,
    close = function() end,
    set = function(m, e, v)
        table.insert(menu_set_calls, m .. "/" .. e .. "=" .. tostring(v))
        if e == "Vectorscope" then return nil end -- pretend one entry is missing
        return true
    end,
    new = function(def)
        local entry = { name = def.name, value = def.value, update = def.update, submenu = {} }
        for _, s in ipairs(def.submenu or {}) do
            local se = { name = s.name, select = s.select, info = s.info, rinfo = s.rinfo, choices = s.choices }
            se.value = s.value or (s.choices and s.choices[1]) or 0
            entry.submenu[s.name] = se
        end
        return entry
    end,
}

config = {
    create_from_menu = function(m) return { menu = m } end,
}
package.loaded["config"] = config

lens = { af = true, autofocusing = false, focal_length = 18, autofocus_calls = 0 }
lens.autofocus = function() lens.autofocus_calls = lens.autofocus_calls + 1; return true end

lv = { enabled = true, running = true, zoom = 1, infos = {} }
lv.info = function(def) table.insert(lv.infos, def) end

movie = { recording = false }

camera = {
    mode = MODE.M,
    iso = { value = 400 },
    shutter = { value = 1/100 },
    aperture = { value = 5.6, min = { value = 3.5 } },
}

display = { notify_box = function(msg) L("notify: %s", msg) end }
