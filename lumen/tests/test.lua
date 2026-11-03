-- Exercise LUMEN scripts against the mock API.
-- Run: lua5.3 lumen/tests/test.lua lumen/scripts lumen/tests
local root = arg[1]
dofile(arg[2] .. "/mock.lua")

local function check(cond, msg)
    if not cond then error("FAIL: " .. msg) end
    print("ok   " .. msg)
end

----------------------------------------------------------------- lfocus
dofile(root .. "/lfocus.lua")
check(lfocus_menu.submenu["Focus Chime"].value == "Bright", "default chime is Bright")
check(lfocus_menu.update(lfocus_menu) == "Chime: Bright", "menu summary shows chime")

-- user half-press: focusing true for a while, then false -> chime
run_tasks(2)
lens.autofocusing = true;  run_tasks(3)
log = {}
lens.autofocusing = false; run_tasks(3)
local beeps = 0
for _, l in ipairs(log) do if l:match("^beep") then beeps = beeps + 1 end end
check(beeps == 2, "Bright chime plays 2 tones after AF ends (got " .. beeps .. ")")

-- no chime when nothing happens
log = {}; run_tasks(5)
check(#log == 0, "no chime while idle")

-- chime OFF -> silent
lfocus_menu.submenu["Focus Chime"].value = "OFF"
lens.autofocusing = true; run_tasks(2); log = {}
lens.autofocusing = false; run_tasks(2)
check(#log == 0, "chime OFF is silent")

-- Auto AF every 2 s: should trigger, but not while recording / in menu
lfocus_menu.submenu["Auto AF"].value = "Every 2 s"
lens.autofocus_calls = 0
for _ = 1, 200 do run_tasks(1) end          -- ~12 s of 60 ms ticks
local n = lens.autofocus_calls
check(n >= 3 and n <= 7, "Auto AF fires every ~2 s (" .. n .. " runs in ~12 s)")

movie.recording = true; lens.autofocus_calls = 0
for _ = 1, 200 do run_tasks(1) end
check(lens.autofocus_calls == 0, "Auto AF never runs while recording")
movie.recording = false

menu.visible = true; lens.autofocus_calls = 0
for _ = 1, 200 do run_tasks(1) end
check(lens.autofocus_calls == 0, "Auto AF never runs while the menu is open")
menu.visible = false

lens.af = false; lens.autofocus_calls = 0
for _ = 1, 200 do run_tasks(1) end
check(lens.autofocus_calls == 0, "Auto AF never runs with the lens on MF")
lens.af = true

lv.enabled = false; lens.autofocus_calls = 0
for _ = 1, 200 do run_tasks(1) end
check(lens.autofocus_calls == 0, "Auto AF never runs outside Live View")
lv.enabled = true
lfocus_menu.submenu["Auto AF"].value = "OFF"

-- Test Chime action
lfocus_menu.submenu["Focus Chime"].value = "Crystal"
log = {}
lfocus_menu.submenu["Test Chime"].select()
for _ = 1, 5 do run_tasks(1) end
beeps = 0
for _, l in ipairs(log) do if l:match("^beep") then beeps = beeps + 1 end end
check(beeps == 3, "Test Chime plays Crystal (3 tones)")
tasks = {}

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
check(#menu_set_calls == 11, "Everyday sets 11 ML settings")
check(log[#log]:match("Everyday: 10 of 11 applied"), "reports missing entries honestly: " .. log[#log])

camera.mode = MODE.M
apply("Astro")
check(camera.iso.value == 1600, "Astro ISO 1600 in M")
check(camera.shutter.value == 20, "Astro 20 s in M")
check(camera.aperture.value == 3.5, "Astro widest aperture")

camera.mode = MODE.P; camera.iso.value = 400
apply("Portrait")
check(camera.iso.value == 400, "Portrait leaves exposure alone outside M")
check(log[#log]:match("needs M mode"), "Portrait tells you exposure needs M")

camera.mode = MODE.M
apply("Cinema")
check(math.abs(camera.shutter.value - 1/50) < 1e-9, "Cinema 1/50 s")
local restart = false
for _, c in ipairs(menu_set_calls) do if c == "Movie Tweaks/Movie Restart=1" then restart = true end end
check(restart, "Cinema turns on Movie Restart")

apply("Clean")
check(menu_set_calls[1] == "Overlay/Global Draw=0", "Clean hides overlays")

for _, c in ipairs(menu_set_calls) do
    check(not c:match("Intervalometer"), "presets never arm the intervalometer")
end
tasks = {}

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

lv.zoom = 1
lastro_menu.submenu["Star Focus"].select()
run_tasks(2)
check(lv.zoom == 10, "Star Focus sets 10x zoom")

print("\nall LUMEN script tests passed")
