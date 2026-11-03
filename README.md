# LUMEN: custom firmware for the Canon EOS 550D

LUMEN is a minimal, dark interface for the **Canon EOS 550D / Rebel T2i / Kiss X4**, built on
[Magic Lantern](https://github.com/reticulatedpines/magiclantern_simplified).

Like Magic Lantern, it runs **from the SD card**, alongside Canon's firmware. Canon's firmware is
never modified. To go back to the stock camera, start it with a normal card.

- **Camera:** EOS 550D, Canon firmware **1.0.9** (required)
- **Based on:** Magic Lantern `ed3e7c0df` (`2025_release_01`), the build installed on the camera
- **Design:** the LUMEN canvas, with all screens drawn at the native 720 × 480 resolution

## Status: v0.3.6

The full feature list, including the Canon settings for focus beeps and AF, is in **[FEATURES.md](FEATURES.md)**.

| Area | State |
|---|---|
| Menu theme: near-black header and footer, gray selection, amber accent | ✅ |
| LUMEN boot / About screen: "Focus Frame" logo, by Dakshesh | ✅ new |
| **Focus Chime**: pleasant tone when autofocus finishes in Live View | ✅ new |
| **Auto AF**: refocus every 2, 5 or 10 s in Live View, off after 10 min | ✅ new |
| **Presets**: Everyday, Portrait, Landscape, Cinema, Astro, Clean | ✅ new |
| **Astro**: star-trail limit and 10× star focus | ✅ new |
| Lua module and LUMEN scripts start automatically | ✅ new |
| All Magic Lantern 550D features | ✅ unchanged |
| Camera starts exactly like stock: no boot logo, and the Lua console no longer pops up at startup (it left the screen blank until a button press) | ✅ |
| **LUMEN Menu**: the design's menu layout (Prefs → LUMEN Menu) | ✅ new |
| **Quick toggles** screen (Overlay → LUMEN Quick) | ✅ new |
| **Timelapse status** (Shoot → LUMEN Timelapse) | ✅ new |
| Live View info bars in LUMEN colors | ✅ new |
| Darker selection bar, longer chime notes | ✅ new |
| Playback panel (needs photo data scripts can't read), LUMEN fonts | not possible / not yet |

## Get a build

Every push is tested and built automatically by GitHub Actions:

1. Open the repo's **Actions** tab, then the latest green **Build LUMEN** run.
2. Download the **LUMEN-550D.109** artifact and unzip it. It contains
   `LUMEN-550D.109-<version>.zip` and a `.sha256` file.
3. Check that the download is intact:

   ```bash
   shasum -a 256 LUMEN-550D.109-0.3.6.zip
   ```

   Compare the result with the `.sha256` file. (It proves the file wasn't damaged in transit. It
   comes from the same build, so it doesn't prove who built it.)

## Install on the card (Magic Lantern already installed)

The boot flag is already set, so you only update the files on the card. Nothing is written to the
camera itself. **Don't use Finder's "Replace" on the `ML` folder.** It would delete `ML/SETTINGS`
and `ML/LOGS`.

1. With the camera **off**, put the card in your Mac and **back it up** first:

   ```bash
   rsync -rt /Volumes/EOS_DIGITAL/ ~/card-backup-magiclantern/
   ```

2. Unzip `LUMEN-550D.109-<version>.zip` into `~/Downloads/LUMEN`, then check that
   `~/Downloads/LUMEN/autoexec.bin` exists. It must be at the top level, not in a subfolder:

   ```bash
   ls ~/Downloads/LUMEN
   ```

3. Merge the files onto the card. This overwrites the program files and keeps your settings and
   logs:

   ```bash
   rsync -rtv --modify-window=1 ~/Downloads/LUMEN/ /Volumes/EOS_DIGITAL/
   ```

   ```bash
   dot_clean /Volumes/EOS_DIGITAL
   ```

4. Eject the card, put it in the camera and turn it on. Press **Trash** to open LUMEN.
   The Lua module and the LUMEN scripts load automatically at startup (a few seconds).
   You'll find them under **Prefs → LUMEN Menu**, **Focus → LUMEN Focus**, **Overlay → LUMEN Quick**, **Shoot → LUMEN Presets**,
   **Shoot → LUMEN Astro** and **Shoot → LUMEN Timelapse**.

### Upgrading from LUMEN 0.3.2 or older (one time)

Older versions used six separate scripts, which filled the camera's Lua memory. `rsync` never
deletes, so remove the old scripts and their autorun flags once (card in the Mac):

```bash
cd /Volumes/EOS_DIGITAL/ML/scripts && rm -f LFOCUS.LUA LPRESET.LUA LASTRO.LUA LQUICK.LUA LTLAPSE.LUA LMENU.LUA
```

```bash
cd /Volumes/EOS_DIGITAL/ML/SETTINGS && rm -f LFOCUS.LEN LPRESET.LEN LASTRO.LEN LQUICK.LEN LTLAPSE.LEN LMENU.LEN LFOCUS.CFG LPRESET.CFG LASTRO.CFG LMENU.CFG
```

### If something goes wrong

- **The camera doesn't start or freezes:** remove the battery **and** the card, wait a minute,
  put the battery back without the card and turn the camera on. It starts as a stock Canon camera.
  Then restore the backup on your Mac:

  ```bash
  rsync -rtv --modify-window=1 ~/card-backup-magiclantern/ /Volumes/EOS_DIGITAL/
  ```

- **After a crash,** Magic Lantern skips loading modules on the next start, as a safety measure.
  Restart once more to load them again.
- **To turn off the LUMEN script only:** delete `ML/SETTINGS/LUMEN.LEN` on the card. Delete `ML/SETTINGS/LUA.EN` too to stop loading Lua.
- **A Canon setting looks changed** (for example the AF button custom function after a battery
  pull during autofocus): fix it in the Canon menu, or use Canon's *Clear all camera settings*.
- **To boot stock firmware once:** hold **SET** while turning the camera on.
- **To uninstall:** run *Menu → Firmware Ver.* with `ML-SETUP.FIR` on the card and wait for the
  uninstall countdown to finish. This is the only step that writes to the camera, so use a full
  battery and never interrupt it.

## Build locally (Linux)

```bash
sudo apt install gcc-arm-none-eabi libnewlib-arm-none-eabi python3-docutils make zip git lua5.3
```

```bash
lumen/make_bundle.sh /tmp/lumen.lua && lua5.3 lumen/tests/test.lua /tmp/lumen.lua lumen/tests
```

```bash
./build.sh
```

The output goes to `dist/`. `build.sh` fetches the pinned Magic Lantern commit into `work/`,
applies `lumen/patches/*.patch` and builds `platform/550D.109`.

## Repo layout

```
build.sh                    fetch Magic Lantern, apply patches, add scripts, build
FEATURES.md                 everything LUMEN can (and can't) do
lumen/VERSION               LUMEN version
lumen/patches/              LUMEN changes to Magic Lantern's C code
lumen/src/                  LUMEN features in Lua, one file per feature (core, Focus,
                            Presets, Astro, Timelapse, Quick, Menu, main)
lumen/make_bundle.sh        joins lumen/src/ into ONE script (ML/scripts/lumen.lua):
                            one Lua state and one background task, to fit the 550D's memory
lumen/card/                 extra card files: autorun flags in ML/SETTINGS (LUA.EN, LUMEN.LEN)
lumen/tests/                tests for the Lua scripts, run against a mock camera API
.github/workflows/build.yml tests and builds on every push
```

## Never commit

- `ROM0.BIN` / `ROM1.BIN`: dumps of the camera's memory, which contain Canon's copyrighted code.
- Canon `.FIR` firmware files.

`.gitignore` blocks both.

## License and credits

Magic Lantern is © the Magic Lantern developers and licensed under the GNU GPL v2 or later.
The LUMEN changes are released under the same license (see `COPYING`). LUMEN is an unofficial
project and isn't affiliated with Canon or the Magic Lantern project. Use it at your own risk.
