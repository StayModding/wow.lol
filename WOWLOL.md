# wow.lol — the rebrand + new shell

This tree is GoldenNugget Mobile (AGPL-3.0) with a new name, a new icon, a
lavender theme, and — the part the previous IPA could not carry — a **new
navigation shell**: a horizontally scrolling row of individual tabs floating along
the bottom edge, instead of a sidebar on a tablet and a burger-with-a-list on a
phone.

Everything else is upstream: the same engine, the same protocols, the same
tweaks. Nothing about what the app *does* to a device changed.

---

## What changed

| Area | Before | After |
|---|---|---|
| Home Screen name (`CFBundleDisplayName`, `CFBundleName`) | GoldenNugget / GoldenNuggetMobile | **wow.lol** |
| Bundle ID | `com.awesomenull.goldennugget` | **`lol.wow.mobile`** |
| Name in the UI (home header, setup guide, About) | GoldenNugget | wow.lol |
| Navigation | `NavigationSplitView` + sidebar (iPad), sheet behind a burger (iPhone) | scrolling tab dock along the bottom, same on both |
| Sections on screen at once | 1 (the selected one), 8 behind a dropdown | all 13, one tap away, always visible |
| Tint / accent | system blue (no accent asset) | `AccentColor` — `#6B4AE6` light, `#A78BFF` dark |
| App icon | Icon Composer stack (glass over a gold gradient) | `AppIcon.appiconset`, 1024 with light / dark / tinted renditions |
| In-app logo (`Logo@1x/@2x`) | gold nugget | white W on lavender |
| Local-network permission text | "GoldenNugget publishes…" | "wow.lol publishes…" |

### The shell (`Nugget/Views/AppShell.swift`)

* `AppDestination` keeps its cases, gains `tabTitle` (short label for the strip)
  and `showsAsTab` (the wallpaper downloader stays a sub-page of PosterBoard).
  Order, icons, titles and the AirLift filter for Wallet/Passcode are unchanged.
* `RootView` owns `selection` and one `path` for pushes *inside* a tab. Tapping a
  tab empties the path, so a tab always opens on its own page; tapping the tab
  that is already open drops whatever it pushed.
* The home page is **not** re-created when a tab changes. It stays in the
  hierarchy — faded out, hit-testing off — and the chosen page is drawn over it.
  Home owns the run (Apply, progress, log) and the launch auto-start; swapping it
  out mid-run would drop the progress and re-run the bootstrap. This is the same
  hazard the old shell had, handled one layer down.
* The dock lives in `.safeAreaInset(edge: .bottom)` on the `NavigationStack`, so it
  survives a push inside a tab (PosterBoard → Download Wallpapers). Content
  scrolls *under* the plate and the inset keeps rows from ending beneath it.
  It sat along the top in the first build, where it stacked above every page's
  own title bar and pushed the first row of every page a hand's width down.
* Exactly one back control per page: a **pushed** page uses the stack's own back
  button, and a **tab** gets one leading `‹ Home` item in its title bar (the
  shell's chevron used to sit in the brand bar, above the title bar that already
  had one).
* No custom header at all: Home's title bar says `wow.lol`, every other page
  names its own section.  (A brand bar of the shell's own sat here for two
  builds; the second pass removed it — see below.)
* The home page's device line and its connection verdict are one card now — the
  device name, a coloured dot and "Supported!" / "Partially Supported" /
  "Not connected" — instead of a card containing one centred word.
* The home page hides the navigation bar (its brand bar replaces it); every other
  page keeps its own inline bar, because that is where its actions live
  (`CommunityCatalogView` refreshes, `FilesView` renames and moves).
* `GoldenSidebarButton`, the `showSidebar` environment value, the sheet menu and
  `AppDestinationList` are gone, along with the six `.goldenSidebarButton()`
  call sites.
* The home header is now a device card (device line, pairing state, refresh) —
  the wordmark moved up into the shell, where every page shares it.

### wow.lol Originals (`Nugget/Core/Originals.swift`)

Five artist packs — 2Pac, Blamian, Biggie, Snoop and Dr. Dre — in **two designs
and four cut types**: thirty-five wallpapers and twenty-five presets.
Everything is generated for this app by `scripts/gen-originals.py`: typographic
posters, no photographs and no likenesses, drawn with Pillow and encoded to
H.264.

* **Two designs per pack.** *Wordmark* sets the pack name huge over its motif;
  *Crest* puts one initial in a ring of tick marks with the name underneath, so
  the second wallpaper looks like a second wallpaper rather than a recolour.
* **Four cut types**, and every pack has them:
  * **Gyro** — art drawn on two planes, foreground against an oversized
    background, drifting against each other;
  * **Animated** — one plane, with smoke, a light sweep and a rotating badge;
  * **Live** — a breathing push-in with a glow that swells with it;
  * **Gyro + Live** — the hybrid: the two planes *and* the breathing frame in
    the same clip, which is what makes the wallpaper move on its own and under
    the tilt.  A copy of the wallpaper, not a copy of the clip.
* **Depth travel** (`PosterBoardDepth`, `PosterBoardView` → *Depth travel*).  iOS
  only parallaxes a caml layer that is **larger** than the document, so the
  layer scale is now `cover × depth`: `Flat` 1.0 (the reference's
  `bounds_scale`), `Subtle` 1.10, `Deep` 1.22 — and `Deep` is the default,
  because at 1.0 the depth effect has nothing to move.  The cost is a tighter
  crop, which the art is drawn to survive: the sleeve frame sits 92 px in from
  a 1080 px edge, so a 22 % overscan never reaches it.
* **Wallpapers** are 3-second 1080×2340 loops at 24 fps in `Originals/Clips`,
  with 540×1170 thumbnails in `Originals/Thumbs`.  2340 is 19.5:9 — the shape of
  a modern iPhone screen — because the caml scales these frames by `cover`: at
  1080×1920 every wallpaper was blown up 1.33× against an iPhone 15 Pro before
  the depth overscan was applied on top of that.  They are **videos**, not
  `.tendies` packs, because a pack carries a poster descriptor and descriptors
  can only be built on a device — a video is an input the app already knows how
  to turn into one (`PosterBoardVideo`).  Tapping a card copies the clip into the
  app's container as the video choice; PosterBoard's Apply delivers it.
* **Presets**: five per artist — a day set, a night set, and three narrower ones
  (essentials, dock, focus, glass, StandBy…).  Each is seeded into
  `Documents/wow.lol/Presets` by `Originals.seedPresetsIfNeeded`, written
  through `GoldenNuggetPresets.document(for:)` from a real `TweakSelection`, so
  they are byte-identical in shape to a preset the app saves itself.  Seeding is
  **per preset slug** (`wow.lol.originals.presets.v2`, with the first release's
  boolean read as "the original ten"): a pack added in a later build reaches an
  install that has already run an older one, and a preset the user deleted stays
  deleted.  Enable-only toggles throughout — a theme that cannot be undone is
  not a preset.
* Regenerate with `python scripts/gen-originals.py` (needs Pillow, numpy and
  ffmpeg — `imageio-ffmpeg` supplies the encoder); `--probe` writes one still per
  pack instead of encoding, `--design a|b`, `--variant` and `--only` narrow it.

### Design, second pass

The first shell was decoration on top of decoration: a brand bar over a tab
strip over every page's own title bar.  What is left is the system's own
furniture plus one bar of the app's:

* **One title bar per page**, drawn by the navigation stack.  Home's says
  `wow.lol`; the brand bar is gone.
* **The dock** is a single sheet of `.ultraThinMaterial` with no per-tab fill and
  no shadows under the chips.  The active tab is tinted and semibold with its
  symbol filled, the way a system tab bar marks one, and the label sits under the
  icon instead of beside it.

### Four more pages (`Nugget/Views/ToolPages.swift`)

The dock now carries nineteen sections.  What was added is not new machinery —
it is machinery that already existed in the core and had no page:

* **Originals** — the five artist packs, one section each, at a size where the
  artwork reads.  Choosing one only sets the video choice; PosterBoard's Apply
  still delivers it, and the page has a button that goes there.
* **History** — `ApplyHistory`'s own record list, newest first, with the device
  each operation went to and the error if it failed.  Clearable.
* **Diagnostics** — the device line, whether the protective backup is encrypted,
  and `Diagnostics.report()` on the page with Copy and Share.
* **Log** — the run log full screen, selectable, shareable, clearable.

### The artefact

The workflow's artifact and the IPA are both named **`wowser-ios`** now
(`wowser-ios.ipa`).  The bundle, its executable and the Xcode project keep their
names: `lol.wow.mobile` is what an upgrade has to match, and renaming the target
would be a different app with a different container.

### Deliberately left alone

* Internal Swift symbols, `PRODUCT_NAME`, the `.xcodeproj`/scheme and the CI
  artifact are still named `GoldenNuggetMobile`. They are invisible on the
  device, and renaming them means editing every path in `scripts/build-ipa.sh`,
  the workflows and `Package.swift` — risk with no visual payoff. The Home
  Screen, the app switcher and the bundle ID all say wow.lol.
* The community catalog's URLs (`goldennugget-team.github.io`). That is a live
  service this feature reads, not a label; renaming the host would disable the
  catalog rather than rebrand it.
* The Swift type names. `GoldenNuggetEngine`, `GoldenNuggetPresets`,
  `GoldenNuggetError` and the module itself are compiled identity, and the app
  has 100k symbols that reference them.

### What the rebrand did rename

Every user-visible mention is gone: the About credit and note, the `credits`
row, the log file (`wow.lol.log`, and the two share rows that name it), the
error strings, the preset format tag, and the wireless-pairing host name the
setup guide tells the user to tap ("Pair with wow.lol"). The private folder
moved from `Documents/GoldenNugget/` to `Documents/wow.lol/`, with a one-time
move at launch so existing presets and the apply history keep working.

Exports are written with a new `format` tag but the old one is still accepted
on import, so desktop-made presets keep loading.

The AGPL-3.0 licence and the copyright headers in the source are untouched:
that attribution is the licence's condition, not a string in the UI.

---

## Build

Two ways, both producing an **unsigned** IPA that a sideloader signs.

### A. GitHub Actions (no Mac needed)

`.github/workflows/build.yml` already builds on every push:

```bash
cd C:\wowsrc            # this tree
git add -A && git commit -m "wow.lol: tabs, palette, icon, name"
git remote add mine https://github.com/<you>/<repo>.git
git push -u mine HEAD:main
```

Then open **Actions → Build IPA → the run → Artifacts → GoldenNuggetMobile.zip**,
unzip it and sign `GoldenNuggetMobile.ipa` with Sideloadly / SideStore / Feather /
ESign / TrollStore.

### B. Xcode on a Mac

```bash
xcodegen generate          # project.pbxproj is generated from project.yml
./scripts/build-ipa.sh Release
# → build/GoldenNuggetMobile.ipa
```

`xcodebuild` refuses to build `project.yml` without XcodeGen 2.46 (the manifest's
header explains why); `brew install xcodegen` gets it.

---

## What was verified here, and what was not

This machine is Windows: there is no Swift toolchain, no `actool`, no iOS SDK, so
**the tree has not been compiled**. What was checked:

* every one of the 102 Swift files still parses structurally (balanced
  braces/parens/brackets, no unterminated string/comment/raw string) — this
  catches the class of mistake a hand edit makes, not type errors;
* `project.yml` is valid YAML and every path it lists exists;
* the three icon PNGs decode at 1024×1024 with no alpha, and `Contents.json`
  matches Xcode's single-size appiconset format;
* `Info.plist` parses, and the display name, bundle name and local-network string
  are the new ones;
* the workflow's `actool` invocation no longer passes the deleted `.icon`
  document.

The first real build is CI's; treat a green run plus a launch on the device as the
only proof that this is good. If something fails to compile, it will be in
`Nugget/Views/AppShell.swift` — that is the only file with new SwiftUI in it.

## Licence

AGPL-3.0, unchanged. If you distribute a build of this, the source has to go with
it.
