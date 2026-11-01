# Capture the actual game on all three maps

Run this in an ordinary graphical desktop session with Godot 4.7.2 and ffmpeg installed. The originating agent sandbox could not initialize a macOS window, so **the movie/GIF path is prepared, not visually validated**.

```sh
python3 tools/capture_gameplay.py \
  --project /path/to/skate-dismount \
  --output /path/to/new-capture-directory \
  --godot /opt/homebrew/bin/godot \
  --ffmpeg /opt/homebrew/bin/ffmpeg
```

The output directory must not exist. `--dry-run` prints commands without creating it. `--skip-import` uses the project's existing import cache. Default recordings are 20 seconds per route at 30 FPS, converted to looping 800-pixel GIFs at 12 FPS. `--seconds` and `--timeout` are configurable. AVI originals and logs are retained.

This uses the real main scene and the built-in `--demo --level=0/1/2` player. The demo charges, kicks, bails through physical contacts, and requests its normal single crashbreaker. It uses no injected actor transforms, impulses, scores, or edited game scripts. These are automated gameplay captures, not a human play session. Every route writes to its own isolated records file in the capture directory; your normal profile is not used.

The helper checks command exit status and movie existence. Those checks alone do not prove useful visuals: **watch every GIF** for map identity, meaningful action, correct rendering, readable framing, and undesirable UI exposure before copying it into `docs/gameplay/`. The CLI demo start/control path was exercised headlessly on all three maps in this sandbox; graphics and encoding actual Godot movies were not verified.

For a single route without the helper (after editor import), the underlying command is:

```sh
godot --path /path/to/skate-dismount --resolution 1280x800 \
  --fixed-fps 30 --disable-vsync \
  --write-movie /path/to/new-capture-directory/civic.avi --quit-after 600 \
  -- --demo --level=0 \
  --records-path=/path/to/new-capture-directory/civic-records.json
```

The directory must already exist for this direct command. Level indices are Civic=0, Market=1, Port=2. Do not add `--headless` to movie capture: on this Mac engine its headless display supports only the dummy renderer.
