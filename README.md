# Resident Evil 7 media fix for CrossOver Preview

Fixes the tested RE7 startup failure after logos by using one consistent GStreamer runtime and its required plugins. Independent of REFramework and VR: fix flat-game video playback first, then use your VR mod.

Tested on CrossOver Preview build 20261006, macOS, GPTK 4 / D3DMetal. Confirmed by the publisher: RE7 progressed past logos into the game after adding both deinterlace and videoflip. Other builds are not verified.

## Prerequisites
- CrossOver Preview installed in /Applications and an existing bottle (default: Steam).
- Apple Command Line Tools or Xcode: install_name_tool, codesign and Python 3.
- GStreamer 1.28.1 x86_64 from the Sikarugir-App release below. This package does not redistribute CrossOver or GStreamer binaries.

Download https://github.com/Sikarugir-App/gstreamer/releases/download/1.28.1/gstreamer-1.0-1.28.1-x86_64.tar.xz and extract it. Copy the entire GStreamer.framework to:

`/Applications/CrossOver Preview.app/Contents/SharedSupport/CrossOver/lib64/GStreamer.framework`

Create lib64 if absent. Copy the whole framework, preserving its symlinks; do not copy individual codec libraries into the stock runtime.

## Install
Fully shut down the bottle first. From the extracted fix folder:

```bash
bash patch-preview.command --check
sudo bash patch-preview.command --bottle Steam
```

For a different bottle use its name. For another installation use `--app "/path/CrossOver Preview.app"`. Custom bottle storage: `--bottles-dir "/path/to/Bottles"`.

Restart the bottle and launch RE7 normally. Logging is off by default. Optional diagnostic installation: add `--diagnostics` (writes ~/Downloads/re7-media.log).

## What changes
- Repoints the x86_64 winegstreamer.so and winedmo.so library search path to the installed framework; keeps their original Wine code and signs the modified modules ad hoc.
- Creates a selected plugin directory: coreelements, typefindfunctions, libav, asf, playback, audioconvert, audioresample, videoconvertscale, volume, app, deinterlace, videofilter (videoflip).
- Sets version-specific plugin paths and a separate GStreamer registry in the chosen bottle.
- Removes quarantine metadata from that installed framework so plugins can load.
- Saves the original modules and bottle configuration before replacing them. No VR runtime, graphics backend or MSync change is made.

## Restore
Close the bottle, then:

```bash
sudo bash patch-preview.command --restore
```

Restore reinstates the entire backed-up bottle configuration, including settings as they were at installation. Preserve any later configuration edits separately. The downloaded framework and selected plugin links remain on disk but are no longer selected by the restored settings. Application backups are under RE7-media-backup-* in CrossOver's SharedSupport/CrossOver folder. CrossOver updates can overwrite this patch; restore before upgrading when possible.

This is an experimental, targeted workaround, not CXPatcher or a general patch for every game. Already patched installations should be restored using their original installer before installing this portable version.

Credits: GStreamer and its contributors; Sikarugir-App runtime distribution; armax9 for the tested workaround.
