# LUMEN: custom firmware for the Canon EOS 550D

LUMEN is a minimal, dark interface for the **Canon EOS 550D / Rebel T2i / Kiss X4**, built on
[Magic Lantern](https://github.com/reticulatedpines/magiclantern_simplified).

Like Magic Lantern, it runs **from the SD card**, alongside Canon's firmware. Canon's firmware is
never modified. To go back to the stock camera, start it with a normal card.

- **Camera:** EOS 550D, Canon firmware **1.0.9** (required)
- **Based on:** Magic Lantern `ed3e7c0df` (`2025_release_01`), the build installed on the camera
- **Design:** the LUMEN canvas, with all screens drawn at the native 720 × 480 resolution

## Status: v0.2.0

The full feature list, including the Canon settings for focus beeps and AF, is in **[FEATURES.md](FEATURES.md)**.

| Area | State |
|---|---|
| Menu theme: near-black header and footer, gray selection, amber accent | ✅ |
| LUMEN welcome / About screen | ✅ |
| **Focus Chime**: pleasant tone when autofocus finishes in Live View | ✅ new |
| **Auto AF**: refocus every 2, 5 or 10 s in Live View | ✅ new |
| **Presets**: Everyday, Portrait, Landscape, Cinema, Astro, Clean | ✅ new |
| **Astro**: star-trail limit and 10× star focus | ✅ new |
| Lua module and LUMEN scripts start automatically | ✅ new |
| All Magic Lantern 550D features | ✅ unchanged |
| Live View info bar restyle, LUMEN fonts | planned |

## Get a build

Every push is built automatically by GitHub Actions:

1. Open the repo's **Actions** tab, then the latest green **Build LUMEN** run.
2. Download the **LUMEN-550D.109** artifact and unzip it. It contains
   `LUMEN-550D.109-<version>.zip` and a `.sha256` file.
3. Verify the zip:

   ```bash
   shasum -a 256 LUMEN-550D.109-0.2.0.zip
   ```

   Compare the result with the contents of the `.sha256` file.

## Install on the card (Magic Lantern already installed)

The boot flag is already set, so you only need to update the files on the card. **Don't use
Finder's "Replace" on the `ML` folder.** It would delete `ML/SETTINGS` and `ML/LOGS`.

1. Unzip `LUMEN-550D.109-<version>.zip` into a folder, for example `~/Downloads/LUMEN`.
2. With the camera **off**, put the card in your Mac and merge the files onto it. This overwrites
   the program files and keeps your settings and logs:

   ```bash
   rsync -av ~/Downloads/LUMEN/ /Volumes/EOS_DIGITAL/
   ```

   ```bash
   dot_clean /Volumes/EOS_DIGITAL
   ```

3. Eject the card, put it in the camera and turn it on. Press **Trash** to open LUMEN.
   The Lua module and the LUMEN scripts load automatically at startup (a few seconds).
   You'll find them under **Focus → LUMEN Focus**, **Shoot → LUMEN Presets** and **Shoot → LUMEN Astro**.

### If something goes wrong

- **The camera doesn't start or freezes:** remove the battery **and** the card, wait a minute,
  put the battery back without the card and turn the camera on. It starts as a stock Canon camera.
  Then put the previous Magic Lantern files back on the card.
- **To boot stock firmware once:** hold **SET** while turning the camera on.
- **To uninstall:** run *Menu → Firmware Ver.* with `ML-SETUP.FIR` on the card and wait for the
  uninstall countdown to finish.

## Build locally (Linux)

```bash
sudo apt install gcc-arm-none-eabi libnewlib-arm-none-eabi python3-docutils make zip git lua5.3
```

```bash
lua5.3 lumen/tests/test.lua lumen/scripts lumen/tests
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
lumen/scripts/              LUMEN features written in Lua (Focus, Presets, Astro)
lumen/card/                 extra card files: autorun flags in ML/SETTINGS
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
