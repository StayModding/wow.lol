import SwiftUI
import UIKit

/// The tool pages: Originals, History, Diagnostics, Log, Pairing, About.
///
/// Each one is a native `List` of system sections.  The app's own chrome is the
/// dock along the bottom and nothing else, so a tool page should look like a
/// page of Settings rather than like a mockup.
///
/// Everything here already existed in the core — `ApplyHistory`, `Diagnostics`,
/// `RunLog`, `PairingRecord`, `WirelessPairing`, `Originals` — and had no surface
/// of its own.  Home was carrying the diagnostics card, the pairing card and a
/// log preview, which made the one page with the Apply button on it also the
/// page you had to scroll to reach everything else.

// MARK: - Originals

struct OriginalsView: View {
    @Binding var posterBoardSelection: PosterBoardSelection
    /// Jump to PosterBoard, so "choose a wallpaper" ends with the Apply.
    let openPosterBoard: () -> Void

    var body: some View {
        List {
            Section {
                NativeNote("Poster art drawn for wow.lol — no photographs, no likenesses. "
                    + "Gyro cuts are drawn on two planes, so the art moves against itself when the phone "
                    + "tilts; animated cuts loop; live cuts breathe. Choosing one here only sets the video "
                    + "choice — PosterBoard's Apply is what puts it on the Lock Screen.")
            }
            Section {
                OriginalsShelf(posterBoardSelection: $posterBoardSelection)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                Button("Open PosterBoard", action: openPosterBoard)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Originals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The artist shelf, with no page of its own.
///
/// One view for two places: the Originals page, and PosterBoard's **Wowser**
/// tab, which is where the packs sit next to the Apply that installs them.  A
/// second copy of these cards for the second place is how the two drift apart.
struct OriginalsShelf: View {
    @Binding var posterBoardSelection: PosterBoardSelection
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Originals.artists, id: \.self) { artist in
                artistShelf(artist)
            }

            if let status {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// One artist, one design row per design.
    ///
    /// The packs ship seven cuts each now — a wordmark set and a crest set — and
    /// a single uncontrolled row of seven made the second design read as three
    /// more variations of the first.  Each design gets its own labelled row, so
    /// the shelf says what it is showing.
    private func artistShelf(_ artist: String) -> some View {
        let clips = Originals.clips.filter { $0.artist == artist }
        var designs: [String] = []
        var groups: [String: [OriginalClip]] = [:]
        for clip in clips {
            if groups[clip.slug] == nil { designs.append(clip.slug) }
            groups[clip.slug, default: []].append(clip)
        }
        let packs = presets(for: artist)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(artist)
                    .font(.system(size: 16, weight: .semibold))
                Text(tag(artist))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(clips.count) wallpapers")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)

            ForEach(designs, id: \.self) { slug in
                VStack(alignment: .leading, spacing: 7) {
                    Text(designTitle(slug))
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(groups[slug] ?? []) { clip in
                                Button { install(clip) } label: { card(clip) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            if let first = packs.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(packs.count == 1 ? first.name
                                          : "\(first.name) and \(packs.count - 1) more")
                        .font(.system(size: 13, weight: .semibold))
                    Text(first.blurb)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func designTitle(_ slug: String) -> String {
        slug.hasSuffix("-b") ? "Crest — one initial, ringed" : "Wordmark"
    }

    /// The presets that belong to an artist: the base slug plus its variations
    /// (`2pac`, `2pac-night`, `2pac-quiet` …), which is how the slugs are built.
    private func presets(for artist: String) -> [OriginalPreset] {
        let base = Originals.clips.first { $0.artist == artist }?.slug ?? ""
        return Originals.presets.filter { $0.slug == base || $0.slug.hasPrefix(base + "-") }
    }

    private func tag(_ artist: String) -> String {
        Originals.clips.first { $0.artist == artist }?.tag ?? ""
    }

    private func install(_ clip: OriginalClip) {
        status = Originals.install(clip, into: &posterBoardSelection)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func card(_ clip: OriginalClip) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let image = Originals.thumbnail(for: clip) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(colors: [Color.secondary.opacity(0.32), Color.secondary.opacity(0.10)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
                .frame(width: 150, height: 325)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
                }

                Label(clip.motion.label.uppercased(), systemImage: clip.motion.symbol)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.38), in: Capsule())
                    .padding(9)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(clip.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(clip.tag).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
    }
}

// MARK: - History

/// What the app has done to the device: `ApplyHistory`'s own record list.
struct HistoryView: View {
    @State private var records: [ApplyHistory.Record] = []

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List {
            if records.isEmpty {
                Section {
                    NativeNote("Nothing applied yet. Every Apply and every Reset — successful or not — is "
                        + "recorded here, newest first, with the device it went to.")
                }
            } else {
                Section("Operations") {
                    ForEach(Array(records.enumerated().reversed()), id: \.offset) { _, record in
                        row(record)
                    }
                }
                Section {
                    Button("Clear history", role: .destructive) {
                        ApplyHistory.clear()
                        records = []
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .task { records = ApplyHistory.load() }
    }

    private func row(_ record: ApplyHistory.Record) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: record.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(record.success ? .green : .orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.mode == "reset" ? "Reset" : "Apply")
                        .font(.system(size: 15, weight: .semibold))
                    if !record.model.isEmpty || !record.device.isEmpty {
                        Text(record.model.isEmpty ? record.device : "\(record.model) · iOS \(record.ios)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(Self.stamp.string(from: Self.date(from: record.timestamp) ?? Date()))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if !record.error.isEmpty {
                    Text(record.error)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private static func date(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        return formatter.date(from: text)
    }
}

// MARK: - Diagnostics

/// The lockdown report, on a page with a share button.
struct DiagnosticsView: View {
    @ObservedObject private var device = DeviceIdentityMonitor.shared
    @State private var report = ""
    @State private var encryption: Bool?
    @State private var busy = false

    var body: some View {
        List {
            Section("Device") {
                LabeledContent("Model", value: device.current.productType.isEmpty
                               ? "unknown" : device.current.productType)
                LabeledContent("iOS", value: device.current.version.isEmpty
                               ? "unknown" : device.current.version)
                if !device.current.buildVersion.isEmpty {
                    LabeledContent("Build", value: device.current.buildVersion)
                }
                LabeledContent("Backup encryption") {
                    Text(encryption.map { $0 ? "on" : "off" } ?? "—")
                        .foregroundStyle(encryption == false ? .orange : .secondary)
                }
            }

            Section("Report") {
                if report.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(busy ? "Reading the device…" : "Not read yet").foregroundStyle(.secondary)
                    }
                } else {
                    Text(report)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(busy ? "Reading…" : "Read again") { Task { await load() } }
                    .disabled(busy)
                if !report.isEmpty {
                    ShareLink(item: report) { Label("Share report", systemImage: "square.and.arrow.up") }
                }
            }

            Section {
                NativeNote("The report is what this app can see from the device's lockdown service: "
                    + "identity, pairing, tunnel and the app's own files. It is meant to be pasted into a "
                    + "bug report — nothing leaves the phone until you share it.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        busy = true
        defer { busy = false }
        await device.refresh()
        encryption = await Diagnostics.backupEncryptionEnabled()
        report = await Diagnostics.report()
    }
}

// MARK: - Log

/// The run log, full screen, with a share button.
struct LogView: View {
    @ObservedObject private var log = RunLog.shared

    var body: some View {
        List {
            if log.lines.isEmpty {
                Section {
                    NativeNote("The log fills as the app talks to the device. An Apply, a tunnel probe "
                        + "or a PosterBoard pass each write their steps here.")
                }
            } else {
                Section {
                    ForEach(Array(log.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11.5, design: .monospaced))
                            .textSelection(.enabled)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
                }
                Section {
                    ShareLink(item: log.lines.joined(separator: "\n")) {
                        Label("Share log", systemImage: "square.and.arrow.up")
                    }
                    Button("Clear", role: .destructive) { log.clear() }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pairing

/// The pairing file and the wireless service, on one page.
///
/// Read-only on purpose: importing and resetting a record both live on Home,
/// next to the tunnel they feed, and a second place to do either is a second
/// place to get the "reset must not delete the file" rule wrong.
struct PairingView: View {
    @AppStorage(PairingRecord.Key.stored) private var stored: String?
    @ObservedObject private var wireless = WirelessPairing.shared

    private var loaded: Bool { PairingRecord.usable(stored ?? "") }

    var body: some View {
        List {
            Section("Pairing file") {
                LabeledContent("State") {
                    Text(loaded ? "Loaded" : "None")
                        .foregroundStyle(loaded ? .green : .orange)
                }
                if loaded {
                    LabeledContent("Source", value: PairingRecord.sourceLabel(stored ?? ""))
                    if let keys = PairingRecord.topLevelKeys(stored ?? "") {
                        LabeledContent("Keys", value: "\(keys.count)")
                    }
                }
            }

            Section("Wireless pairing") {
                LabeledContent("Service") {
                    Text(String(describing: wireless.phase))
                        .foregroundStyle(.secondary)
                }
                if let name = wireless.serviceName {
                    LabeledContent("Host name", value: name)
                }
                if let port = wireless.port {
                    LabeledContent("Port", value: String(port))
                }
                if let pin = wireless.pin {
                    LabeledContent("PIN", value: pin)
                }
            }

            Section {
                NativeNote("A pairing file is what lets the app talk to the device without a computer. "
                    + "Import one, or reset the import, from the Home page. This page only reports what "
                    + "is in use, so reading it never changes the record.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Pairing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About

struct AboutView: View {
    @ObservedObject private var device = DeviceIdentityMonitor.shared

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }
    private var name: String { info["CFBundleDisplayName"] as? String ?? "wowser" }
    private var short: String { info["CFBundleShortVersionString"] as? String ?? "—" }
    private var build: String { info["CFBundleVersion"] as? String ?? "—" }
    private var identifier: String { info["CFBundleIdentifier"] as? String ?? "—" }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Version \(short) (\(build))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Device") {
                LabeledContent("Model", value: device.current.productType.isEmpty
                               ? "unknown" : device.current.productType)
                LabeledContent("iOS", value: device.current.version.isEmpty
                               ? "unknown" : device.current.version)
            }

            Section("App") {
                LabeledContent("Bundle", value: identifier)
                LabeledContent("Sections", value: String(AppDestination.allCases.count))
                LabeledContent("Originals",
                               value: "\(Originals.clips.count) wallpapers · \(Originals.presets.count) presets")
            }

            Section {
                NativeNote("wowser is a rebrand and rebuild of GoldenNugget Mobile, which is AGPL-3.0 — "
                    + "the source for this build is public, and the original team's work is credited there "
                    + "rather than on this screen.")
                if let url = URL(string: "https://github.com/StayModding/wow.lol") {
                    Link("Source and build notes", destination: url)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
