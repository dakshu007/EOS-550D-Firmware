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
check(draw_calls >= 3, "the screen is redrawn after each key (" .. draw_calls .. " draws)")
check(menu_blocked == false and keys.running == false, "closing gives the menu and keys back")
check(lquick.open == false and #tasks == 0, "the Quick screen task ends after closing")

lquick.sel = 1
key_queue = { KEY.RIGHT, KEY.SET, KEY.SET, KEY.MENU }  -- Zebras off again, then on
menu_set_calls = {}
lquick_menu.select()
for _ = 1, 20 do run_tasks(1) end
check(menu_set_calls[1] == "Overlay/Zebras=0" and menu_set_calls[2] == "Overlay/Zebras=1"
    and menu_values["Overlay/Zebras"] == 1, "SET twice toggles Zebras off and on again")

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

print("\nall LUMEN script tests passed (including Quick and Timelapse)")
