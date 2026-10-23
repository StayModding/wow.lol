import SwiftUI
import UIKit

/// The app's shell: six sections along the bottom, the selected page above them,
/// and that page's siblings named in its own title bar.
///
/// This replaces the two shells that used to live here — a `NavigationSplitView`
/// with a sidebar on a tablet, and a sheet behind a burger on a phone — and then a
/// single strip of nineteen scrolling tabs, which had the opposite problem: every
/// screen was in the bar, but the bar had to be dragged to find any of them, so it
/// was a rail of labels rather than a map of the app.
///
/// Two levels, six and at most five: six sections that fit across a phone without
/// scrolling, and the pages of the section you are in, named in the title bar
/// where the page title would be.  Everything is two taps away and nothing is
/// hidden behind "More".  The page within a section is a switch, not a push, so a
/// section is not a stack of screens the user has to back out of.
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
    case conflicts
    case community

    case posterBoard
    case statusBar
    case passcode
    case templates
    case wallpaperDownloads

    case skipSetup
    case wallet
    case daemons
    case media
    case files

    case pairing
    case tunnel
    case diagnostics
    case history
    case log

    case settings

    var id: String { rawValue }

    /// Whether this destination is a **page** — drawn in the shell's body and
    /// named in the title bar — rather than something a page pushes.
    ///
    /// Two are pushed, not paged, and both for the same reason: they are details
    /// of a page, not peers of it.  The wallpaper downloader edits the very
    /// selection `PosterBoardView` shows, and the run log is the detail view of a
    /// record on **History**.  Pushing them keeps them reachable from the page
    /// that owns them without giving them a slot that would duplicate it.
    var isPage: Bool { self != .wallpaperDownloads && self != .log }

    /// The section this page belongs to.
    ///
    /// Exhaustive by construction: a case added to this enum cannot compile until
    /// it has been given a home here, so a new screen cannot arrive without a
    /// place in the bar.  Which pages a section holds — and in what order — is
    /// read off `allCases`, so this one switch is the whole grouping.
    var section: AppSection {
        switch self {
        case .home: .home
        case .tweaks, .presets, .conflicts, .community: .tweaks
        case .posterBoard, .statusBar, .passcode, .templates, .wallpaperDownloads: .look
        case .skipSetup, .wallet, .daemons, .media, .files: .tools
        case .pairing, .tunnel, .diagnostics, .history, .log: .device
        case .settings: .settings
        }
    }

    /// The page title, used by the navigation bar a **pushed** page draws above
    /// itself (and as the back button's label from one).
    var title: String {
        switch self {
        case .home: "wow.lol"
        case .tweaks: "Tweaks"
        case .conflicts: "Conflicts"
        case .presets: "Presets"
        case .community: "Community Catalog"
        case .posterBoard: "PosterBoard"
        case .wallpaperDownloads: "Download Wallpapers"
        case .templates: "Templates"
        case .statusBar: "Status Bar"
        case .skipSetup: "Skip Setup"
        case .wallet: "Wallet"
        case .passcode: "Passcode"
        case .daemons: "Daemons"
        case .media: "Media"
        case .files: "Files"
        case .history: "History"
        case .diagnostics: "Diagnostics"
        case .tunnel: "Tunnel"
        case .log: "Run Log"
        case .pairing: "Pairing"
        case .settings: "Settings"
        }
    }

    /// The tab's own label.  Shorter than `title` on purpose: a strip is read at
    /// a glance and a long label costs the tab beside it its space.
    var tabTitle: String {
        switch self {
        case .home: "Home"
        case .tweaks: "Tweaks"
        case .conflicts: "Clash"
        case .presets: "Presets"
        case .community: "Community"
        case .posterBoard: "PosterBoard"
        case .wallpaperDownloads: "Download"
        case .templates: "Templates"
        case .statusBar: "Status"
        case .skipSetup: "Skip"
        case .wallet: "Wallet"
        case .passcode: "Passcode"
        case .daemons: "Daemons"
        case .media: "Media"
        case .files: "Files"
        case .history: "History"
        case .diagnostics: "Diag"
        case .tunnel: "Tunnel"
        case .log: "Log"
        case .pairing: "Pairing"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .tweaks: "slider.horizontal.3"
        case .conflicts: "exclamationmark.triangle"
        case .presets: "tray.2"
        case .community: "square.grid.2x2"
        case .posterBoard: "photo.artframe"
        case .templates: "slider.horizontal.below.rectangle"
        case .wallpaperDownloads: "square.and.arrow.down"
        case .statusBar: "antenna.radiowaves.left.and.right"
        case .skipSetup: "forward.end"
        case .wallet: "creditcard.fill"
        case .passcode: "lock.rectangle"
        case .daemons: "server.rack"
        case .media: "photo.on.rectangle"
        case .files: "folder"
        case .history: "clock.arrow.circlepath"
        case .diagnostics: "stethoscope"
        case .tunnel: "point.3.connected.trianglepath.dotted"
        case .log: "text.alignleft"
        case .pairing: "dot.radiowaves.left.and.right"
        case .settings: "gearshape"
        }
    }
}

/// One slot in the bottom bar: a group of pages that belong together.
///
/// This is the shell's second level, and it exists because of arithmetic.  The
/// app has twenty-one screens.  A bar that draws twenty-one tabs along the bottom
/// of a phone is either a scrolling strip nobody can see whole — which is what
/// the last dock was, every section still one tap away but none of them findable
/// without dragging — or a stock `TabView` that hides thirteen of them behind
/// "More".  Six sections fit across a phone without scrolling, each named, each
/// one tap from anywhere; the pages inside a section are named in the title bar
/// of the page itself, so nothing is more than two taps away and nothing is
/// behind a word that says nothing.
///
/// The split is by what the user is doing, not by how the code is organised:
/// **Tweaks** is choosing switches, **Look** is making the device look different,
/// **Tools** is moving files and running one-off jobs, **Device** is what the
/// tunnel and the record of it say, and Home and Settings are themselves.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case tweaks
    case look
    case tools
    case device
    case settings

    var id: String { rawValue }

    /// The bar's label: six of these have to fit across the narrowest phone at
    /// 9 pt, so they are one short word each.
    var title: String {
        switch self {
        case .home: "Home"
        case .tweaks: "Tweaks"
        case .look: "Look"
        case .tools: "Tools"
        case .device: "Device"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .tweaks: "slider.horizontal.3"
        case .look: "paintpalette"
        case .tools: "wrench.and.screwdriver"
        case .device: "iphone"
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
    /// Pushes *within* the selected section (PosterBoard → Download Wallpapers).
    /// Switching sections empties it, so a section always opens on a page.
    @State private var path: [AppDestination] = []

    /// The page each section was last left on, so going Home and back to **Look**
    /// lands on PosterBoard rather than resetting to the section's first page.
    /// Deliberately *not* persisted: across a launch the app opens on Home, and a
    /// section entered fresh should start at the top of its own story.
    @State private var lastPage: [AppSection: AppDestination] = [:]

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
            // One title bar, the system's, on every page.  It is also the
            // section's second level: `page(_:)` puts the section's other pages in
            // its principal slot, so the band above a page names where you are and
            // what is next to it in one line, and the shell draws nothing above a
            // page at all — the old brand bar was a second band saying what the
            // title bar underneath already said.
            .toolbar(.visible, for: .navigationBar)
        }
        // Six sections along the bottom edge.  The last dock scrolled nineteen
        // chips through this strip: every section was in it, but finding one meant
        // dragging a rail under your thumb and reading labels as they went past,
        // and the bar was a navigation *problem* rather than a map.  Six fixed
        // slots are a map — the same six in the same order every time — and the
        // pages of a section are named in the title bar of the page you are on,
        // two taps at most.
        //
        // It is a bar that owns the bottom edge, not a capsule floating over the
        // page: the safe-area inset it installs is its own height, so a page's
        // last row ends above it rather than behind it.
        //
        // Outside the stack, so the bar survives a push inside a section: the
        // wallpaper downloader is reached from PosterBoard and the dock is still
        // there when it is open.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WowSectionDock(selection: selection.section,
                           sections: sections,
                           select: select)
        }
        // One place records where each section was left, so `select(_:)` has
        // something to come back to.
        .onChange(of: selection) { _, newValue in
            lastPage[newValue.section] = newValue
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

    /// The sections the bar draws: every one that has a page on this device.
    private var sections: [AppSection] {
        AppSection.allCases.filter { !pages(in: $0).isEmpty }
    }

    /// A section's pages, in the enum's own order, minus the ones this device
    /// cannot use.
    ///
    /// Filtered rather than listed: `allCases` is the enum's own exhaustiveness
    /// check, so a destination cannot arrive without a place in a section (the
    /// `section` switch has to answer for it), and the AirLift test keeps Wallet
    /// and Passcode off a device whose version predicates cannot work.
    private func pages(in section: AppSection) -> [AppDestination] {
        AppDestination.allCases.filter { destination in
            destination.section == section
                && destination.isPage
                && (!(destination == .wallet || destination == .passcode)
                    || !AirliftAvailability.isHidden(deviceVersion: device.current.version,
                                                     buildVersion: device.current.buildVersion))
        }
    }

    /// A tap on the bar.
    ///
    /// It opens the section on the page it was last left on — a section that
    /// always reset to its first page would make the bar a way to lose your place
    /// — and a tap on the section already open only closes whatever it pushed, so
    /// the bar never moves the page out from under a user who is reading it.
    private func select(_ section: AppSection) {
        if !path.isEmpty { path.removeAll() }
        let candidates = pages(in: section)
        guard let first = candidates.first else { return }
        let target = lastPage[section].flatMap { candidates.contains($0) ? $0 : nil } ?? first
        guard target != selection else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            selection = target
        }
    }

    /// A tap on one of the section's other pages, from the title bar.
    private func selectPage(_ destination: AppDestination) {
        if !path.isEmpty { path.removeAll() }
        guard destination != selection else { return }
        withAnimation(.easeInOut(duration: 0.18)) { selection = destination }
    }

    /// The page for a destination, plus the one piece of chrome the shell adds to
    /// it: the names of its section's other pages.
    ///
    /// Those names sit in the title bar's principal slot, which is where the page
    /// title would be — so the section's pages are named *instead of* repeating the
    /// page's own name, and the whole second level costs no height at all.  A page
    /// alone in its section (Home, Settings) and anything **pushed** keeps the
    /// ordinary title, which is also what gives a pushed page its back button.
    @ViewBuilder
    private func page(_ destination: AppDestination) -> some View {
        let strip = path.isEmpty ? pages(in: destination.section) : []
        content(destination)
            .toolbar {
                if strip.count > 1 {
                    ToolbarItem(placement: .principal) {
                        WowPageStrip(pages: strip,
                                     selection: destination,
                                     select: selectPage)
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
        case .conflicts:
            ConflictsView(selection: $tweakSelection)
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
        case .skipSetup:
            SkipSetupView()
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
        case .history:
            HistoryView()
        case .diagnostics:
            DiagnosticsView()
        case .tunnel:
            TunnelView()
        case .log:
            LogView()
        case .pairing:
            PairingView()
        case .settings:
            SettingsView()
        }
    }
}

/// The bottom bar: one slot per section, six across the width of a phone.
///
/// Six is what the app's structure actually has, and it is also what fits: at
/// 9 pt a label is under 40 pt wide, so six slots of about 60 pt sit on the
/// narrowest phone without scrolling, without shrinking, and without a "More".
///
/// The selected tile is **one view that moves**, not six that blink on and off —
/// a `matchedGeometryEffect` carries the violet tile from slot to slot, so the eye
/// follows the selection instead of hunting for where it went.  That is the whole
/// customisation: no second row of chrome, no per-tab rules, nothing that scrolls
/// under the thumb.
///
/// It is a bar that owns the bottom edge rather than a capsule floating over the
/// page.  A floating pill is *over* content by construction: the last row of a
/// list ran up against it and a keyboard shared space with it.  This bar installs
/// a safe-area inset equal to its own height, so a page's last row ends above it.
private struct WowSectionDock: View {
    let selection: AppSection
    let sections: [AppSection]
    let select: (AppSection) -> Void

    @Namespace private var tile

    var body: some View {
        HStack(spacing: 2) {
            ForEach(sections) { section in
                Button { select(section) } label: { slot(section) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)
                    .accessibilityAddTraits(section == selection ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .background { plate }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    /// A slot: the icon, the section's one word, and the tile that only the
    /// selected slot draws.  38 pt of drawing plus 6 of padding, so the bar is
    /// 44 pt taller than the page is not — the hit area is the full slot
    /// (`contentShape`), which on six equal columns is already past 44 wide.
    private func slot(_ section: AppSection) -> some View {
        let active = section == selection
        return VStack(spacing: 2) {
            Image(systemName: section.systemImage)
                .font(.system(size: 17, weight: active ? .semibold : .regular))
                .symbolVariant(active ? .fill : .none)
                .frame(height: 19)
            Text(section.title)
                .font(.system(size: 9, weight: active ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(active ? Color.white : Color.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background {
            if active {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(WowBrand.selectedTab)
                    .shadow(color: WowBrand.violet.opacity(0.32), radius: 7, y: 3)
                    .matchedGeometryEffect(id: "section", in: tile)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var plate: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .bottom)
    }
}

/// The other pages of the current section, in the title bar.
///
/// This is where the one-band layout comes from.  The principal slot of a
/// navigation bar *is* the page title, so naming the section's pages instead of
/// the page costs no height at all: the bar that already existed now carries the
/// page's name and its siblings' names, with the current one filled in.  A section
/// of one page has nothing to name and keeps the ordinary title.
///
/// The strip scrolls, because **Tools** has five pages and a phone at accessibility
/// text sizes has room for three; it keeps the current page centred so the one you
/// are on is never the one that is half cut off.
private struct WowPageStrip: View {
    let pages: [AppDestination]
    let selection: AppDestination
    let select: (AppDestination) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(pages) { destination in
                        Button { select(destination) } label: { pill(destination) }
                            .buttonStyle(.plain)
                            .id(destination)
                            .accessibilityLabel(destination.title)
                            .accessibilityAddTraits(destination == selection ? .isSelected : [])
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(height: 29)
        .frame(maxWidth: 460)
        .animation(.easeOut(duration: 0.16), value: selection)
    }

    private func pill(_ destination: AppDestination) -> some View {
        let active = destination == selection
        return HStack(spacing: 4) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(destination.tabTitle)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(active ? Color.white : Color.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(height: 25)
        .background {
            Capsule(style: .continuous)
                .fill(active ? AnyShapeStyle(WowBrand.selectedTab)
                             : AnyShapeStyle(Color.primary.opacity(0.07)))
        }
        .contentShape(Capsule(style: .continuous))
    }
}
