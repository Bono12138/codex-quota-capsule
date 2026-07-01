import SwiftUI
import AppKit
import QuotaCapsuleCore

private let douyinID = "huotuichang439"

struct CapsuleRootView: View {
    @ObservedObject var store: QuotaStore
    let onExpandedChanged: (Bool) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 10) {
            Button {
                let nextExpanded = !expanded
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    expanded = nextExpanded
                }
                onExpandedChanged(nextExpanded)
            } label: {
                CompactCapsuleView(store: store)
            }
            .buttonStyle(.plain)

            if expanded {
                DetailPopoverView(store: store)
            }
        }
        .padding(10)
        .frame(width: 380)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    onDragChanged(value.translation)
                }
                .onEnded { _ in
                    onDragEnded()
                }
        )
    }
}

struct CompactCapsuleView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(toneColor(store.displayModel.tone))
                .frame(width: 8, height: 8)
                .shadow(color: toneColor(store.displayModel.tone).opacity(0.8), radius: 6)

            Text(store.visibleStatusText)
                .font(.system(size: 13, weight: .bold))

            Text(store.visibleCompactText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else if store.snapshot.sourceStatus != .ok {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}

struct DetailPopoverView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.copy.shortWindowTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(store.prediction.headline)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(2)
                }
                Spacer()
                Text(store.visibleStatusText)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(toneColor(store.displayModel.tone), in: Capsule())
                    .foregroundStyle(.black.opacity(0.82))
            }

            Text(store.prediction.detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 9) {
                ForEach(store.displayModel.metrics, id: \.label) { metric in
                    MetricRow(metric: metric, tone: store.displayModel.tone)
                }
            }

            HStack(spacing: 10) {
                MiniStat(title: store.copy.weeklyRemainingTitle, value: store.weeklyText)
                MiniStat(title: store.copy.resetTimeTitle, value: store.resetText)
                MiniStat(title: store.copy.successUpdateTitle, value: store.lastRefreshText)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(store.copy.dataSourceTitle)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    SourcePill(title: store.copy.sourceTitle, value: store.sourceNameText)
                    SourcePill(title: store.copy.endpointTitle, value: store.sourceEndpointText)
                    SourcePill(title: store.copy.statusTitle, value: store.sourceStatusText)
                }
                Text(store.sourceNoteText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(store.copy.manualRefreshNote)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }
}

struct SourcePill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct MetricRow: View {
    let metric: CapsuleMetric
    let tone: CapsuleLevel

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(metric.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.value)
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.14))
                    Capsule()
                        .fill(toneColor(tone))
                        .frame(width: geometry.size.width * CGFloat(metric.numericValue ?? 0) / 100)
                }
            }
            .frame(height: 7)
        }
    }
}

struct MiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct MenuBarContent: View {
    @ObservedObject var store: QuotaStore
    let onTogglePanel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.prediction.headline)
                .font(.headline)
            Text(store.prediction.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(store.copy.menuSourcePrefix): \(store.sourceText)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(store.copy.lastUpdatePrefix): \(store.lastRefreshText)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(store.copy.lastAttemptPrefix): \(store.lastAttemptText)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button(store.copy.refreshNowAction) {
                store.refresh()
            }
            Button(store.copy.toggleCapsuleAction) {
                onTogglePanel()
            }
            Divider()
            Text(store.copy.aboutFeedbackTitle)
                .font(.caption.bold())
            Text(store.copy.authorLine)
                .font(.caption)
            Text(store.copy.emailLine)
                .font(.caption)
            Text(store.copy.xLine)
                .font(.caption)
            Text(store.copy.douyinLine)
                .font(.caption)
            Button(store.copy.emailFeedbackAction) {
                openExternalURL("mailto:mmz1218bono@gmail.com")
            }
            Button(store.copy.githubIssuesAction) {
                openExternalURL("https://github.com/Bono12138/codex-quota-capsule/issues")
            }
            Button(store.copy.openXAction) {
                openExternalURL("https://x.com/starlightsz0")
            }
            Button(store.copy.copyDouyinIdAction) {
                copyToClipboard(douyinID)
            }
            Divider()
            Button(store.copy.quitAction) {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 6)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.33percent")
            Text(store.visibleStatusText)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quota Capsule")
                .font(.title2.bold())
            Text(store.copy.localPrivacyDescription)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.copy.authorLine)
                    Text(store.copy.emailLine)
                    Text(store.copy.xLine)
                    Text(store.copy.douyinLine)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    DouyinQRCodeView()
                    Text(store.copy.douyinQrHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(store.copy.emailFeedbackAction) {
                        openExternalURL("mailto:mmz1218bono@gmail.com")
                    }
                    Button(store.copy.githubIssuesAction) {
                        openExternalURL("https://github.com/Bono12138/codex-quota-capsule/issues")
                    }
                }
                HStack {
                    Button(store.copy.openXAction) {
                        openExternalURL("https://x.com/starlightsz0")
                    }
                    Button(store.copy.copyDouyinIdAction) {
                        copyToClipboard(douyinID)
                    }
                }
            }
            Button(store.copy.refreshQuotaAction) {
                store.refresh()
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

struct DouyinQRCodeView: View {
    var body: some View {
        Group {
            if let image = bundledImage(named: "douyin-qr", extension: "png") {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 68, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 150, height: 224)
            }
        }
        .frame(width: 150)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

private func openExternalURL(_ value: String) {
    guard let url = URL(string: value) else {
        return
    }
    NSWorkspace.shared.open(url)
}

private func copyToClipboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

private func bundledImage(named name: String, extension fileExtension: String) -> NSImage? {
    if let url = Bundle.main.url(forResource: name, withExtension: fileExtension) {
        return NSImage(contentsOf: url)
    }

    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/\(name).\(fileExtension)")
    if FileManager.default.fileExists(atPath: sourceURL.path) {
        return NSImage(contentsOf: sourceURL)
    }

    return nil
}

func toneColor(_ level: CapsuleLevel) -> Color {
    switch level {
    case .safe:
        Color(red: 0.28, green: 0.86, blue: 0.66)
    case .watch:
        Color(red: 0.95, green: 0.72, blue: 0.30)
    case .danger:
        Color(red: 1.0, green: 0.45, blue: 0.42)
    case .unknown:
        Color(red: 0.66, green: 0.70, blue: 0.68)
    }
}
