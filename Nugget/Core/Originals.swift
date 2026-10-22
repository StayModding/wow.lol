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
/// The `parallax` cuts are the "gyro" ones.  Their art is drawn on two planes,
/// foreground against an oversized background, and the caml the video path
/// writes places the layer off-centre and scaled — which is the travel
/// PosterKit's depth effect moves against.
struct OriginalClip: Identifiable, Hashable {
    enum Motion: String, Hashable {
        case parallax
        case animated

        var label: String {
            switch self {
            case .parallax: "Gyro"
            case .animated: "Animated"
            }
        }

        var blurb: String {
            switch self {
            case .parallax:
                "Two planes, so the art shifts against itself when the phone moves."
            case .animated:
                "A seamless loop — light, smoke and dust move across a still frame."
            }
        }
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
            selection.reverse = clip.motion == .parallax
            selection.foreground = false
            selection.calculationMode = .linear
            return "\(clip.artist) — \(clip.title) is selected. Press Apply on Home to put it on the Lock Screen."
        } catch {
            return error.localizedDescription
        }
    }

    /// Writes the five presets into the preset folder, once.
    ///
    /// Once, not "if missing": a preset the user deleted on purpose must stay
    /// deleted.  The flag is per install, and a reinstall seeds them again.
    static let seededKey = "wow.lol.originals.presets.v1"

    @discardableResult
    static func seedPresetsIfNeeded(defaults: UserDefaults = .standard) -> Int {
        guard !defaults.bool(forKey: seededKey) else { return 0 }
        var written = 0
        for pack in presets {
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
            written += 1
        }
        if written > 0 { defaults.set(true, forKey: seededKey) }
        return written
    }
}
