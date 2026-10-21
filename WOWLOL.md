# wow.lol — the rebrand + new shell

This tree is GoldenNugget Mobile (AGPL-3.0) with a new name, a new icon, a
lavender theme, and — the part the previous IPA could not carry — a **new
navigation shell**: a brand bar and a horizontally scrolling row of individual
tabs across the top, instead of a sidebar on a tablet and a burger-with-a-list on
a phone.

Everything else is upstream: the same engine, the same protocols, the same
tweaks. Nothing about what the app *does* to a device changed.

---

## What changed

| Area | Before | After |
|---|---|---|
| Home Screen name (`CFBundleDisplayName`, `CFBundleName`) | GoldenNugget / GoldenNuggetMobile | **wow.lol** |
| Bundle ID | `com.awesomenull.goldennugget` | **`lol.wow.mobile`** |
| Name in the UI (home header, setup guide, About) | GoldenNugget | wow.lol |
| Navigation | `NavigationSplitView` + sidebar (iPad), sheet behind a burger (iPhone) | brand bar + scrolling tab strip, same on both |
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
* The strip lives in `.safeAreaInset(edge: .top)` on the `NavigationStack`, so it
  survives a push inside a tab (PosterBoard → Download Wallpapers) and the page
  never scrolls under it.
* The home page hides the navigation bar (its brand bar replaces it); every other
  page keeps its own inline bar, because that is where its actions live
  (`CommunityCatalogView` refreshes, `FilesView` renames and moves).
* `GoldenSidebarButton`, the `showSidebar` environment value, the sheet menu and
  `AppDestinationList` are gone, along with the six `.goldenSidebarButton()`
  call sites.
* The home header is now a device card (device line, pairing state, refresh) —
  the wordmark moved up into the shell, where every page shares it.

### Deliberately left alone

* Internal Swift symbols, `PRODUCT_NAME`, the `.xcodeproj`/scheme and the CI
  artifact are still named `GoldenNuggetMobile`. They are invisible on the
  device, and renaming them means editing every path in `scripts/build-ipa.sh`,
  the workflows and `Package.swift` — risk with no visual payoff. The Home
  Screen, the app switcher and the bundle ID all say wow.lol.
* On-disk locations (`Documents/GoldenNugget/Presets`, `goldennugget.log`).
  Renaming them would orphan presets, backups and logs that already exist.
* The upstream credit in Settings → About, the "port of" note and the Credits
  rows. This is an AGPL-3.0 work; the attribution stays, and the note now says
  plainly that wow.lol is a rebrand of GoldenNugget.

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
