import SwiftUI
import UIKit

/// Four pages that used to be cards on Home, or nowhere at all.
///
/// Each one is a native `List` of system sections: the app's own chrome is the
/// dock at the bottom and nothing else, so a tool page should look like a page
/// of Settings rather than like a mockup.
///
/// Everything here already existed in the core — `ApplyHistory`, `Diagnostics`,
/// `RunLog`, `Originals` — and had no surface of its own.  Home was carrying the
/// diagnostics card, the pairing card and a log preview, which made the one page
/// with the Apply button on it also the page you had to scroll to reach
/// everything else.

// MARK: - Originals

/// The five artist packs, as a page of their own.
///
/// It was a shelf inside PosterBoard, above the pack list and the video picker,
/// which put it in competition with the controls it feeds.  Here it can show the
/// artwork at a readable size, say which preset belongs to which pack, and hand
/// the choice to PosterBoard with one button.
struct OriginalsView: View {
    @Binding var posterBoardSelection: PosterBoardSelection
    /// Jump to PosterBoard, so "choose a wallpaper" ends with the Apply.
    let openPosterBoard: () -> Void

    @State private var status: String?

    var body: some View {
        List {
            Section {
                NativeNote("Poster art drawn for wow.lol — no photographs, no likenesses. "
                    + "Gyro cuts are drawn on two planes, so the art moves against itself when the phone "
                    + "tilts; animated cuts loop. Choosing one here only sets the video choice — "
                    + "PosterBoard's Apply is what puts it on the Lock Screen.")
            }

            ForEach(Originals.artists, id: \.self) { artist in
                Section(artist) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(Originals.clips.filter { $0.artist == artist }) { clip in
                                Button { install(clip) } label: { card(clip) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

                    if let preset = Originals.presets.first(where: { $0.slug == clipSlug(artist) }) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.name)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(preset.blurb)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if let status {
                Section {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Open PosterBoard", action: openPosterBoard)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Originals")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The pack's own slug, taken from any of its clips.
    private func clipSlug(_ artist: String) -> String {
        Originals.clips.first { $0.artist == artist }?.slug ?? ""
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
                .frame(width: 150, height: 256)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
                }

                Label(clip.motion.label.uppercased(),
                      systemImage: clip.motion == .parallax ? "gyroscope" : "play.circle.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .labelStyle(.titleAndIcon)
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
                    if !record.device.isEmpty || !record.model.isEmpty {
                        Text(record.model.isEmpty ? record.device : "\\(record.model) · iOS \\(record.ios)")
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

/// The lockdown report, on a page with a copy button.
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

/// The run log, full screen, with a copy button.
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
                            .foregroundStyle(.primary)
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
