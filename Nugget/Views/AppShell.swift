import SwiftUI
import UIKit

/// The app's shell: a brand bar and a row of tabs across the top, and the
/// selected page underneath.
///
/// This replaces the two shells that used to live here — a `NavigationSplitView`
/// with a sidebar on a tablet, and a sheet behind a burger on a phone.  Both of
/// those hid the app's own sections: on the phone every destination except Home
/// was two taps away, behind a button that said nothing about what was inside.
/// A strip of tabs has no such level: every section is one tap away, it is
/// visible the whole time, and it says what the app can do just by being looked
/// at.
///
/// The strip is a scrolling row rather than a fixed set of five, because the app
/// really does have thirteen sections and a `TabView` would have to hide eight of
/// them behind a "More" list — the same dropdown this change is removing, moved
/// to the bottom of the screen.  A horizontal scroll keeps every tab a first-class
/// tab; the row follows the selection so the active one is never off screen.
///
/// The home page is **not** re-created when a tab is picked.  It is the one view
/// that owns the run (Apply, progress, log) and the launch bootstrap, so it stays
/// in the hierarchy — faded out and untouchable — and the chosen page is drawn
/// over it.  A split view destroyed its detail on every selection; that is why
/// the original hoisted the selections up to `RootView`, and the same hazard is
/// here, one layer down: swapping the page out beneath a running apply would
/// drop its progress and re-run the auto-start.
enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case home
    case tweaks
    case presets
    case community
    case posterBoard
    case templates
    case wallpaperDownloads
    case statusBar
    case wallet
    case passcode
    case daemons
    case media
    case files
    case settings

    var id: String { rawValue }

    /// Whether this destination gets a tab of its own in the strip.
    ///
    /// The wallpaper downloader is the one that does not.  It is a **sub-page of
    /// PosterBoard**, not a section of its own: it edits the very selection the
    /// PosterBoard page shows and the home page's `Apply` delivers, so a second
    /// entry point to it in the strip is a duplicate tab one level above the page
    /// that owns it, and the page it duplicates is the one whose contents
    /// (`Wallpaper packs`) it fills.  `PosterBoardView` pushes it with a
    /// `NavigationLink` in that section, which is also where the desktop build
    /// reaches its downloader from (`wallpaper_downloader.py`).
    ///
    /// The case itself stays — a destination has to exist to be pushed — only its
    /// tab goes.
    var showsAsTab: Bool { self != .wallpaperDownloads }

    /// The page title, used by the navigation bar a **pushed** page draws above
    /// itself (and as the back button's label from one).
    var title: String {
        switch self {
        case .home: "wow.lol"
        case .tweaks: "Tweaks"
        case .presets: "Presets"
        case .community: "Community Catalog"
        case .posterBoard: "PosterBoard"
        case .templates: "Templates"
        case .wallpaperDownloads: "Download Wallpapers"
        case .statusBar: "Status Bar"
        case .wallet: "Wallet"
        case .passcode: "Passcode"
        case .daemons: "Daemons"
        case .media: "Media"
        case .files: "Files"
        case .settings: "Settings"
        }
    }

    /// The tab's own label.  Shorter than `title` on purpose: a strip is read at
    /// a glance and a long label costs the tab beside it its space.
    var tabTitle: String {
        switch self {
        case .home: "Home"
        case .tweaks: "Tweaks"
        case .presets: "Presets"
        case .community: "Community"
        case .posterBoard: "PosterBoard"
        case .templates: "Templates"
        case .wallpaperDownloads: "Download"
        case .statusBar: "Status"
        case .wallet: "Wallet"
        case .passcode: "Passcode"
        case .daemons: "Daemons"
        case .media: "Media"
        case .files: "Files"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .tweaks: "slider.horizontal.3"
        case .presets: "tray.2"
        case .community: "square.grid.2x2"
        case .posterBoard: "photo.artframe"
        case .templates: "slider.horizontal.below.rectangle"
        case .wallpaperDownloads: "square.and.arrow.down"
        case .statusBar: "antenna.radiowaves.left.and.right"
        case .wallet: "creditcard.fill"
        case .passcode: "lock.rectangle"
        case .daemons: "server.rack"
        case .media: "photo.on.rectangle"
        case .files: "folder"
        case .settings: "gearshape"
        }
    }
}

/// The app's palette, in one place.
///
/// The accent (`Color.accentColor`, from `Assets.xcassets/AccentColor`) is what
/// SwiftUI tints controls with; these are the two brand values the shell paints
/// itself with, and they are **fixed** rather than dynamic on purpose — white
/// text sits on them in both appearances, so a light/dark pair would only make
/// the label's contrast flicker.
enum WowBrand {
    /// Deep violet: the fill of the selected tab, and the darker end of the
    /// gradient.  #6B4AE6
    static let violet = Color(red: 0.42, green: 0.29, blue: 0.90)
    /// The lighter violet it fades to.  #8A5CF6
    static let violetLight = Color(red: 0.54, green: 0.36, blue: 0.96)
    /// The icon's lavender, used at low opacity as a wash behind the header.
    /// #B8A6F5
    static let lavender = Color(red: 0.72, green: 0.65, blue: 0.96)

    static let selectedTab = LinearGradient(colors: [violetLight, violet],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing)
}

struct RootView: View {
    /// Drives the device-identity poll: read on the way to the foreground, stopped
    /// on the way out.  Owned here because this is the one view that outlives every
    /// destination.
    @Environment(\.scenePhase) private var scenePhase

    /// The one-time setup gate.
    ///
    /// Observed rather than a second `@AppStorage` on the same key: the store is
    /// the flag, so finishing the guide has to lift the gate in the same run that
    /// set it. A mirror would have made the two disagree for exactly one frame —
    /// the frame where the user is looking at the button they just pressed.
    @ObservedObject private var firstRun = FirstRunSettings.shared
    /// Only used to hide the Wallet and Passcode tabs on a version that does not
    /// have the AirLift path; the same filter the old sidebar applied.
    @ObservedObject private var device = DeviceIdentityMonitor.shared

    /// The selected tab.  There is no second "current" to keep in sync: the strip
    /// and the page both read this one value.
    @State private var selection: AppDestination = .home
    /// Pushes *within* the selected tab (PosterBoard → Download Wallpapers).
    /// Switching tabs empties it, so a tab always opens on its own page.
    @State private var path: [AppDestination] = []

    /// Owned here, above the page, because the selections outlive the page that
    /// edits them: the home page's single Apply delivers what Tweaks, PosterBoard,
    /// Status Bar and Templates assemble, and the user has to be able to walk over
    /// to Apply without losing any of it.
    @State private var tweakSelection = TweakSelection()
    @State private var posterBoardSelection = PosterBoardSelection()
    @State private var statusBarSelection = StatusBarSelection()
    @State private var templateSelection = TemplateSelection()
    /// Launch auto-start bookkeeping, hoisted for the same reason as the
    /// selection: the flags guard a process-wide singleton
    /// (`startMinimuxer`'s lock rejects *concurrent* attempts only), so they
    /// have to outlive the view that reads them.  See `GoldenNuggetView`.
    @State private var didAutoStart = false
    /// "Reset pairing file" saying no, and **persisted on purpose**.
    ///
    /// It used to be `@State` alongside `didAutoStart`, which made the reset only
    /// half-work: `resetPairing()` cleared the record in memory and in
    /// `UserDefaults` but left `Documents/pairingfile.mobiledevicepairing` in
    /// place, and the restore path reads that file *first*.  So the next launch
    /// — which started again from "the user has not said no" — picked the
    /// record straight back up and re-paired a device the user had just
    /// unpaired, with nothing in the log to say why.
    ///
    /// Persisting the flag makes the reset stick without **deleting** anything:
    /// the record stays on disk untouched, and only the automatic load of it is
    /// suppressed.  That is deliberate — the pairing file may be the user's only
    /// copy, and a button labelled "Reset pairing file" must not destroy it.
    /// A successful import clears the flag again (see `loadPairingFile`), so
    /// importing after a reset restores the normal launch behaviour.
    @AppStorage(PairingRecord.Key.autoImportDisabled) private var autoImportDisabled = false

    var body: some View {
        Group {
            // The gate, not a sheet and not a pushed page: the app cannot do
            // anything at all until both prerequisites are in place, so the shell
            // behind it would be a menu of things that each fail identically.
            // A sheet would leave that same shell one swipe away.
            if firstRun.isComplete {
                shell
            } else {
                FirstRunView()
            }
        }
        // The native screens resolve every colour and text style from the system,
        // so the app follows the device appearance.
        // The device line and the version bounds it gates refresh themselves, and
        // the two ends of the app's life are the moments that matter: coming back
        // from the background is when a rebooted or swapped device is most stale,
        // and going out is when nothing should be talking to lockdown at all.
        // `.task(id:)` rather than an `onChange` because the id covers the first
        // appearance too — the app opens into `.active` and must start polling
        // without waiting for a change that may never come.
        //
        // The id carries the gate's state as well: while the guide is up there is
        // no pairing and no tunnel, so a lockdown poll can only log a device that
        // is not there yet — and finishing the guide has to start it, which a
        // scenePhase-only id would not notice until the next foreground.
        .task(id: firstRun.isComplete ? scenePhase : nil) {
            guard scenePhase == .active, firstRun.isComplete else {
                DeviceIdentityMonitor.shared.stop()
                return
            }
            DeviceIdentityMonitor.shared.start()
        }
        // The imported packs and the two picked files come back at launch, not
        // when the PosterBoard page is first opened: the Apply that delivers them
        // is on the home page, and a selection that is only loaded by *visiting*
        // its editor is a selection that can be missing while the button is
        // pressed.
        .task {
            // Seeded before the pages read the folder, so the Originals are in
            // the Presets list the first time it is opened.
            Originals.seedPresetsIfNeeded()
            posterBoardSelection.loadFromDisk()
            statusBarSelection.loadFromDisk()
            // No device version here on purpose: this runs at launch, possibly
            // before the tunnel is up, and a template that declares a version
            // range would then be dropped for the whole session.  The Templates
            // page re-reads with the version once it has one.
            templateSelection.loadFromDisk()
        }
    }

    // MARK: - Shell

    @ViewBuilder
    private var shell: some View {
        NavigationStack(path: $path) {
            ZStack {
                home
                    .opacity(selection == .home ? 1 : 0)
                    .allowsHitTesting(selection == .home)
                    .accessibilityHidden(selection != .home)
                if selection != .home {
                    page(selection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(for: AppDestination.self) { page($0) }
            // One title bar, the system's, on every page.  Home declares
            // "wow.lol" and every other page declares its own name, so the shell
            // draws nothing above a page at all: the old brand bar was a second
            // band saying what the title bar underneath already said.
            .toolbar(.visible, for: .navigationBar)
        }
        // The tabs are a bar along the bottom, not a row over the page.  Along
        // the top they were the tallest thing on the screen and every page paid
        // for them twice: once for the strip, once for the title bar underneath
        // it, before a single row was visible.  Down here the page keeps the
        // whole display, the bar floats over content that scrolls *under* it
        // (the inset stops any row from ending beneath the plate, so nothing is
        // ever hidden), and a thumb reaches it without moving the hand.
        //
        // Outside the stack, so the tabs survive a push inside one: the wallpaper
        // downloader is reached from PosterBoard and the dock is still there when
        // it is open.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WowTabDock(selection: selection,
                       destinations: tabs,
                       select: select)
        }
    }

    private var home: some View {
        GoldenNuggetView(tweakSelection: $tweakSelection,
                         posterBoardSelection: $posterBoardSelection,
                         statusBarSelection: $statusBarSelection,
                         templateSelection: $templateSelection,
                         didAutoStart: $didAutoStart,
                         autoImportDisabled: $autoImportDisabled)
    }

    /// The pages that get a tab, in the enum's order, minus the ones this device
    /// cannot use.
    ///
    /// Filtered rather than hardcoded: `allCases` is the enum's own
    /// exhaustiveness check, so a new destination cannot arrive without a tab
    /// (or without an explicit `showsAsTab == false`), and the AirLift test keeps
    /// Wallet and Passcode off a device whose version predicates cannot work.
    private var tabs: [AppDestination] {
        AppDestination.allCases.filter { destination in
            destination.showsAsTab
                && (!(destination == .wallet || destination == .passcode)
                    || !AirliftAvailability.isHidden(deviceVersion: device.current.version,
                                                     buildVersion: device.current.buildVersion))
        }
    }

    /// No back control of the shell's own: each page carries exactly one.
    ///
    /// A **pushed** page (PosterBoard → Download Wallpapers) is undone by the
    /// stack's back button, which the title bar already draws — the shell adding
    /// a second chevron is what used to put two of them side by side.  A **tab**
    /// is a switch rather than a push, so the stack has nothing behind it and
    /// draws nothing; `page(_:)` gives those pages one leading item that goes
    /// back to Home.

    private func select(_ destination: AppDestination) {
        // A second tap on the tab that is already open means "back to the top of
        // this section": drop whatever it pushed.
        if !path.isEmpty { path.removeAll() }
        guard destination != selection else { return }
        withAnimation(.easeInOut(duration: 0.18)) { selection = destination }
    }

    /// The page for a destination, plus the one piece of chrome the shell adds to
    /// it: the way back to Home.
    ///
    /// Attached here rather than drawn over the page, so it sits in the title bar
    /// beside the page's own actions instead of taking a row of its own, and only
    /// when the stack has no back button of its own to show (see the note above).
    @ViewBuilder
    private func page(_ destination: AppDestination) -> some View {
        content(destination)
            .toolbar {
                if path.isEmpty, destination != .home {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { select(.home) } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Home")
                                    .font(.system(size: 17))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to Home")
                    }
                }
            }
    }

    /// The pages, by destination.  Home is not among the pushed cases — it is the
    /// one view that stays alive — but the switch still has to be exhaustive.
    @ViewBuilder
    private func content(_ destination: AppDestination) -> some View {
        switch destination {
        case .home:
            EmptyView()
        case .tweaks:
            TweaksView(selection: $tweakSelection)
        case .presets:
            PresetManagerView(selection: $tweakSelection)
        case .community:
            CommunityCatalogView()
        case .posterBoard:
            PosterBoardView(selection: $posterBoardSelection)
        case .templates:
            TemplatesView(selection: $templateSelection)
        case .wallpaperDownloads:
            WallpaperDownloadsView(selection: $posterBoardSelection)
        case .statusBar:
            StatusBarView(selection: $statusBarSelection)
        case .wallet:
            WalletView()
        case .passcode:
            PasscodeThemeView()
        case .daemons:
            DaemonsView(selection: $tweakSelection)
        case .media:
            MediaView()
        case .files:
            FilesView()
        case .settings:
            SettingsView()
        }
    }
}

/// The tabs, along the bottom edge.
///
/// A pill of symbols rather than a stock `TabView`: this app has thirteen
/// sections and a stock bar would put eight of them behind "More" — the
/// dropdown the shell exists to remove, moved to the bottom of the screen.  The
/// row scrolls, keeps the active tab centred, and every section stays a
/// first-class tab.
///
/// The look is the system's: one sheet of material, no per-tab fill, no shadows
/// under the chips.  The active tab is told apart by tint and weight, the way a
/// system tab bar does it, instead of by a second colour scheme inside a bar
/// that is already glass.
private struct WowTabDock: View {
    let selection: AppDestination
    let destinations: [AppDestination]
    let select: (AppDestination) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 2) {
                    ForEach(destinations) { destination in
                        Button { select(destination) } label: {
                            chip(destination)
                        }
                        .buttonStyle(.plain)
                        .id(destination)
                        .accessibilityLabel(destination.title)
                        .accessibilityAddTraits(destination == selection ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .clipShape(Capsule(style: .continuous))
            .background { plate }
            // The active tab is never allowed to sit half off screen.  No
            // animation on the first pass: the row is scrolled to Home before
            // anyone sees it, so animating it would look like the app scrolling
            // itself on launch.
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .sensoryFeedback(.selection, trigger: selection)
    }

    /// A sheet of material with the faintest edge, so it reads as glass over
    /// the page rather than as another card laid on it.
    private var plate: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.16), radius: 16, y: 4)
    }

    private func chip(_ destination: AppDestination) -> some View {
        let active = destination == selection
        return VStack(spacing: 3) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 17, weight: active ? .semibold : .regular))
                .symbolVariant(active ? .fill : .none)
                .frame(height: 20)
            Text(destination.tabTitle)
                .font(.system(size: 10, weight: active ? .semibold : .medium))
                .lineLimit(1)
        }
        .foregroundStyle(active ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(minWidth: 58)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(active ? Color.accentColor.opacity(0.12) : .clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeOut(duration: 0.16), value: active)
    }
}
