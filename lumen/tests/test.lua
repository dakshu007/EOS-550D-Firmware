-- Exercise LUMEN scripts against the mock API.
-- Run: lua5.3 lumen/tests/test.lua lumen/scripts lumen/tests
local root = arg[1]
dofile(arg[2] .. "/mock.lua")

local function check(cond, msg)
    if not cond then error("FAIL: " .. msg) end
    print("ok   " .. msg)
end

local function count_beeps()
    local n = 0
    for _, l in ipairs(log) do if l:match("^beep") then n = n + 1 end end
    return n
end

local function ticks(n) for _ = 1, n do run_tasks(1) end end

----------------------------------------------------------------- lfocus
dofile(root .. "/lfocus.lua")
local F = lfocus_menu.submenu
check(F["Focus Chime"].value == "Bright", "default chime is Bright")
check(F["Auto AF"].value == "OFF", "Auto AF starts OFF")
check(lfocus_menu.update(lfocus_menu) == "Chime: Bright", "menu summary shows chime")

-- user half-press: focusing true for a while, then false -> chime
ticks(2)
lens.autofocusing = true;  ticks(3)
log = {}
lens.autofocusing = false; ticks(3)
check(count_beeps() == 2, "Bright chime plays 2 tones after AF ends")

log = {}; ticks(5)
check(#log == 0, "no chime while idle")

-- Test Chime runs inside the monitor task (no second yielding task)
for _, name in ipairs({ "Soft", "Bright", "Crystal", "Classic" }) do
    F["Focus Chime"].value = name
    log = {}
    F["Test Chime"].select()
    ticks(6)
    local want = ({ Soft = 1, Bright = 2, Crystal = 3, Classic = 2 })[name]
    check(count_beeps() == want, "Test Chime plays " .. name .. " (" .. want .. " tones)")
end
check(#tasks == 1, "Test Chime does not start extra tasks")

-- Test Chime plays immediately, without needing the background task
local saved_tasks = tasks
tasks = {}                                    -- pretend the background task never ran
F["Focus Chime"].value = "Bright"; log = {}
F["Test Chime"].select()
check(count_beeps() == 2, "Test Chime plays at once, even with no background task")
local saw_msg = false
for _, l in ipairs(log) do if l:match("notify: Chime: Bright") then saw_msg = true end end
check(saw_msg, "Test Chime shows a message so you know the press registered")
F["Focus Chime"].value = "OFF"; log = {}
F["Test Chime"].select()
check(count_beeps() == 0 and log[#log]:match("Focus Chime is OFF"), "Test Chime explains when the chime is OFF")
tasks = saved_tasks

-- Status shows whether the background task is alive, and errors
ticks(2)
check(F["Status"].rinfo() == "running", "Status: running")
clock = clock + 5000
check(F["Status"].rinfo() == "stopped", "Status: stopped when the background task stops looping")
ticks(1)
local real_lens = lens
lens = setmetatable({}, { __index = function(t, k)
    if k == "autofocusing" then error("test failure") end
    return real_lens[k]
end })
ticks(2)
check(F["Status"].rinfo() == "running (had an error)" and lfocus_last_error:match("test failure"),
    "an error is recorded and the background task keeps running")
lens = real_lens; lfocus_last_error = nil
ticks(2)
check(F["Status"].rinfo() == "running", "keeps running after the error")

-- chime OFF -> silent
F["Focus Chime"].value = "OFF"
lens.autofocusing = true; ticks(2); log = {}
lens.autofocusing = false; ticks(2)
check(#log == 0, "chime OFF is silent")

-- Auto AF needs a known, safe Canon Live View AF method
F["Auto AF"].value = "Every 2 s"
check(F["Auto AF"] ~= nil, "Auto AF menu exists")
lens.autofocus_calls = 0
ticks(200)
check(lens.autofocus_calls == 0, "Auto AF never runs while the LV AF method is unknown")

property.PROP_LIVE_VIEW_AF_SYSTEM:handler(0)          -- Quick mode
lens.autofocus_calls = 0; ticks(200)
check(lens.autofocus_calls == 0, "Auto AF never runs in Quick mode (mirror would flip)")

property.PROP_LIVE_VIEW_AF_SYSTEM:handler(1)          -- Live mode
F["Auto AF"].value = "OFF"; ticks(2)                  -- restart the 10 min window
F["Auto AF"].value = "Every 2 s"
lens.autofocus_calls = 0; ticks(200)                  -- ~12 s of 60 ms ticks
local n = lens.autofocus_calls
check(n >= 3 and n <= 7, "Auto AF fires every ~2 s in Live mode (" .. n .. " runs in ~12 s)")

for _, case in ipairs({
    { "recording",     function(v) movie.recording = v end },
    { "menu open",     function(v) menu.visible = v end },
    { "lens on MF",    function(v) lens.af = not v end },
    { "LV off",        function(v) lv.enabled = not v end },
    { "LV paused",     function(v) lv.running = not v end },
}) do
    case[2](true); lens.autofocus_calls = 0; ticks(200)
    check(lens.autofocus_calls == 0, "Auto AF never runs: " .. case[1])
    case[2](false)
end

-- 10 minute limit
F["Auto AF"].value = "OFF"; ticks(2)
F["Auto AF"].value = "Every 5 s"
log = {}
local t_end = clock + 11 * 60 * 1000
while clock < t_end do ticks(1) end
check(F["Auto AF"].value == "OFF", "Auto AF switches itself off after 10 minutes")
local told = false
for _, l in ipairs(log) do if l:match("Auto AF switched off") then told = true end end
check(told, "tells the user Auto AF was switched off")
lens.autofocus_calls = 0; ticks(200)
check(lens.autofocus_calls == 0, "no Auto AF after the time limit")

-- settings: saving and safe loading
lfocus_cfg:saving()
check(lfocus_cfg.data.auto == "OFF", "Auto AF is never saved as ON")
tasks = {}; sleeping = {}
mock_saved_cfg = { chime = "Crystal", auto = "Every 2 s" }
dofile(root .. "/lfocus.lua")
check(lfocus_menu.submenu["Focus Chime"].value == "Crystal", "saved chime is restored")
check(lfocus_menu.submenu["Auto AF"].value == "OFF", "Auto AF is OFF after reboot even if saved ON")
tasks = {}; sleeping = {}
mock_saved_cfg = { chime = "Banana" }                 -- bad value from an old/broken file
dofile(root .. "/lfocus.lua")
check(lfocus_menu.submenu["Focus Chime"].value == "Bright", "unknown saved chime falls back to Bright")
tasks = {}; sleeping = {}
mock_saved_cfg = {}                                   -- file with missing keys
dofile(root .. "/lfocus.lua")
check(lfocus_menu.submenu["Focus Chime"].value == "Bright", "missing saved keys fall back to defaults")
tasks = {}; sleeping = {}

----------------------------------------------------------------- lpreset
dofile(root .. "/lpreset.lua")
check(lpreset_menu.update(lpreset_menu) == "Everyday", "default preset is Everyday")

local function apply(name)
    lpreset_menu.submenu["Preset"].value = name
    menu_set_calls = {}; log = {}
    lpreset_menu.submenu["Apply"].select()
    run_tasks(2)
end

apply("Everyday")
check(#menu_set_calls == 9, "Everyday sets 9 overlay settings")
check(log[#log]:match("Everyday: 8 of 9 applied"), "reports missing entries honestly: " .. log[#log])

camera.mode = MODE.M
apply("Astro")
check(camera.iso.value == 1600, "Astro ISO 1600 in M")
check(camera.shutter.value == 20, "Astro 20 s in M")
check(camera.aperture.value == 3.5, "Astro widest aperture")

camera.mode = MODE.MOVIE; camera.shutter.value = 1/100
apply("Astro")
check(camera.shutter.value == 1/100, "Astro does not touch exposure in movie mode")
apply("Cinema")
check(math.abs(camera.shutter.value - 1/50) < 1e-9, "Cinema sets 1/50 s in movie mode")

camera.mode = MODE.P; camera.iso.value = 400
apply("Portrait")
check(camera.iso.value == 400, "Portrait leaves exposure alone outside M")
check(log[#log]:match("needs M mode"), "Portrait tells you exposure needs M")

camera.mode = MODE.M
apply("Cinema")
local restart = false
for _, c in ipairs(menu_set_calls) do if c == "Movie Tweaks/Movie Restart=1" then restart = true end end
check(restart, "Cinema turns on Movie Restart")

apply("Clean")
check(menu_set_calls[1] == "Overlay/Global Draw=0", "Clean hides overlays")

for _, name in ipairs({ "Everyday", "Portrait", "Landscape", "Cinema", "Astro", "Clean" }) do
    apply(name)
    for _, c in ipairs(menu_set_calls) do
        check(c:match("^Overlay/") or c:match("^Movie Tweaks/"),
            name .. " only changes overlays / movie tweaks (" .. c .. ")")
    end
end

lpreset_menu.submenu["Preset"].value = "Astro"
lpreset_cfg:saving()
tasks = {}; sleeping = {}
mock_saved_cfg = lpreset_cfg.data
dofile(root .. "/lpreset.lua")
check(lpreset_menu.submenu["Preset"].value == "Astro", "saved preset is restored")
tasks = {}; sleeping = {}
mock_saved_cfg = { preset = "Disco" }
dofile(root .. "/lpreset.lua")
check(lpreset_menu.submenu["Preset"].value == "Everyday", "unknown saved preset falls back to Everyday")
tasks = {}; sleeping = {}

----------------------------------------------------------------- lastro
lv.infos = {}
dofile(root .. "/lastro.lua")
check(lastro_menu.update(lastro_menu) == "OFF", "Star Limit off by default")
lastro_menu.submenu["Star Limit"].value = "ON"
lens.focal_length = 18
local info = lv.infos[1]
info.update(info)
check(info.value == "STAR 17s", "18 mm: 500/(18*1.6) = 17 s, got " .. info.value)
lastro_menu.submenu["Rule"].value = "300 rule (pixel)"
info.update(info)
check(info.value == "STAR 10s", "300 rule at 18 mm = 10 s, got " .. info.value)
lens.focal_length = 55
lastro_menu.submenu["Rule"].value = "500 rule"
info.update(info)
check(info.value == "STAR 6s", "55 mm = 6 s, got " .. info.value)
lastro_menu.submenu["Star Limit"].value = "OFF"
info.update(info)
check(info.value == "", "info hidden when OFF")

lv.zoom = 1; log = {}
lastro_menu.submenu["Star Focus"].select()
run_tasks(2)
check(lv.zoom == 10, "Star Focus sets 10x zoom")
check(log[#log]:match("10x"), "Star Focus confirms the zoom")

lv.zoom = 1; lv.zoom_refused = true; log = {}
lastro_menu.submenu["Star Focus"].select()
run_tasks(2)
check(lv.zoom == 1 and log[#log]:match("not available"), "Star Focus reports when zoom is refused")
lv.zoom_refused = false

lv.running = false; log = {}
lastro_menu.submenu["Star Focus"].select()
run_tasks(2)
check(log[#log]:match("Live View first"), "Star Focus needs running Live View")
lv.running = true

lastro_menu.submenu["Rule"].value = "400 rule (sharper)"
lastro_cfg:saving()
tasks = {}; sleeping = {}
mock_saved_cfg = lastro_cfg.data
lv.infos = {}
dofile(root .. "/lastro.lua")
check(lastro_menu.submenu["Rule"].value == "400 rule (sharper)", "saved rule is restored")
tasks = {}; sleeping = {}
mock_saved_cfg = { limit = 7, rule = "999 rule" }
lv.infos = {}
dofile(root .. "/lastro.lua")
check(lastro_menu.submenu["Star Limit"].value == "OFF" and lastro_menu.submenu["Rule"].value == "500 rule",
    "bad saved astro values fall back to defaults")



----------------------------------------------------------------- lquick
tasks = {}; sleeping = {}
dofile(root .. "/lquick.lua")
check(lquick_menu.parent == "Overlay" and lquick_menu.name == "LUMEN Quick", "LUMEN Quick is in the Overlay menu")

menu_values = {}
menu.visible = true
key_queue = { KEY.RIGHT, KEY.SET, KEY.Q }      -- move to Zebras, toggle it, close
draw_calls = 0; menu_set_calls = {}
lquick_menu.select()
for _ = 1, 20 do run_tasks(1) end
check(menu_values["Overlay/Zebras"] == 1, "SET turns the selected overlay on (Zebras)")
check(menu_set_calls[1] == "Overlay/Zebras=1", "only the selected overlay is changed")
check(draw_calls == 1, "keys that arrive together are handled in one pass, no wasted redraws (" .. draw_calls .. ")")
check(menu_blocked == false and event.keypress == nil, "closing gives the menu and buttons back")
check(lquick.open == false and #tasks == 0, "the Quick screen task ends after closing")

lquick.sel = 1
key_queue = { KEY.RIGHT, KEY.SET, KEY.SET }  -- Zebras off again, then on
menu_set_calls = {}
lquick_menu.select()
for _ = 1, 10 do run_tasks(1) end
key_queue = { KEY.MENU }                       -- then close (a separate press)
for _ = 1, 10 do run_tasks(1) end
check(menu_set_calls[1] == "Overlay/Zebras=0" and menu_set_calls[2] == "Overlay/Zebras=1"
    and menu_values["Overlay/Zebras"] == 1, "SET twice toggles Zebras off and on again")

menu.visible = true
key_queue = { KEY.LEFT }                      -- wrap from tile 2 to tile 1, then close via menu closing
lquick.sel = 2
lquick_menu.select()
run_tasks(3)
menu.visible = false                          -- user leaves the ML menu
run_tasks(3)
check(lquick.sel == 1 and lquick.open == false, "LEFT wraps; screen closes when the ML menu closes")
check(menu_blocked == false, "menu unblocked after the ML menu closes")

lquick.sel = 1
for _, k in ipairs({ KEY.DOWN, KEY.DOWN, KEY.LEFT, KEY.RIGHT, KEY.RIGHT }) do lquick:handle_key(k) end
check(lquick.sel == 2, "arrow navigation stays inside the 4x2 grid (sel=" .. lquick.sel .. ")")
for i = 1, 20 do lquick:handle_key(KEY.RIGHT) end
check(lquick.sel >= 1 and lquick.sel <= 8, "selection never leaves the grid")

menu.visible = true
key_queue = { KEY.SET, KEY.SET, KEY.Q }
lquick_menu.select(); lquick_menu.select()   -- double open must not start two screens
for _ = 1, 20 do run_tasks(1) end
check(lquick.open == false, "opening twice does not start two Quick screens")
menu.visible = false
tasks = {}; sleeping = {}

----------------------------------------------------------------- ltlapse
lv.infos = {}
dofile(root .. "/ltlapse.lua")
local tl_info = lv.infos[1]
interval.running = false
tl_info.update(tl_info)
check(tl_info.value == "", "timelapse info hidden when the intervalometer is off")
check(ltlapse_menu.update(ltlapse_menu) == "OFF", "Shoot menu shows OFF when not running")

interval.running = true; interval.time = 10; interval.count = 0
clock = 1000000
tl_info.update(tl_info)
check(tl_info.value == "TL 0  0:00", "running before the first frame: frames and elapsed")
interval.count = 1; event.intervalometer(1)
clock = clock + 3000
tl_info.update(tl_info)
check(tl_info.value == "TL 1  next 7s  0:03", "countdown after a frame, got " .. tl_info.value)
clock = clock + 65000
tl_info.update(tl_info)
check(tl_info.value:match("next 0s") and tl_info.value:match("1:08"), "countdown stops at 0; elapsed 1:08")

log = {}
ltlapse_menu.submenu["Frame Tick"].value = "ON"
check(event.intervalometer(2) == nil, "never asks the intervalometer to stop")
check(count_beeps() == 1, "Frame Tick beeps once per frame")
ltlapse_menu.submenu["Frame Tick"].value = "OFF"; log = {}
event.intervalometer(3)
check(count_beeps() == 0, "Frame Tick OFF is silent")

ltlapse_menu.submenu["Stop now"].select()
check(interval.running == false and interval.stopped == 1, "Stop now stops the intervalometer")
ltlapse_menu.submenu["Stop now"].select()
check(interval.stopped == 1, "Stop now does nothing when already stopped")
tl_info.update(tl_info)
check(tl_info.value == "", "info hidden again after stopping")

-- keys arriving one at a time each redraw once
menu.visible = true; lquick.sel = 1; draw_calls = 0
key_queue = {}
lquick_menu.select()
run_tasks(2)
local d0 = draw_calls
key_queue = { KEY.RIGHT }; run_tasks(2)
key_queue = { KEY.RIGHT }; run_tasks(2)
check(draw_calls == d0 + 2 and lquick.sel == 3, "each separate key press redraws once")
key_queue = { KEY.RIGHT, KEY.RIGHT, KEY.RIGHT, KEY.RIGHT }; run_tasks(2)
check(draw_calls == d0 + 3 and lquick.sel == 7, "a burst of 4 presses is drawn once (no lag build-up)")
key_queue = { KEY.Q }; run_tasks(3)
check(lquick.open == false, "Q closes")
menu.visible = false
tasks = {}; sleeping = {}

----------------------------------------------------------------- lmenu
menu_values = { ["Overlay/Zebras"] = 0, ["Overlay/Global Draw"] = 1 }
local real_get = menu.get
local get_calls = 0
-- simulate a camera where a few settings don't exist
local missing = { ["Vectorscope"] = true, ["Level Indicator"] = true, ["Headphone Mon."] = true }
menu.get = function(m, e, as_int)
    get_calls = get_calls + 1
    if missing[e] then return nil end
    return real_get(m, e, as_int)
end
menu_select_calls = {}
menu.select = function(m, e) table.insert(menu_select_calls, m .. "/" .. tostring(e)); return true end
local closed = 0
menu.close = function() closed = closed + 1; menu.visible = false end

dofile(root .. "/lmenu.lua")
check(lmenu_menu.parent == "Prefs", "LUMEN Menu settings live in Prefs")
check(lmenu_menu.submenu["Trash button opens"].value == "Magic Lantern menu", "Trash keeps opening the normal ML menu by default")

-- open from the menu item
menu.visible = true; draw_calls = 0; key_queue = {}
lmenu_menu.submenu["Open LUMEN Menu"].select()
run_tasks(3)
check(lmenu.open and menu_blocked and lmenu.capturing, "Open LUMEN Menu shows the screen")
check(lmenu.tabs[1].name == "Shoot", "first tab is Shoot")
local has_vs = false
for _, t in ipairs(lmenu.tabs) do
    for _, it in ipairs(t.items) do if it[1] == "Vectorscope" then has_vs = true end end
end
check(not has_vs, "settings this camera doesn't have are hidden")

-- navigation: RIGHT x2 = Overlay tab, DOWN = Global Draw, SET toggles it off
key_queue = { KEY.RIGHT, KEY.RIGHT, KEY.DOWN }
run_tasks(2)
check(lmenu.tabs[lmenu.tab].name == "Overlay" and lmenu.tabs[lmenu.tab].items[lmenu.row][1] == "Global Draw",
    "Left/Right change tab, Up/Down move (now Overlay / Global Draw)")
menu_set_calls = {}
key_queue = { KEY.SET }; run_tasks(2)
check(menu_set_calls[1] == "Overlay/Global Draw=0", "SET switches an ON/OFF item (Global Draw off)")
check(lmenu.tabs[lmenu.tab].values[lmenu.row] == "OFF", "the changed value is shown right away")

-- cached values: moving around does not re-read every setting
get_calls = 0
key_queue = { KEY.DOWN, KEY.DOWN, KEY.UP, KEY.DOWN }; run_tasks(2)
check(get_calls == 0, "moving between rows reads no settings (values cached)")

-- SET on a non-toggle item opens it in Magic Lantern and leaves the LUMEN screen
key_queue = { KEY.UP, KEY.UP, KEY.UP }; run_tasks(2)     -- back to "LUMEN Quick"
menu_set_calls = {}; menu_select_calls = {}
key_queue = { KEY.SET }; run_tasks(3)
check(#menu_set_calls == 0 and menu_select_calls[1] == "Overlay/LUMEN Quick",
    "SET on a non-switch item opens it in the ML menu instead of changing it")
check(lmenu.open == false and menu_blocked == false and lmenu.capturing == false,
    "leaving gives the menu and buttons back")

-- every toggle-marked item is a plain ON/OFF overlay/focus/audio/prefs item
for _, t in ipairs(lmenu.tabs) do
    for _, it in ipairs(t.items) do
        if it.toggle then
            check(t.name ~= "Shoot" and t.name ~= "Expo" and t.name ~= "Debug" and t.name ~= "Movie",
                "no Shoot/Expo/Movie/Debug item can be switched from LUMEN Menu (" .. it[1] .. ")")
        end
    end
end

-- Trash / MENU are passed straight to ML (instant close, no slow menu.close)
menu.visible = true; key_results = {}
lmenu_menu.submenu["Open LUMEN Menu"].select(); run_tasks(3)
key_queue = { KEY.MENU }; run_tasks(3)
check(key_results[#key_results].passed and menu.visible == false and lmenu.open == false and closed == 0,
    "MENU goes straight to Magic Lantern, which closes the menu; LUMEN Menu ends")
check(lmenu_menu ~= nil and event.keypress ~= nil and lmenu.capturing == false,
    "the Trash hook is back after closing")

-- INFO goes to the classic ML menu (stays open)
menu.visible = true; closed = 0
lmenu_menu.submenu["Open LUMEN Menu"].select(); run_tasks(3)
key_queue = { KEY.INFO }; run_tasks(3)
check(lmenu.open == false and closed == 0 and menu.visible, "INFO switches to the classic ML menu")

-- Trash shortcut: off by default, then on
menu.visible = false
event.keypress(KEY.TRASH); run_tasks(2)
check(lmenu.starting == false and lmenu.open == false, "Trash does nothing extra while set to the ML menu")
lmenu_menu.submenu["Trash button opens"].value = "LUMEN Menu"
check(event.keypress(KEY.TRASH) == nil, "the Trash key is never blocked")
run_tasks(2)
check(lmenu.open == false, "waits for the ML menu to appear first")
menu.visible = true; run_tasks(3)
check(lmenu.open == true, "Trash opens LUMEN Menu once the ML menu is on screen")
key_queue = { KEY.TRASH }; run_tasks(3)
check(lmenu.open == false and menu.visible == false, "Trash closes it again")

-- Trash pressed but the menu never appears: gives up quietly after 2 s
lmenu.starting = false; menu.visible = false
event.keypress(KEY.TRASH)
for _ = 1, 60 do run_tasks(1) end
check(lmenu.starting == false and lmenu.open == false, "gives up if the ML menu never opens")

-- settings
lmenu_cfg:saving()
check(lmenu_cfg.data.trash == "LUMEN Menu", "Trash setting is saved")
tasks = {}; sleeping = {}
mock_saved_cfg = { trash = "Banana" }
dofile(root .. "/lmenu.lua")
check(lmenu_menu.submenu["Trash button opens"].value == "Magic Lantern menu", "bad saved value falls back to the ML menu")
tasks = {}; sleeping = {}
menu.get = real_get

-- fresh LUMEN Menu for the following tests
tasks = {}; sleeping = {}
dofile(root .. "/lmenu.lua")

-- buttons other than Trash/MENU never reach the hidden ML menu while LUMEN Menu is open
menu.visible = true; key_results = {}
lmenu_menu.submenu["Open LUMEN Menu"].select(); run_tasks(3)
key_queue = { KEY.SET, KEY.UP, KEY.DOWN, KEY.LEFT, KEY.RIGHT, KEY.Q }; run_tasks(1)
local leaked = false
for _, r in ipairs(key_results) do if r.passed then leaked = true end end
check(not leaked, "SET/arrows/Q are kept from the classic menu underneath")
key_queue = { KEY.TRASH }; run_tasks(3)
check(menu.visible == false and lmenu.open == false, "Trash closes")

-- Global Draw keeps its mode when switched off and on (3 = ON, all modes)
menu_values["Overlay/Global Draw"] = 3
menu.visible = true
lmenu.tab, lmenu.row, lmenu.top = 3, 2, 1          -- Overlay / Global Draw
lmenu_menu.submenu["Open LUMEN Menu"].select(); run_tasks(3)
check(lmenu.tabs[lmenu.tab].items[lmenu.row][1] == "Global Draw", "selected Global Draw")
key_queue = { KEY.SET }; run_tasks(2)
check(menu_values["Overlay/Global Draw"] == 0, "Global Draw off")
key_queue = { KEY.SET }; run_tasks(2)
check(menu_values["Overlay/Global Draw"] == 3, "Global Draw back to its previous mode (ON, all modes)")
key_queue = { KEY.TRASH }; run_tasks(3)

-- if the screen can't open, the Trash hook stays (event.keypress not lost)
local hook = event.keypress
local saved_get = menu.get
menu.get = function() return nil end              -- camera reports no settings
lmenu.built = false
menu.visible = true; log = {}
lmenu_menu.submenu["Open LUMEN Menu"].select(); run_tasks(3)
check(event.keypress == hook and hook ~= nil, "a failed open leaves the Trash hook in place")
check(log[#log] and log[#log]:match("LUMEN Menu:"), "a failed open is reported, not silent")
menu.get = saved_get; lmenu.built = false; menu.visible = false

-- its own Prefs entry is not listed inside LUMEN Menu
lmenu:build()
check(#lmenu.tabs > 0, "settings list rebuilt")
for _, t in ipairs(lmenu.tabs) do
    for _, it in ipairs(t.items) do
        check(it[1] ~= "LUMEN Menu", "LUMEN Menu does not list itself")
    end
end

-- Quick: Global Draw also keeps its mode
tasks = {}; sleeping = {}
dofile(root .. "/lquick.lua")
menu_values["Overlay/Global Draw"] = 3
menu.visible = true; lquick.sel = 1
key_queue = { KEY.SET, KEY.SET, KEY.Q }
lquick_menu.select(); for _ = 1, 10 do run_tasks(1) end
check(menu_values["Overlay/Global Draw"] == 3, "Quick restores Global Draw's mode")
key_results = {}
key_queue = { KEY.TRASH }
lquick_menu.select(); run_tasks(3)
check(key_results[1].passed and menu.visible == false and lquick.open == false, "Trash closes Quick instantly")
tasks = {}; sleeping = {}

print("\nall LUMEN script tests passed (including Quick, Timelapse and LUMEN Menu)")
