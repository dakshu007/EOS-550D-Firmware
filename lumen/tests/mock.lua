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
sleeping = {}
task = {
    create = function(fn) table.insert(tasks, coroutine.create(fn)) end,
    -- like ML (lua_task.c): task.yield fails if another task of the same
    -- script is already sleeping inside task.yield
    yield = function(ms)
        local me = coroutine.running()
        for co in pairs(sleeping) do
            if co ~= me and coroutine.status(co) == "suspended" then
                error("FIXME: cannot use task.yield() from two tasks")
            end
        end
        clock = clock + (ms or 0)
        sleeping[me] = true
        coroutine.yield()
        sleeping[me] = nil
    end,
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
ICON_TYPE = { ACTION = 5 }
KEY = { SET = 1, UP = 2, DOWN = 3, LEFT = 4, RIGHT = 5, Q = 6, MENU = 7, TRASH = 8,
        WHEEL_UP = 9, WHEEL_DOWN = 10, WHEEL_LEFT = 11, WHEEL_RIGHT = 12, INFO = 13 }
-- fonts: like ML, each has a height and a width(text) method
local function font(h, cw) return { height = h, width = function(self, t) return #tostring(t) * cw end } end
FONT = { MED = font(23, 11), LARGE = font(32, 16), SMALL = font(12, 8) }
event = {}
MODE = { M = 3, MOVIE = 20, P = 0 }
UNIT = { TIME = 1 }
COLOR = { BLACK = 2, WHITE = 1, ORANGE = 19, gray = function(p) return 38 + p * 41 // 100 end }

menus_created = {}
menu_set_calls = {}
menu_values = {}          -- "Menu/Entry" -> int value (missing = 0)
menu_blocked = false
menu = {
    visible = false,
    close = function() end,
    block = function(b) menu_blocked = b end,
    set = function(m, e, v)
        table.insert(menu_set_calls, m .. "/" .. e .. "=" .. tostring(v))
        if e == "Vectorscope" then return nil end -- pretend one entry is missing
        menu_values[m .. "/" .. e] = v
        return true
    end,
    get = function(m, e, as_int)
        local v = menu_values[m .. "/" .. e] or 0
        if as_int ~= nil then return v end
        return v == 0 and "OFF" or "ON"
    end,
    new = function(def)
        local entry = { name = def.name, value = def.value, update = def.update, select = def.select,
                        parent = def.parent, submenu = {} }
        table.insert(menus_created, entry)
        for _, s in ipairs(def.submenu or {}) do
            local se = { name = s.name, select = s.select, info = s.info, rinfo = s.rinfo, choices = s.choices }
            se.value = s.value or (s.choices and s.choices[1]) or 0
            entry.submenu[s.name] = se
        end
        return entry
    end,
}

-- saved config the next script load will see (nil = no file yet)
mock_saved_cfg = nil
config = {
    create = function(default)
        local cfg = { data = mock_saved_cfg or default }
        mock_saved_cfg = nil
        return cfg
    end,
    create_from_menu = function(m) error("LUMEN scripts must not use create_from_menu") end,
}

-- Canon properties: scripts attach handlers, tests fire them
property = setmetatable({}, { __index = function(t, k)
    local o = {}
    rawset(t, k, o)
    return o
end })
package.loaded["config"] = config

lens = { af = true, autofocusing = false, focal_length = 18, autofocus_calls = 0 }
lens.autofocus = function() lens.autofocus_calls = lens.autofocus_calls + 1; return true end

-- lv.zoom goes through accessors so tests can make Canon refuse the zoom
lv = { enabled = true, running = true, infos = {}, zoom_refused = false, _zoom = 1 }
setmetatable(lv, {
    __index = function(t, k) if k == "zoom" then return rawget(t, "_zoom") end end,
    __newindex = function(t, k, v)
        if k == "zoom" then
            if not rawget(t, "zoom_refused") then rawset(t, "_zoom", v) end
        else
            rawset(t, k, v)
        end
    end,
})
lv.info = function(def) table.insert(lv.infos, def) end

movie = { recording = false }

camera = {
    mode = MODE.M,
    iso = { value = 400 },
    shutter = { value = 1/100 },
    aperture = { value = 5.6, min = { value = 3.5 } },
}

draw_calls = 0
display = {
    notify_box = function(msg) L("notify: %s", msg) end,
    draw = function(fn) draw_calls = draw_calls + 1; fn() end,
    rect = function(x, y, w, h, stroke, fill)
        if x < 0 or y < 0 or x + w > 720 or y + h > 480 then error("rect out of screen") end
    end,
    print = function(text, x, y, font, fg, bg, max_w)
        if x < 0 or y < 0 or x > 720 or y > 480 then error("print out of screen") end
    end,
}

-- intervalometer
interval = { time = 10, count = 0, running = false, stopped = 0 }
interval.stop = function() interval.running = false; interval.stopped = interval.stopped + 1 end

-- keys library (scripts/lib/keys.lua): tests push keys into key_queue
key_queue = {}
keys = {
    running = false,
    start = function(self) self.running = true end,
    stop = function(self) self.running = false end,
    getkey = function(self) return table.remove(key_queue, 1) end,
}
package.loaded["keys"] = keys
