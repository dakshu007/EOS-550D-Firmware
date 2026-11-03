# LUMEN features (v0.3.7)

Everything LUMEN can do on the EOS 550D, where to find it, and what the camera's hardware can't do.

Press **Trash (🗑)** to open the LUMEN menu. **◀ ▶** switch tabs, **▲ ▼** move, **SET** changes a
setting and **Q** opens a submenu.

## New in LUMEN

| Feature | Where | What it does |
|---|---|---|
| **Focus Chime** | Focus → LUMEN Focus | Plays a short tone when autofocus finishes in Live View. Choose Soft, Bright (default), Crystal or Classic. **Test Chime** plays it right away and shows a message. |
| **Status** | Focus → LUMEN Focus | Shows whether LUMEN's background task is running (it runs the AF chime, Auto AF, LUMEN Menu, Quick, Presets and Star Focus), and the last error if there was one. Press SET to see the details. |
| **Auto AF** | Focus → LUMEN Focus | In Live View, refocuses every 2, 5 or 10 s while you're not recording. Always starts OFF and switches itself off after 10 minutes. |
| **Presets** | Shoot → LUMEN Presets | One-tap setups: **Everyday, Portrait, Landscape, Cinema, Astro, Clean**. Pick one, then **Apply**. |
| **Star Limit** | Shoot → LUMEN Astro | Shows the longest exposure before stars trail at your focal length (500, 400 or 300 rule, 1.6× crop) in the Live View info bar. |
| **Star Focus** | Shoot → LUMEN Astro | Jumps Live View to 10× zoom for focusing on a star, and tells you if Canon refuses the zoom (then press the zoom button). |
| **LUMEN Menu** | **Trash** button (default), or Prefs → LUMEN Menu → Open LUMEN Menu | The LUMEN menu layout: tab names in a rail on the left, settings with their current values, a description and button hints at the bottom. **◀ ▶** change tab, **▲ ▼** move, **SET** switches ON/OFF items (overlays, trap/follow focus), **Q** or **SET** on anything else opens it in the normal Magic Lantern menu, **INFO** switches to the classic menu, **Trash** closes (instantly, like the normal menu). Switching an item OFF and ON again restores its previous mode (for example Global Draw "ON, all modes"). Settings this camera doesn't have are hidden. For the plain Magic Lantern menu on Trash, set **Prefs → LUMEN Menu → Trash button opens → Magic Lantern menu**. |
| **Quick toggles** | Overlay → LUMEN Quick | One screen with 8 tiles: Overlays, Zebras, Focus Peak, Magic Zoom, Cropmarks, Spotmeter, False Color, Histogram. Arrows move, **SET** toggles (and restores the previous mode when switched back on), **Q** goes back, **Trash** closes. Star it to put it in **★ My Menu**. |
| **Timelapse status** | Shoot → LUMEN Timelapse | While the intervalometer runs: frames taken, countdown to the next frame and elapsed time, in the menu and the Live View info bar. Optional **Frame Tick** sound, and **Stop now**. |
| **Live View colors** | Live View info bars | The ISO value you're changing shows as an amber label, exposure override and RAW in amber. Overheat warnings stay red and orange. |
| **LUMEN theme** | everywhere | Dark menus, gray selection bar with an amber marker, amber accents and the LUMEN About screen. |

Notes:
- **Presets** change ISO, shutter speed and aperture only when the dial is on **M** (Cinema also works
  in movie mode with manual exposure). In other modes they change only the overlays. A message reports
  how many settings were applied. Presets change only overlays and movie helpers. They never touch
  Canon custom functions (mirror lockup, bracketing) and never start the intervalometer.
- **Auto AF** safety rules:
  - It runs only when the Canon Live View AF method is **Live mode** or **Face detection**, and never
    in **Quick mode**, where the mirror would flip every time.
  - If the menu shows a warning, the AF method isn't known yet. Change Canon's Live View AF mode to
    another setting and back to **Live mode** once.
  - It never runs while recording, with the menu open, with the lens on MF, or outside Live View.
  - It always starts OFF after power-on and switches itself off after 10 minutes. This saves the
    battery, because it keeps the camera from sleeping.
  - It suits still or slow subjects. The 550D can't track moving subjects in Live View.
  - If you use **back-button AF** (Canon custom function), Magic Lantern briefly changes that custom
    function during each autofocus and restores it afterwards. If the battery is pulled mid-focus,
    check it in the Canon menu.
- The chime is silent while you record video with sound, so it never ends up in your audio.

## Not changed by LUMEN

- **Canon's own screens** (the MENU button screens, the Q screen, Canon's Live View icons) are part
  of Canon's firmware inside the camera. Changing them would mean rewriting the camera's internal
  memory, which is what can brick a camera, so LUMEN leaves them alone. In Live View, press
  **DISP** to switch to the Magic Lantern / LUMEN overlays.
- **The classic Magic Lantern menu** is still there (press **INFO** in the LUMEN Menu). The LUMEN
  Menu shows and switches the common settings. Detailed editing (for example choosing a zebra level
  or an ISO) happens in the classic menu, which LUMEN opens for you on the right item.
- **Playback:** a custom LUMEN playback panel isn't possible, because scripts can't read a photo's
  saved exposure details. Magic Lantern's playback tools still work: press **Q** while reviewing a
  photo for the histogram and zebras, and use **Prefs → Image Review → QuickZoom**.
- **The Magic Lantern welcome screen** still appears once a day the first time you open the menu.
  It now shows the LUMEN logo.

## Focus beep and autofocus: Canon settings that help

The 550D's own beep and AF modes work alongside LUMEN. Set these in the **Canon menu** (MENU button):

| Setting | Where (Canon menu) | Set to | Why |
|---|---|---|---|
| Beep | Shooting 1 → **Beep** | **Enable** | Beeps when focus locks in the **viewfinder**. LUMEN's chime covers Live View. |
| AF mode (viewfinder) | Press the **AF** button (▶ on the dial) | **AI Servo** | Continuous autofocus: keeps tracking a moving subject while you hold the shutter halfway. |
| AF mode (still subjects) | Press the **AF** button | **One Shot** | Locks focus once and beeps |
| Live View AF method | Shooting 4 → **AF mode** (Live View settings) | **Live mode**, or **Face detection Live mode** for people | Contrast AF on the sensor, needed for LUMEN Auto AF. Face detection finds faces automatically. |
| Movie AF | Movie menu → **AF mode** | **Live mode** or **Face detection** | Press halfway (or *) to refocus during video |

## All features by tab

| Tab | Features |
|---|---|
| 🎤 **Audio** | Manual audio levels (analog and digital gain), AGC off, wind filter, input source, audio meters |
| ± **Expo** | White balance in Kelvin and fine-tuning, fine ISO, shutter and aperture control, picture styles, auto ETTR, Dual ISO, auto exposure |
| 📊 **Overlay** | Zebras, focus peaking, Magic Zoom, cropmarks, ghost image, spotmeter, false color, histogram, waveform, vectorscope |
| 🎥 **Movie** | RAW video (MLV Lite) with sound (mlv_snd) and playback (mlv_play), FPS override, HDR video, bit rate, gradual exposure, vignetting, image fine-tuning, creative effects, Movie Tweaks (logging, time indicator, auto-restart, REC/STBY notify, force Live View, shutter lock) |
| 📷 **Shoot** | **LUMEN Presets**, **LUMEN Astro**, HDR bracketing, intervalometer, advanced intervalometer (adv_int), deflicker, bulb timer, silent pictures, motion detect, LCD sensor remote, audio remote shot, mirror lockup, flash tweaks |
| ✛ **Focus** | **LUMEN Focus**, trap focus, follow focus, rack focus, focus stacking, DOF and hyperfocal info, focus patterns |
| 🖥 **Display** | Live View brightness, contrast and saturation, color schemes, clear overlays, defishing, anamorphic preview |
| 🔧 **Prefs** | Config files, QuickZoom image review, Live View zoom tweaks, focus box, arrow/SET shortcuts, key settings, warnings, power saving, display presets, **customize menus / My Menu** |
| ▦ **Modules** | File manager, image viewer, Lua scripting, custom file names (img_name), card benchmark, self-test, Arkanoid |
| 📜 **Scripts** | LUMEN scripts plus calculator, Pong, Sokoban, text editor, movie delayed start, screenshot |

### Make your own "Fn" menu (like Sony)
1. Open any setting you use often, for example Zebras.
2. Open **Prefs → Customize Menus** and star (★) the settings you want.
3. They appear together in the **★ My Menu** tab, your one-stop quick menu.

## Not possible on the 550D hardware

| Feature on modern cameras | Why not |
|---|---|
| Eye AF and AI subject tracking | No on-sensor phase-detect AF or AI processor |
| Fast, continuous video AF | Same reason. Live View uses slow contrast AF. |
| In-body stabilization, pixel shift | The sensor can't move. Use lens IS. |
| 4K, 120 fps, 10-bit, log profiles | DIGIC 4 processor and card speed limits |
| Electronic level | The 550D has no level sensor |
| Wi-Fi, Bluetooth, touchscreen, flip screen, dual cards | Physical hardware |
