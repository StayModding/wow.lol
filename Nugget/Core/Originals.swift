import Foundation
import UIKit

/// The wow.lol Originals: five artist packs, every pixel generated for this app.
///
/// Two things ship per pack, and neither of them is a photograph or a likeness:
///
///   * a **wallpaper** — a short H.264 loop.  PosterBoard's video path turns it
///     into a CoreAnimation descriptor on the device itself, which is the only
///     way this app is able to deliver an animated wallpaper: a `.tendies` pack
///     carries a poster descriptor, and descriptors cannot be authored off a
///     device.  A video, on the other hand, is a documented input.
///   * a **preset** — a real tweak selection, written through the app's own
///     preset serialiser so it round-trips exactly like one the user saved.
///
/// The `parallax` and `gyro` cuts are the ones with depth.  Their art is drawn on
/// two planes, foreground against an oversized background, and the caml the
/// video path writes places the layer off-centre and scaled — which is the
/// travel PosterKit's depth effect moves against.  The `gyro` cut is the hybrid:
/// those planes *plus* the live motion, so the wallpaper breathes on its own and
/// shifts under the tilt.
struct OriginalClip: Identifiable, Hashable {
    enum Motion: String, Hashable {
        case parallax
        case animated
        case live
        case gyro

        var label: String {
            switch self {
            case .parallax: "Gyro"
            case .animated: "Animated"
            case .live: "Live"
            case .gyro: "Gyro + Live"
            }
        }

        var symbol: String {
            switch self {
            case .parallax: "gyroscope"
            case .animated: "play.circle.fill"
            case .live: "waveform"
            case .gyro: "move.3d"
            }
        }

        var blurb: String {
            switch self {
            case .parallax:
                "Two planes, so the art shifts against itself when the phone moves."
            case .animated:
                "A seamless loop — light, smoke and dust move across a still frame."
            case .live:
                "A breathing frame: the art pushes in and the light swells with it."
            case .gyro:
                "Both at once: the depth planes travel under the tilt while the frame itself breathes, sweeps and glows."
            }
        }

        /// Whether the cut carries the two-plane art the depth effect reads.
        var hasDepth: Bool { self == .parallax || self == .gyro }
    }

    let slug: String
    let artist: String
    let title: String
    let tag: String
    let motion: Motion
    /// `#RRGGBB`, for the card's chip and the preset's tag.
    let accent: String

    /// Both the mp4's name and the jpg's, which is why they share one.
    var id: String { "\(slug)-\(motion.rawValue)" }

    var clipURL: URL? { Originals.bundleURL(id, "mp4") }
    var thumbURL: URL? { Originals.bundleURL(id, "jpg") }
}

/// One artist's tweak preset, as a set of catalog ids rather than a JSON blob.
///
/// Deliberately not a checked-in `.json`: a hand-written document would have to
/// guess every `type` and default value in the catalog, and would drift from the
/// catalog the moment a tweak is renamed.  Setting the ids on a real
/// `TweakSelection` and serialising it with `GoldenNuggetPresets.document` means
/// the file this seeds is byte-for-byte the shape the app saves itself.
struct OriginalPreset: Identifiable, Hashable {
    let slug: String
    let name: String
    let blurb: String
    /// `TweakCatalog` ids, all enable-only toggles: a preset that cannot be
    /// undone from the UI is not something a theme should ship.
    let toggles: [String]

    var id: String { slug }
}

enum Originals {
    /// The bundle lookup, with the folder spellings as a fallback.
    ///
    /// Xcode copies these into the bundle root, which is the first lookup.  The
    /// other two are there because a build that treats `Originals/Clips` as a
    /// *folder* reference instead would leave the files one level down, and a
    /// missing wallpaper should be a wrong path, not missing artwork with no
    /// explanation.
    static func bundleURL(_ name: String, _ ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Clips")
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Thumbs")
    }

    /// The packs, in the order the generator numbers them.
    static let artists = ["2Pac", "Blamian", "Biggie", "Snoop", "Dr. Dre"]

    static let clips: [OriginalClip] = [
        OriginalClip(slug: "2pac", artist: "2Pac", title: "Thug Life",
                     tag: "West Side", motion: .parallax, accent: "#E23B3B"),
        OriginalClip(slug: "2pac", artist: "2Pac", title: "Crimson Field",
                     tag: "Bandana", motion: .animated, accent: "#E23B3B"),
        OriginalClip(slug: "blamian", artist: "Blamian", title: "No Skip",
                     tag: "Chrome", motion: .parallax, accent: "#22D3EE"),
        OriginalClip(slug: "blamian", artist: "Blamian", title: "Neon Horizon",
                     tag: "Night Drive", motion: .animated, accent: "#FF4FD8"),
        OriginalClip(slug: "biggie", artist: "Biggie", title: "King of New York",
                     tag: "Brooklyn", motion: .parallax, accent: "#C9A227"),
        OriginalClip(slug: "biggie", artist: "Biggie", title: "Gold Dust",
                     tag: "Velvet", motion: .animated, accent: "#C9A227"),
        OriginalClip(slug: "snoop", artist: "Snoop", title: "Dogg Pound",
                     tag: "Lowrider", motion: .parallax, accent: "#7BE495"),
        OriginalClip(slug: "snoop", artist: "Snoop", title: "Wire Wheel",
                     tag: "West Coast", motion: .animated, accent: "#7BE495"),
        OriginalClip(slug: "dre", artist: "Dr. Dre", title: "Still D.R.E.",
                     tag: "Compton", motion: .parallax, accent: "#E23B3B"),
        OriginalClip(slug: "dre", artist: "Dr. Dre", title: "Chrome Arcs",
                     tag: "Studio", motion: .animated, accent: "#E8ECF2"),
        OriginalClip(slug: "2pac", artist: "2Pac", title: "Cali Love",
                     tag: "Sunset", motion: .live, accent: "#E23B3B"),
        OriginalClip(slug: "blamian", artist: "Blamian", title: "Afterglow",
                     tag: "Neon", motion: .live, accent: "#22D3EE"),
        OriginalClip(slug: "biggie", artist: "Biggie", title: "Skyline",
                     tag: "Brooklyn", motion: .live, accent: "#C9A227"),
        OriginalClip(slug: "snoop", artist: "Snoop", title: "Long Beach",
                     tag: "Coast", motion: .live, accent: "#7BE495"),
        OriginalClip(slug: "dre", artist: "Dr. Dre", title: "Headphones",
                     tag: "Studio", motion: .live, accent: "#E8ECF2"),
        // The hybrids: the same art as the two cuts above, moving on its own
        // *and* under the tilt — a copy of the wallpaper, but not a copy of the
        // clip.  Every pack has one, in both designs.
        OriginalClip(slug: "2pac", artist: "2Pac", title: "Thug Life Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#E23B3B"),
        OriginalClip(slug: "blamian", artist: "Blamian", title: "No Skip Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#22D3EE"),
        OriginalClip(slug: "biggie", artist: "Biggie", title: "King of New York Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#C9A227"),
        OriginalClip(slug: "snoop", artist: "Snoop", title: "Dogg Pound Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#7BE495"),
        OriginalClip(slug: "dre", artist: "Dr. Dre", title: "Still D.R.E. Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#E8ECF2"),
        // The crest design: a monogram in a ring rather than the wordmark.  Two
        // cuts each — the gyro one for the tilt, the live one for the breathing
        // zoom — because a second design is a second wallpaper, not a second
        // animation of the same one.
        OriginalClip(slug: "2pac-b", artist: "2Pac", title: "Crest",
                     tag: "Monogram", motion: .parallax, accent: "#E23B3B"),
        OriginalClip(slug: "2pac-b", artist: "2Pac", title: "Crest After Dark",
                     tag: "Monogram", motion: .live, accent: "#E23B3B"),
        OriginalClip(slug: "blamian-b", artist: "Blamian", title: "Crest",
                     tag: "Monogram", motion: .parallax, accent: "#22D3EE"),
        OriginalClip(slug: "blamian-b", artist: "Blamian", title: "Crest After Dark",
                     tag: "Monogram", motion: .live, accent: "#22D3EE"),
        OriginalClip(slug: "biggie-b", artist: "Biggie", title: "Crest",
                     tag: "Monogram", motion: .parallax, accent: "#C9A227"),
        OriginalClip(slug: "biggie-b", artist: "Biggie", title: "Crest After Dark",
                     tag: "Monogram", motion: .live, accent: "#C9A227"),
        OriginalClip(slug: "snoop-b", artist: "Snoop", title: "Crest",
                     tag: "Monogram", motion: .parallax, accent: "#7BE495"),
        OriginalClip(slug: "snoop-b", artist: "Snoop", title: "Crest After Dark",
                     tag: "Monogram", motion: .live, accent: "#7BE495"),
        OriginalClip(slug: "dre-b", artist: "Dr. Dre", title: "Crest",
                     tag: "Monogram", motion: .parallax, accent: "#E8ECF2"),
        OriginalClip(slug: "dre-b", artist: "Dr. Dre", title: "Crest After Dark",
                     tag: "Monogram", motion: .live, accent: "#E8ECF2"),
        OriginalClip(slug: "2pac-b", artist: "2Pac", title: "Crest Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#E23B3B"),
        OriginalClip(slug: "blamian-b", artist: "Blamian", title: "Crest Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#22D3EE"),
        OriginalClip(slug: "biggie-b", artist: "Biggie", title: "Crest Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#C9A227"),
        OriginalClip(slug: "snoop-b", artist: "Snoop", title: "Crest Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#7BE495"),
        OriginalClip(slug: "dre-b", artist: "Dr. Dre", title: "Crest Live",
                     tag: "Gyro + Live", motion: .gyro, accent: "#E8ECF2"),
    ]

    static let presets: [OriginalPreset] = [
        OriginalPreset(slug: "2pac", name: "2Pac — Thug Life",
                       blurb: "Steady home screen: no icon fly-in, no page dots drifting with the tilt, a real signal reading in the status bar, and the outer glass effect on.",
                       toggles: ["SBDisableIconFlyInAnimation",
                                 "SBDisableParallaxOnPageControl",
                                 "SBShowRSSI",
                                 "SolariumEnableHomeScreenExteriorEffects"]),
        OriginalPreset(slug: "blamian", name: "Blamian — No Skip",
                       blurb: "Flat and quick: live icons off, full app names instead of truncated ones, and the glass drawn without its frost.",
                       toggles: ["SBDisableLiveIcons",
                                 "SBSuppressAppShortcutTruncation",
                                 "SolariumNoBlurReducedFrost"]),
        OriginalPreset(slug: "biggie", name: "Biggie — King of New York",
                       blurb: "Lock screen first: adaptive clock sizing, the batteries widget always offered, and the dock trimmed of recents.",
                       toggles: ["SBCoverSheetProportionalAdaptiveTime",
                                 "SBBatteryWidgetAlwaysAvailable",
                                 "SBRecentsEnabled",
                                 "SolariumEnableHomeScreenExteriorEffects"]),
        OriginalPreset(slug: "snoop", name: "Snoop — Dogg Pound",
                       blurb: "Quiet home screen: App Library and recents out of the dock, page dots still, longer press on notifications, signal reading shown.",
                       toggles: ["SBAppLibraryInDockEnabled",
                                 "SBRecentsEnabled",
                                 "SBDisableParallaxOnPageControl",
                                 "SBAlwaysAllowLongLookGesture",
                                 "SBShowRSSI"]),
        OriginalPreset(slug: "dre", name: "Dr. Dre — Still D.R.E.",
                       blurb: "The older glass drawing method, static icons, no fly-in, and Control Center that closes when you tap outside it.",
                       toggles: ["ForceSolariumFallback",
                                 "SBDisableLiveIcons",
                                 "SBDisableIconFlyInAnimation",
                                 "SBDismissControlCenterElsewhereOnPresentation"]),
        OriginalPreset(slug: "2pac-night", name: "2Pac — After Hours",
                       blurb: "Evening set: no icon fly-in, full app names, and the frost taken out of the glass so dark wallpapers stay dark.",
                       toggles: ["SBDisableIconFlyInAnimation",
                                 "SBSuppressAppShortcutTruncation",
                                 "SolariumNoBlurReducedFrost"]),
        OriginalPreset(slug: "blamian-night", name: "Blamian — Midnight Chrome",
                       blurb: "Neon on black: static icons, the outer glass effect on, and the old glass drawing method so nothing blooms.",
                       toggles: ["SBDisableLiveIcons",
                                 "SolariumEnableHomeScreenExteriorEffects",
                                 "ForceSolariumFallback"]),
        OriginalPreset(slug: "biggie-night", name: "Biggie — Night Shift",
                       blurb: "Lock screen quiet: adaptive clock sizing, batteries widget offered, recents out of the dock.",
                       toggles: ["SBCoverSheetProportionalAdaptiveTime",
                                 "SBBatteryWidgetAlwaysAvailable",
                                 "SBRecentsEnabled"]),
        OriginalPreset(slug: "snoop-night", name: "Snoop — Smoke Session",
                       blurb: "Nothing moves: page dots still, icon fly-in off, longer press on notifications.",
                       toggles: ["SBDisableParallaxOnPageControl",
                                 "SBDisableIconFlyInAnimation",
                                 "SBAlwaysAllowLongLookGesture"]),
        OriginalPreset(slug: "2pac-essentials", name: "2Pac — Essentials",
                       blurb: "The four that matter on a home screen: no fly-in, still page dots, the search button gone, real signal reading.",
                       toggles: ["SBDisableIconFlyInAnimation",
                                 "SBDisableParallaxOnPageControl",
                                 "SBHideSearchAffordance",
                                 "SBShowRSSI"]),
        OriginalPreset(slug: "2pac-quiet", name: "2Pac — Quiet Hours",
                       blurb: "Nothing to look at: low-battery and charging notices off, no return-to-app shortcut in the corner, lock-screen notifications hidden.",
                       toggles: ["SBHideLowPowerAlerts",
                                 "SBHideACPower",
                                 "SBNeverBreadcrumb",
                                 "SBHideNotifications"]),
        OriginalPreset(slug: "blamian-clean", name: "Blamian — Clean Slate",
                       blurb: "Every outline and shadow taken off the glass: icon outlines, folder shine, widget shine, search-button shadow.",
                       toggles: ["DisableIconGlassOutline",
                                 "DisableFolderSpecular",
                                 "DisableWidgetSpecular",
                                 "ExcludeSearchShadow"]),
        OriginalPreset(slug: "blamian-depth", name: "Blamian — Depth",
                       blurb: "Glass that answers the light: lighting from the phone's angle, stronger reflections, softer diffusion, and still reflections.",
                       toggles: ["SolariumUseDisplayAngle",
                                 "ForceEnhancedSpeculars",
                                 "SolariumIncreasedDiffusion",
                                 "DisableSpecularMotion"]),
        OriginalPreset(slug: "biggie-dock", name: "Biggie — Dock Only",
                       blurb: "A dock that holds apps: recents and the App Library out, its glass and shine taken off.",
                       toggles: ["SBRecentsEnabled",
                                 "SBAppLibraryInDockEnabled",
                                 "NoLiquidDock",
                                 "DisableDockSpecular"]),
        OriginalPreset(slug: "biggie-clock", name: "Biggie — Clockwork",
                       blurb: "Lock screen clock: adaptive sizing, no glass, no second hand on the clock icon, and the motion shortcuts off.",
                       toggles: ["SBCoverSheetProportionalAdaptiveTime",
                                 "NoLiquidClock",
                                 "DisableSecondsHand",
                                 "SBCoverSheetDisableDeviceMotionEffectPerformanceOptimizations"]),
        OriginalPreset(slug: "snoop-focus", name: "Snoop — Focus",
                       blurb: "One app at a time: notifications and the Dynamic Island gone, no return-to-app chip, no Home Screen search button.",
                       toggles: ["SBHideNotifications",
                                 "HideDICompletely",
                                 "SBNeverBreadcrumb",
                                 "SBHideSearchAffordance"]),
        OriginalPreset(slug: "snoop-standby", name: "Snoop — StandBy",
                       blurb: "StandBy on a desk: it runs without a charger, wakes to a tap, and the image brightness limit comes off.",
                       toggles: ["AMAmbientIgnoreBatteryCharging",
                                 "SBAlwaysOnTapToInteract",
                                 "SBUseAlwaysOnBrightnessCurve",
                                 "SBEnforceOverallAPLLimit"]),
        OriginalPreset(slug: "dre-mono", name: "Dre — Monochrome",
                       blurb: "Flat and quiet: flat icons, no reflections anywhere, no edge distortion, no icon outlines.",
                       toggles: ["UseFlatIconsEverywhere",
                                 "DisableSpecularEverywhere",
                                 "DisableOuterRefraction",
                                 "DisableIconGlassOutline"]),
        OriginalPreset(slug: "dre-frame-rate", name: "Dre — Frame Rate",
                       blurb: "Less work per frame: no live icons, no widget snapshotting, and temporary screen images released as soon as they are done.",
                       toggles: ["SBDisableLiveIcons",
                                 "SBWidgetSnapshottingEnabled",
                                 "SBDisableAsyncRenderingSurfaceRetention"]),
        OriginalPreset(slug: "2pac-studio", name: "2Pac — Studio Session",
                       blurb: "Everything still, nothing blooming: parity for the page dots and the icons, and the glass drawn flat.",
                       toggles: ["SBDisableParallaxOnPageControl",
                                 "SBDisableLiveIcons",
                                 "ForceSolariumFallback"]),
        OriginalPreset(slug: "blamian-bright", name: "Blamian — Daylight",
                       blurb: "Full glass: the outer home-screen effect on, brighter highlights kept, icons frozen in place.",
                       toggles: ["SolariumEnableHomeScreenExteriorEffects",
                                 "SBDisableIconFlyInAnimation"]),
        OriginalPreset(slug: "biggie-royal", name: "Biggie — Royal",
                       blurb: "Dock and lock screen: recents out, batteries widget offered, clock sizing adaptive.",
                       toggles: ["SBRecentsEnabled",
                                 "SBBatteryWidgetAlwaysAvailable",
                                 "SBCoverSheetProportionalAdaptiveTime"]),
        OriginalPreset(slug: "snoop-cruise", name: "Snoop — Cruise",
                       blurb: "Signal and shortcuts: the reading shown, long app names, longer notification presses.",
                       toggles: ["SBShowRSSI",
                                 "SBSuppressAppShortcutTruncation",
                                 "SBAlwaysAllowLongLookGesture"]),
        OriginalPreset(slug: "dre-master", name: "Dre — Master",
                       blurb: "Reference chain: no frost, no icon motion, Control Center closes when you tap away.",
                       toggles: ["SolariumNoBlurReducedFrost",
                                 "SBDisableIconFlyInAnimation",
                                 "SBDismissControlCenterElsewhereOnPresentation"]),
        OriginalPreset(slug: "dre-night", name: "Dre — In the Lab",
                       blurb: "Studio quiet: signal reading shown, Control Center closes when you tap outside it, static icons.",
                       toggles: ["SBShowRSSI",
                                 "SBDismissControlCenterElsewhereOnPresentation",
                                 "SBDisableLiveIcons"]),
    ]

    /// Thumbnails, decoded once.  A `List` row is re-evaluated on every scroll
    /// frame, and decoding a 540×960 JPEG in `body` is how a scrolling gallery
    /// turns into a slideshow.
    private static var thumbs: [String: UIImage] = [:]

    static func thumbnail(for clip: OriginalClip) -> UIImage? {
        if let cached = thumbs[clip.id] { return cached }
        guard let url = clip.thumbURL, let image = UIImage(contentsOfFile: url.path) else { return nil }
        thumbs[clip.id] = image
        return image
    }

    /// Puts a clip on the PosterBoard selection, ready for the Apply on Home.
    ///
    /// The video path copies one file into the app's container, so the previous
    /// choice is cleared first: leaving them behind would grow the container by
    /// a few megabytes per tap, and the page has a "clear" button that does the
    /// same thing on purpose.
    @discardableResult
    static func install(_ clip: OriginalClip,
                        into selection: inout PosterBoardSelection) -> String {
        guard let url = clip.clipURL else {
            return "\(clip.title) is missing from the app bundle — reinstall the build."
        }
        do {
            selection.video = try PosterBoard.store(url, in: PosterBoard.videoDirectory)
            selection.thumbnail = nil
            selection.loop = true
            selection.reverse = clip.motion.hasDepth
            selection.foreground = false
            selection.calculationMode = .linear
            // A gyro cut with the depth travel turned off is a flat poster with
            // motion baked in; picking one is a request for the tilt as well.
            if clip.motion.hasDepth { selection.depth = .deep }
            return "\(clip.artist) — \(clip.title) is selected. Press Apply on Home to put it on the Lock Screen."
        } catch {
            return error.localizedDescription
        }
    }

    /// Writes the presets into the preset folder, once each.
    ///
    /// Per preset, not per install: the list grows with every build, and a single
    /// "have I seeded yet" flag meant a pack added later never reached a device
    /// that had already run an older build.  A preset the user deleted is still
    /// left deleted, because its slug stays in the seeded set.
    static let seededKey = "wow.lol.originals.presets.v2"

    /// The first release's flag, when the list was ten presets and the record was
    /// one boolean.  An install that has it is treated as having seeded exactly
    /// those ten, so the ones added since are the only ones it is missing.
    static let legacySeededKey = "wow.lol.originals.presets.v1"

    private static let legacySlugs: Set<String> = [
        "2pac", "2pac-night", "blamian", "blamian-night", "biggie",
        "biggie-night", "snoop", "snoop-night", "dre", "dre-night",
    ]

    @discardableResult
    static func seedPresetsIfNeeded(defaults: UserDefaults = .standard) -> Int {
        var seeded = Set(defaults.stringArray(forKey: seededKey) ?? [])
        if defaults.bool(forKey: legacySeededKey) {
            seeded.formUnion(legacySlugs)
        }
        var written = 0
        for pack in presets where !seeded.contains(pack.slug) {
            var selection = TweakSelection()
            for id in pack.toggles {
                guard let spec = TweakCatalog.byID[id] else { continue }
                selection.setOn(true, for: spec)
            }
            let document = GoldenNuggetPresets.document(for: selection,
                                                        deviceModel: "",
                                                        iosVersion: "",
                                                        description: pack.blurb,
                                                        tags: ["originals", pack.slug],
                                                        createdAt: nil)
            guard let data = try? JSONSerialization.data(withJSONObject: document,
                                                         options: [.prettyPrinted, .sortedKeys]),
                  (try? data.write(to: GoldenNuggetPresets.fileURL(for: pack.name),
                                   options: .atomic)) != nil else { continue }
            seeded.insert(pack.slug)
            written += 1
        }
        if written > 0 {
            defaults.set(seeded.sorted(), forKey: seededKey)
            defaults.set(true, forKey: legacySeededKey)
        }
        return written
    }
        return written
    }
}
