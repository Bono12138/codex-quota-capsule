import SwiftUI
import AppKit
import QuotaCapsuleCore

private let douyinID = FeedbackDestinations.douyinID
private let douyinURL = FeedbackDestinations.douyinURL.absoluteString
private let authorXURL = FeedbackDestinations.authorXURL.absoluteString

enum CapsuleViewMetrics {
    static let shadowPadding: CGFloat = 16
    static let collapsedContentHeight: CGFloat = 60
    static let collapsedHeight: CGFloat = collapsedContentHeight + shadowPadding * 2
    static let expandedHeight: CGFloat = 560
    static let expandedDetailContentHeight: CGFloat = expandedHeight - shadowPadding * 2 - collapsedContentHeight - 8
    static let dockedContentWidth: CGFloat = 116
    static let dockedContentHeight: CGFloat = 46
    static let dockedWidth: CGFloat = dockedContentWidth + shadowPadding * 2
    static let dockedHeight: CGFloat = dockedContentHeight + shadowPadding * 2
}

struct CapsuleRootView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if store.isCapsuleDocked {
                    DockedCapsuleView(store: store)
                } else {
                    CompactCapsuleView(store: store)
                }

                if !store.isCapsuleDocked {
                    CapsuleResizeHandles(helpText: store.copy.resizeCapsuleHelp)
                }
            }

            if store.isPanelExpanded && !store.isCapsuleDocked {
                DetailPopoverView(store: store)
            }
        }
        .frame(width: store.isCapsuleDocked ? CapsuleViewMetrics.dockedContentWidth : store.capsuleWidth)
        .padding(CapsuleViewMetrics.shadowPadding)
        .frame(width: store.isCapsuleDocked ? CapsuleViewMetrics.dockedWidth : store.capsuleWidth + CapsuleViewMetrics.shadowPadding * 2)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct DockedCapsuleView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(toneColor(store.displayModel.tone))
                .frame(width: 8, height: 8)
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary.opacity(0.76))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(store.visibleStatusText)
                        .font(.system(size: 12, weight: .bold))
                    if let used = store.compactUsedValueText {
                        Text(used)
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(toneColor(store.displayModel.tone))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                Text(store.copy.compactUsageLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .frame(width: CapsuleViewMetrics.dockedContentWidth, height: CapsuleViewMetrics.dockedContentHeight)
        .background {
            Capsule(style: .continuous)
                .fill(capsuleSurfaceColor())
                .shadow(color: .black.opacity(0.12), radius: 9, y: 4)
        }
        .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
    }
}

struct CompactCapsuleView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(toneColor(store.displayModel.tone))
                        .frame(width: 8, height: 8)
                        .shadow(color: toneColor(store.displayModel.tone).opacity(0.55), radius: 5)

                    Text(store.visibleStatusText)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let usedText = store.visibleCompactUsedBadgeText {
                        Text(usedText)
                            .font(.system(size: 10, weight: .bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(toneColor(store.displayModel.tone).opacity(0.18), in: Capsule())
                    }

                    if store.isRefreshing {
                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 12, height: 12)
                    } else if store.snapshot.sourceStatus != .ok {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(store.compactProjectedText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let elapsed = store.compactElapsedPercent,
               let used = store.compactUsedPercent {
                CompactPaceBars(
                    elapsedLabel: store.copy.compactTimeLabel,
                    usageLabel: store.copy.compactUsageTrackLabel,
                    elapsedPercent: elapsed,
                    usedPercent: used,
                    tone: store.displayModel.tone
                )
                .frame(width: compactMeterWidth, alignment: .leading)
                .layoutPriority(2)
            } else {
                CompactStatusNote(
                    text: store.sourceStatusText,
                    isSuccess: store.snapshot.sourceStatus == .ok
                )
                    .frame(width: compactMeterWidth, alignment: .leading)
                    .layoutPriority(2)
            }
        }
        .padding(.leading, 38)
        .padding(.trailing, 36)
        .padding(.vertical, 9)
        .frame(height: CapsuleViewMetrics.collapsedContentHeight)
        .background {
            Capsule(style: .continuous)
                .fill(capsuleSurfaceColor())
                .shadow(color: .black.opacity(0.09), radius: 10, y: 4)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .overlay(Capsule().stroke(.white.opacity(0.24), lineWidth: 1))
        .overlay(
            Capsule()
                .stroke(onboardingHighlightColor().opacity(store.onboardingFocus == .capsule ? 0.98 : 0), lineWidth: 3)
                .shadow(color: onboardingHighlightColor().opacity(store.onboardingFocus == .capsule ? 0.55 : 0), radius: 8)
        )
    }

    private var compactMeterWidth: CGFloat {
        min(150, max(126, store.capsuleWidth * 0.34))
    }
}

struct CapsuleResizeHandles: View {
    let helpText: String

    var body: some View {
        HStack {
            CapsuleResizeHandle(helpText: helpText)
            Spacer(minLength: 0)
            CapsuleResizeHandle(helpText: helpText)
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, maxHeight: CapsuleViewMetrics.collapsedContentHeight)
    }
}

struct CapsuleResizeHandle: View {
    let helpText: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.primary.opacity(0.36))
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.primary.opacity(0.18))
                .frame(width: 13, height: 3)
        }
        .frame(width: 28, height: 42)
        .contentShape(Rectangle())
        .opacity(0.82)
        .help(helpText)
    }
}

struct CompactPaceBars: View {
    let elapsedLabel: String
    let usageLabel: String
    let elapsedPercent: Int
    let usedPercent: Int
    let tone: CapsuleLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CompactPaceTrack(label: elapsedLabel, percent: elapsedPercent, percentText: "\(elapsedPercent)%", color: .secondary)
            CompactPaceTrack(
                label: usageLabel,
                percent: usedPercent,
                percentText: usedPercent == 0 ? "<1%" : "\(usedPercent)%",
                color: toneColor(tone)
            )
        }
    }
}

struct CompactPaceTrack: View {
    let label: String
    let percent: Int
    let percentText: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary.opacity(0.68))
                .frame(width: 28, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.12))
                    Capsule()
                        .fill(color.opacity(0.95))
                        .frame(width: geometry.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
                }
            }
            .frame(height: 4)
            Text(percentText)
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary.opacity(0.72))
                .frame(width: 34, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompactStatusNote: View {
    let text: String
    let isSuccess: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSuccess ? toneColor(.safe) : .secondary)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.primary.opacity(0.08), in: Capsule())
    }
}

struct DetailPopoverView: View {
    @ObservedObject var store: QuotaStore
    @State private var assistedFeedbackMessage = ""
    @State private var diagnosticsExpanded = false

    private var progressMetrics: [CapsuleMetric] {
        Array(store.displayModel.metrics.prefix(2))
    }

    private var guidanceMetrics: [CapsuleMetric] {
        Array(store.displayModel.metrics.dropFirst(2).prefix(2))
    }

    var body: some View {
        ScrollView(.vertical) {
            detailContent
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .frame(maxHeight: CapsuleViewMetrics.expandedDetailContentHeight)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(panelSurfaceColor())
                .shadow(color: .black.opacity(0.08), radius: 9, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.14), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(onboardingHighlightColor().opacity(store.onboardingFocus == .detail ? 0.98 : 0), lineWidth: 3)
                .shadow(color: onboardingHighlightColor().opacity(store.onboardingFocus == .detail ? 0.55 : 0), radius: 9)
        )
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.copy.weeklyOnlyTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)
                Spacer()
                Text(store.visibleStatusText)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(toneColor(store.displayModel.tone), in: Capsule())
                    .foregroundStyle(.black.opacity(0.82))
            }

            Text(store.displayModel.defaultText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !store.displayModel.confidenceText.isEmpty {
                Label(store.displayModel.confidenceText, systemImage: "scope")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(store.copy.weeklyPaceTitle)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                ForEach(progressMetrics, id: \.label) { metric in
                    MetricRow(metric: metric, tone: store.displayModel.tone)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(store.copy.weeklyGuidanceTitle)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(Array(guidanceMetrics.enumerated()), id: \.element.label) { index, metric in
                        OverviewStatTile(
                            title: metric.label,
                            value: metric.value,
                            tone: store.displayModel.tone,
                            systemImage: index == 0 ? "calendar.badge.clock" : "speedometer"
                        )
                    }
                }
            }

            if !store.observedUsageText.isEmpty {
                Label(store.observedUsageText, systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }

            WeeklyTrendChartView(store: store)

            VStack(alignment: .leading, spacing: 6) {
                Label(store.quotaResetDescription, systemImage: "calendar.badge.clock")
                Label(store.dataRefreshDescription, systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)

            PanelQuickActionsView(store: store, assistedFeedbackMessage: $assistedFeedbackMessage)

            DisclosureGroup(isExpanded: $diagnosticsExpanded) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        SourcePill(title: store.copy.sourceTitle, value: store.sourceNameText)
                        SourcePill(title: store.copy.endpointTitle, value: store.sourceEndpointText)
                        SourcePill(title: store.copy.statusTitle, value: store.sourceStatusText)
                    }
                    Text(store.sourceNoteText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !store.diagnosticPaceComparisonText.isEmpty {
                        Text(store.diagnosticPaceComparisonText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 8)
            } label: {
                Label(store.copy.dataDiagnosticsTitle, systemImage: "stethoscope")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            ResetCreditFooterView(store: store)
        }
    }
}

struct ResetCreditFooterView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        if let countText = store.resetCreditCountText {
            VStack(alignment: .leading, spacing: 7) {
                Divider()
                    .opacity(0.35)
                Label(store.copy.resetCreditsTitle, systemImage: "ticket")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(countText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))
                ForEach(store.resetCreditRows) { row in
                    Text(row.text)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let missingText = store.resetCreditMissingDetailsText {
                    Text(missingText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WeeklyTrendChartView: View {
    @ObservedObject var store: QuotaStore

    private var points: [WeeklyTrendPoint] {
        store.runwayForecast.currentCycleTrend
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.copy.weeklyTrendTitle)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            if store.displayModel.showsLivePaceDetails,
               points.count >= 2,
               let window = store.snapshot.weeklyWindow {
                chart(window: window)
                    .frame(height: 76)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { chartLegend }
                    VStack(alignment: .leading, spacing: 5) { chartLegend }
                }
            } else if !store.displayModel.showsLivePaceDetails {
                Label(store.copy.paceDetailsPausedText, systemImage: "pause.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Label(store.copy.trendLearningText, systemImage: "chart.xyaxis.line")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func chart(window: QuotaWindow) -> some View {
        Canvas { context, size in
            let inset: CGFloat = 5
            let width = max(1, size.width - inset * 2)
            let height = max(1, size.height - inset * 2)
            let cycleStart = window.resetsAt.addingTimeInterval(-Double(window.windowMinutes) * 60)
            let duration = max(1, window.resetsAt.timeIntervalSince(cycleStart))

            func location(at date: Date, usedPercent: Double) -> CGPoint {
                let progress = min(1, max(0, date.timeIntervalSince(cycleStart) / duration))
                let used = min(100, max(0, usedPercent)) / 100
                return CGPoint(
                    x: inset + width * progress,
                    y: inset + height * (1 - used)
                )
            }

            var sustainable = Path()
            sustainable.move(to: CGPoint(x: inset, y: inset + height))
            sustainable.addLine(to: CGPoint(x: inset + width, y: inset))
            context.stroke(
                sustainable,
                with: .color(.secondary.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )

            var actual = Path()
            for (index, point) in points.enumerated() {
                let location = location(at: point.at, usedPercent: point.usedPercent)
                index == 0 ? actual.move(to: location) : actual.addLine(to: location)
            }
            context.stroke(
                actual,
                with: .color(toneColor(store.displayModel.tone)),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )

            if let band = store.runwayForecast.projectedRemainingBandAtReset {
                let lowerUsed = 100 - min(100, max(0, band.upper))
                let upperUsed = 100 - min(100, max(0, band.lower))
                var forecastBand = Path()
                forecastBand.move(to: location(at: window.resetsAt, usedPercent: lowerUsed))
                forecastBand.addLine(to: location(at: window.resetsAt, usedPercent: upperUsed))
                context.stroke(
                    forecastBand,
                    with: .color(toneColor(store.displayModel.tone).opacity(0.52)),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
            }

            var reset = Path()
            reset.move(to: CGPoint(x: inset + width, y: inset))
            reset.addLine(to: CGPoint(x: inset + width, y: inset + height))
            context.stroke(
                reset,
                with: .color(.primary.opacity(0.32)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 3])
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.copy.weeklyTrendTitle)，\(store.copy.sustainableLineTitle)，\(forecastBandText)")
    }

    @ViewBuilder
    private var chartLegend: some View {
        Label(store.copy.sustainableLineTitle, systemImage: "line.diagonal")
        Label(forecastBandText, systemImage: "arrow.up.and.down")
        Label("\(store.copy.resetMarkerTitle) \(store.resetText)", systemImage: "flag.checkered")
    }

    private var forecastBandText: String {
        "\(store.copy.forecastResetBandTitle)：\(store.copy.forecastResetBandValue(store.runwayForecast.projectedRemainingBandAtReset))"
    }
}

struct PanelQuickActionsView: View {
    @ObservedObject var store: QuotaStore
    @Binding var assistedFeedbackMessage: String

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 128), spacing: 7)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) {
                    primaryActions
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                    primaryActions
                }
            }

            if !assistedFeedbackMessage.isEmpty {
                Label(assistedFeedbackMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(toneColor(store.displayModel.tone))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var primaryActions: some View {
        quickActionButton(title: store.copy.refreshNowAction, symbol: "arrow.clockwise") {
            store.refresh()
        }

        quickActionButton(title: store.copy.submitFeedbackAction, symbol: "paperplane") {
            let destination = startAssistedFeedback(store: store)
            assistedFeedbackMessage = destination == .github ? store.copy.assistedFeedbackStartedMessage : store.copy.assistedFeedbackEmailMessage
        }
        .help(store.copy.codexFeedbackHint)

        moreActionsMenu
    }

    private var moreActionsMenu: some View {
        Menu {
            Button(store.copy.openStatusMenuAction) {
                NotificationCenter.default.post(name: .quotaCapsuleShowStatusMenu, object: nil)
            }

            Button(store.copy.toggleCapsuleAction) {
                NotificationCenter.default.post(name: .quotaCapsuleTogglePanel, object: nil)
            }

            Section(store.copy.languageMenuTitle) {
                Button("简体中文 · \(store.copy.languageSimplifiedAssistiveLabel)") {
                    store.selectLocale(.zhHans)
                }
                Button("繁體中文 · \(store.copy.languageTraditionalAssistiveLabel)") {
                    store.selectLocale(.zhHant)
                }
                Button("English · \(store.copy.languageEnglishAssistiveLabel)") {
                    store.selectLocale(.en)
                }
            }

            Button(store.copy.userGuideAction) {
                NotificationCenter.default.post(name: .quotaCapsuleShowOnboarding, object: nil)
            }

            Button(store.copy.contactAuthorTitle) {
                NotificationCenter.default.post(name: .quotaCapsuleShowContactAuthor, object: nil)
            }

            Button(store.copy.aboutFeedbackTitle) {
                NotificationCenter.default.post(name: .quotaCapsuleShowAboutFeedback, object: nil)
            }

            Divider()

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label(store.copy.quitAction, systemImage: "power")
            }
        } label: {
            panelActionLabel(title: store.copy.moreActionsTitle, symbol: "ellipsis.circle")
        }
        .buttonStyle(.plain)
    }

    private func quickActionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            panelActionLabel(title: title, symbol: symbol)
        }
        .buttonStyle(.plain)
    }

    private func panelActionLabel(title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 10.5, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .symbolVariant(.none)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .center)
            .padding(.horizontal, 9)
            .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
    }
}

struct OverviewStatsGrid: View {
    let paceTitle: String
    let paceValue: String
    let weeklyTitle: String
    let weeklyValue: String
    let resetTitle: String
    let resetValue: String
    let updatedTitle: String
    let updatedValue: String
    let tone: CapsuleLevel

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            OverviewStatTile(title: paceTitle, value: paceValue, tone: tone, systemImage: "gauge.with.dots.needle.33percent")
            OverviewStatTile(title: weeklyTitle, value: weeklyValue, tone: tone, systemImage: "calendar")
            OverviewStatTile(title: resetTitle, value: resetValue, tone: tone, systemImage: "clock.arrow.circlepath")
            OverviewStatTile(title: updatedTitle, value: updatedValue, tone: tone, systemImage: "checkmark.seal")
        }
    }
}

struct OverviewStatTile: View {
    let title: String
    let value: String
    let tone: CapsuleLevel
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(toneColor(tone))
                    .frame(width: 18, height: 18)
                    .background(toneColor(tone).opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(toneColor(tone).opacity(0.72))
                .frame(height: 3)
                .padding(.horizontal, 11)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
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
            if let numericValue = metric.numericValue {
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
                            .frame(width: geometry.size.width * CGFloat(numericValue) / 100)
                    }
                }
                .frame(height: 7)
            } else {
                HStack(spacing: 8) {
                    Text(metric.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(metric.value)
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(toneColor(tone).opacity(0.16), in: Capsule())
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct WeeklyProjectionView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(toneColor(store.weeklyProjectionTone))
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.copy.weeklyProjectionTitle)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(store.weeklyProjectionText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(onboardingHighlightColor().opacity(store.onboardingFocus == .weekly ? 0.98 : 0), lineWidth: 3)
                .shadow(color: onboardingHighlightColor().opacity(store.onboardingFocus == .weekly ? 0.55 : 0), radius: 8)
        )
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

struct MenuBarLabel: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.33percent")
            Text(store.visibleMenuBarText)
        }
    }
}

struct AnalyticsConsentPanel: View {
    @ObservedObject var store: QuotaStore
    let compact: Bool

    var body: some View {
        if store.analyticsConsent == .granted {
            grantedSummary
        } else if store.analyticsConsent == .denied {
            basicSummary
        } else {
            fullConsentPanel
        }
    }

    private var grantedSummary: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: compact ? 13 : 16, weight: .semibold))
                .foregroundStyle(toneColor(store.displayModel.tone))
            VStack(alignment: .leading, spacing: 2) {
                Text(store.copy.analyticsGrantedText)
                    .font(compact ? .caption.bold() : .headline)
                Text(store.copy.analyticsSensitiveBoundary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(compact ? 11 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var basicSummary: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: compact ? 13 : 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.copy.analyticsDeniedText)
                    .font(compact ? .caption.bold() : .headline)
                Text(store.copy.analyticsBasicSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(store.copy.analyticsAllowAction) {
                store.setAnalyticsConsent(.granted)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(compact ? .small : .regular)
        }
        .padding(compact ? 11 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fullConsentPanel: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            Text(store.copy.analyticsConsentTitle)
                .font(compact ? .caption.bold() : .headline)

            AnalyticsInfoRow(
                symbol: "checkmark.shield.fill",
                title: store.copy.analyticsEssentialTitle,
                description: store.copy.analyticsEssentialBody,
                tint: toneColor(store.displayModel.tone),
                compact: compact
            )

            AnalyticsInfoRow(
                symbol: "chart.xyaxis.line",
                title: store.copy.analyticsProductTitle,
                description: store.copy.analyticsProductBody,
                tint: .accentColor,
                compact: compact
            )

            Text(store.copy.analyticsSensitiveBoundary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("\(store.copy.analyticsCurrentChoiceTitle): \(store.analyticsConsentText)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Button(store.copy.analyticsAllowAction) {
                    store.setAnalyticsConsent(.granted)
                }
                .buttonStyle(.borderedProminent)
                Button(store.copy.analyticsDenyAction) {
                    store.setAnalyticsConsent(.denied)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AnalyticsInfoRow: View {
    let symbol: String
    let title: String
    let description: String
    let tint: Color
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DouyinIDCopyCard: View {
    @ObservedObject var store: QuotaStore
    let didCopy: Bool
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(didCopy ? toneColor(store.displayModel.tone) : Color.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(douyinID)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospaced()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(didCopy ? store.copy.douyinCopiedHint : store.copy.douyinCopyHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(didCopy ? 0.16 : 0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor.opacity(didCopy ? 0.45 : 0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AboutFeedbackView: View {
    @ObservedObject var store: QuotaStore
    @State private var assistedFeedbackMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quota Capsule")
                        .font(.title2.bold())
                    Label(store.copy.productIntroTitle, systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundStyle(toneColor(store.displayModel.tone))
                    Text(store.copy.productIntroBody)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Label(store.copy.betaThanksTitle, systemImage: "hand.wave.fill")
                        .font(.headline)
                    Text(store.copy.betaThanksBody)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(store.copy.submitFeedbackAction) {
                        let destination = startAssistedFeedback(store: store)
                        assistedFeedbackMessage = destination == .github ? store.copy.assistedFeedbackStartedMessage : store.copy.assistedFeedbackEmailMessage
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 2)
                    Text(store.copy.codexFeedbackHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(store.copy.feedbackAlternativeHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            feedbackAlternativeButtons
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            feedbackAlternativeButtons
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    if !assistedFeedbackMessage.isEmpty {
                        Label(assistedFeedbackMessage, systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(toneColor(store.displayModel.tone))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                AboutAuthorBlock(store: store)

                ProductInfoBlock(
                    symbol: "checkmark.seal.fill",
                    title: store.copy.currentVersionFeaturesTitle,
                    rows: store.copy.currentVersionFeatures,
                    tone: toneColor(store.displayModel.tone)
                )

                ProductInfoBlock(
                    symbol: "sparkles",
                    title: store.copy.futureVersionFeaturesTitle,
                    rows: store.copy.futureVersionFeatures,
                    tone: .accentColor
                )

                AdvancedDataSettingsEntry(store: store)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 720)
        .frame(minHeight: 560)
        .background(.thickMaterial)
        .onAppear {
            assistedFeedbackMessage = ""
            store.recordSettingsOpened(surface: "about_feedback")
        }
    }

    @ViewBuilder
    private var feedbackAlternativeButtons: some View {
        Button(store.copy.emailFeedbackAction) {
            store.recordFeedbackClick("email")
            openExternalURL("mailto:\(FeedbackDestinations.authorEmail)")
        }
        Button(store.copy.openXAction) {
            store.recordFeedbackClick("x")
            openExternalURL(authorXURL)
        }
        Button(store.copy.openDouyinAction) {
            store.recordFeedbackClick("douyin_open")
            openExternalURL(douyinURL)
        }
    }
}

struct AboutAuthorBlock: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(store.copy.aboutAuthorTitle, systemImage: "person.crop.circle")
                .font(.headline)
                .foregroundStyle(toneColor(store.displayModel.tone))
            Text(store.copy.aboutAuthorBody)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(store.copy.openXAction) {
                    store.recordFeedbackClick("x")
                    openExternalURL(authorXURL)
                }
                Button(store.copy.openDouyinAction) {
                    store.recordFeedbackClick("douyin_open")
                    openExternalURL(douyinURL)
                }
                Button(store.copy.contactAuthorTitle) {
                    NotificationCenter.default.post(name: .quotaCapsuleShowContactAuthor, object: nil)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AdvancedDataSettingsEntry: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.copy.advancedDataSettingsTitle)
                    .font(.system(size: 13, weight: .bold))
                Text(store.copy.localDataPrivacyAuthorizationTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(store.copy.advancedDataSettingsTitle) {
                NotificationCenter.default.post(name: .quotaCapsuleShowAdvancedDataSettings, object: nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct ProductInfoBlock: View {
    let symbol: String
    let title: String
    let rows: [String]
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tone)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(rows, id: \.self) { row in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(tone.opacity(0.82))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(row)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AdvancedDataSettingsView: View {
    @ObservedObject var store: QuotaStore
    let context: String
    let onConfirmRevokeAnalytics: () -> Void
    let onConfirmClearLocalHistory: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.copy.advancedDataSettingsTitle)
                        .font(.title2.bold())
                    Text(store.copy.localPrivacyDescription)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Label(store.copy.localDataPrivacyAuthorizationTitle, systemImage: "lock.shield")
                        .font(.headline)
                    AnalyticsConsentPanel(store: store, compact: false)
                    Text(store.copy.analyticsRevokeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(role: .destructive) {
                        onConfirmRevokeAnalytics()
                    } label: {
                        Text(store.copy.analyticsRevokeAction)
                    }
                    .disabled(store.analyticsConsent != .granted)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(store.copy.localHistoryTitle, systemImage: "externaldrive")
                        .font(.headline)
                    Text(store.historyDatabaseSizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(role: .destructive) {
                        onConfirmClearLocalHistory()
                    } label: {
                        Text(store.copy.clearLocalHistoryAction)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 600)
        .frame(minHeight: 420)
        .background(.thickMaterial)
        .onAppear {
            store.recordSettingsOpened(surface: context)
        }
    }
}

struct ContactAuthorView: View {
    @ObservedObject var store: QuotaStore
    let context: String
    @State private var didCopyDouyin = false
    @State private var assistedFeedbackMessage = ""

    init(store: QuotaStore, context: String = "settings") {
        self.store = store
        self.context = context
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.copy.contactAuthorTitle)
                    .font(.title2.bold())
                Text(store.copy.authorMenuHint)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(store.copy.authorLine)
                            Text(store.copy.emailLine)
                            Text(store.copy.xLine)
                            Text(store.copy.douyinLine)
                            DouyinIDCopyCard(
                                store: store,
                                didCopy: didCopyDouyin,
                                onCopy: {
                                    copyToClipboard(douyinID)
                                    didCopyDouyin = true
                                    store.recordFeedbackClick("douyin_copy")
                                }
                            )
                            .padding(.top, 2)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], alignment: .leading, spacing: 8) {
                            Button(store.copy.submitFeedbackAction) {
                                let destination = startAssistedFeedback(store: store)
                                assistedFeedbackMessage = destination == .github ? store.copy.assistedFeedbackStartedMessage : store.copy.assistedFeedbackEmailMessage
                            }
                            Button(store.copy.emailFeedbackAction) {
                                store.recordFeedbackClick("email")
                                openExternalURL("mailto:\(FeedbackDestinations.authorEmail)")
                            }
                            Button(store.copy.openXAction) {
                                store.recordFeedbackClick("x")
                                openExternalURL(authorXURL)
                            }
                            Button(store.copy.openDouyinAction) {
                                store.recordFeedbackClick("douyin_open")
                                openExternalURL(douyinURL)
                            }
                            Button(store.copy.refreshQuotaAction) {
                                store.refresh()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        if !assistedFeedbackMessage.isEmpty {
                            Label(assistedFeedbackMessage, systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(toneColor(store.displayModel.tone))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
                    .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: 8) {
                        DouyinQRCodeView(size: 250)
                        Text(store.copy.douyinQrHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 250)
                    }
                    .frame(width: 278)
                }

            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 720)
        .frame(minHeight: 500)
        .background(.thickMaterial)
        .onAppear {
            didCopyDouyin = false
            assistedFeedbackMessage = ""
            store.recordSettingsOpened(surface: context)
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var store: QuotaStore
    @State private var stepIndex = 0
    @State private var didCopyDouyin = false
    let onComplete: () -> Void

    private var steps: [OnboardingStep] {
        [
            OnboardingStep(id: "capsule", focus: .capsule, title: store.copy.onboardingCapsuleStepTitle, body: store.copy.onboardingCapsuleStepBody, symbol: "capsule.portrait"),
            OnboardingStep(id: "detail", focus: .detail, title: store.copy.onboardingDetailStepTitle, body: store.copy.onboardingDetailStepBody, symbol: "rectangle.and.text.magnifyingglass"),
            OnboardingStep(id: "weekly", focus: .weekly, title: store.copy.onboardingWeeklyStepTitle, body: store.copy.onboardingWeeklyStepBody, symbol: "calendar.badge.clock"),
            OnboardingStep(id: "menu", focus: .menu, title: store.copy.onboardingMenuStepTitle, body: store.copy.onboardingMenuStepBody, symbol: "menubar.rectangle"),
            OnboardingStep(id: "feedback", focus: .feedback, title: store.copy.onboardingFeedbackStepTitle, body: store.copy.onboardingFeedbackStepBody, symbol: "paperplane")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.needsLanguageSelection {
                    languageSelection
                } else {
                    guidedTour
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 680, height: store.needsLanguageSelection ? 340 : 620)
        .background(.thickMaterial)
        .onAppear {
            store.recordOnboardingStarted()
            updateFocus()
        }
        .onChange(of: stepIndex) { _, _ in
            didCopyDouyin = false
            updateFocus()
        }
        .onChange(of: store.needsLanguageSelection) { _, _ in
            updateFocus()
        }
        .onDisappear {
            store.setOnboardingFocus(nil)
        }
    }

    private var languageSelection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(store.copy.languageSelectionTitle)
                    .font(.title2.bold())
            }
            Text(store.copy.languageSelectionSubtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                languageButton(.zhHans, code: "简", title: "简体中文", subtitle: store.copy.languageSimplifiedAssistiveLabel)
                languageButton(.zhHant, code: "繁", title: "繁體中文", subtitle: store.copy.languageTraditionalAssistiveLabel)
                languageButton(.en, code: "EN", title: "English", subtitle: store.copy.languageEnglishAssistiveLabel)
            }
        }
    }

    private var guidedTour: some View {
        let step = steps[min(stepIndex, steps.count - 1)]
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.copy.onboardingTitle)
                    .font(.title2.bold())
                Text(store.copy.onboardingSubtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: step.symbol)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(toneColor(store.displayModel.tone))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 7) {
                            Text(step.title)
                                .font(.headline)
                            Text(step.body)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    stepDetails(step)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                OnboardingPreviewCard(store: store, step: step)
                    .frame(width: 236)
            }

            if step.id == "capsule", store.snapshot.sourceStatus != .ok {
                diagnosticPanel
            }

            if step.id == "capsule" {
                GuideRow(symbol: "person.crop.circle", text: store.copy.onboardingAuthorIntro)
            } else if step.id == "feedback" {
                onboardingAuthorActions
            }

            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == stepIndex ? toneColor(store.displayModel.tone) : .secondary.opacity(0.28))
                        .frame(width: 7, height: 7)
                }
                Spacer()
                Button(store.copy.onboardingSkipAction) {
                    store.skipOnboarding()
                    onComplete()
                }
                if stepIndex > 0 {
                    Button(store.copy.onboardingBackAction) {
                        stepIndex -= 1
                    }
                }
                Button(store.copy.refreshNowAction) {
                    store.refresh()
                }
                Button(stepIndex == steps.count - 1 ? store.copy.onboardingStartAction : store.copy.onboardingNextAction) {
                    if stepIndex == steps.count - 1 {
                        store.completeOnboarding()
                        onComplete()
                    } else {
                        stepIndex += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var onboardingAuthorActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(toneColor(store.displayModel.tone))
                Text(store.copy.onboardingAuthorActionTitle)
                    .font(.system(size: 13, weight: .bold))
            }
            Text(store.copy.onboardingAuthorActionBody)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    authorButtonsPrimary
                    authorButtonsSocial
                }
                VStack(alignment: .leading, spacing: 8) {
                    authorButtonsPrimary
                    authorButtonsSocial
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(toneColor(store.displayModel.tone).opacity(0.24), lineWidth: 1)
        )
    }

    private var authorButtonsPrimary: some View {
        HStack(spacing: 8) {
            Button(store.copy.submitFeedbackAction) {
                _ = startAssistedFeedback(store: store)
            }
            Button(store.copy.emailFeedbackAction) {
                store.recordFeedbackClick("email")
                openExternalURL("mailto:\(FeedbackDestinations.authorEmail)")
            }
        }
    }

    private var authorButtonsSocial: some View {
        HStack(spacing: 8) {
            Button(store.copy.openXAction) {
                store.recordFeedbackClick("x")
                openExternalURL(authorXURL)
            }
            Button(store.copy.openDouyinAction) {
                store.recordFeedbackClick("douyin_open")
                openExternalURL(douyinURL)
            }
            Button {
                copyToClipboard(douyinID)
                didCopyDouyin = true
                store.recordFeedbackClick("douyin_copy")
            } label: {
                Label(didCopyDouyin ? store.copy.douyinCopiedShortAction : store.copy.copyDouyinIdAction, systemImage: didCopyDouyin ? "checkmark.circle.fill" : "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private func stepDetails(_ step: OnboardingStep) -> some View {
        switch step.id {
        case "capsule":
            VStack(alignment: .leading, spacing: 10) {
                GuideRow(symbol: "lock.shield", text: store.copy.onboardingLocalRead)
                GuideRow(symbol: "checkmark.shield", text: store.copy.onboardingPrivacy)
                GuideRow(symbol: "arrow.left.and.right", text: store.copy.onboardingInteraction)
            }
        case "detail":
            VStack(alignment: .leading, spacing: 10) {
                GuideRow(symbol: "gauge.with.dots.needle.67percent", text: store.copy.onboardingStatus)
                GuideRow(symbol: "tablecells", text: store.copy.onboardingDetailStepBody)
            }
        case "feedback":
            EmptyView()
        default:
            EmptyView()
        }
    }

    private var diagnosticPanel: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(store.copy.onboardingDiagnosticTitle)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(store.sourceNoteText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func languageButton(_ locale: QuotaLocale, code: String, title: String, subtitle: String) -> some View {
        Button {
            store.selectLocale(locale)
        } label: {
            LanguageChoiceButton(code: code, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    private func updateFocus() {
        guard !store.needsLanguageSelection else {
            store.setOnboardingFocus(nil)
            return
        }
        let step = steps[min(stepIndex, steps.count - 1)]
        store.setOnboardingFocus(step.focus)
        store.recordOnboardingStep(step.id)
    }
}

struct OnboardingStep {
    let id: String
    let focus: OnboardingFocus
    let title: String
    let body: String
    let symbol: String
}

struct LanguageChoiceButton: View {
    let code: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Text(code)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 186, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        )
    }
}

struct OnboardingPreviewCard: View {
    @ObservedObject var store: QuotaStore
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: step.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(toneColor(store.displayModel.tone))
                Text(step.title)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            switch step.id {
            case "capsule":
                previewCapsule
            case "detail":
                previewDetail
            case "weekly":
                previewWeekly
            case "menu":
                previewMenu
            default:
                previewFeedback
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 186, alignment: .topLeading)
        .background(panelSurfaceColor(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(toneColor(store.displayModel.tone).opacity(0.36), lineWidth: 1)
        )
    }

    private var previewCapsule: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Circle()
                    .fill(toneColor(store.displayModel.tone))
                    .frame(width: 8, height: 8)
                Text(store.visibleStatusText)
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(store.visibleCompactUsedBadgeText ?? store.sourceStatusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(store.compactProjectedText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Divider()
            GuideRow(symbol: "cursorarrow.motionlines", text: store.copy.onboardingInteraction)
        }
    }

    private var previewDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            previewBar(
                label: store.displayModel.metrics[0].label,
                value: store.displayModel.metrics[0].numericValue ?? 24
            )
            previewBar(
                label: store.displayModel.metrics[1].label,
                value: store.displayModel.metrics[1].numericValue ?? 5
            )
            HStack {
                previewGuidanceMetric(store.displayModel.metrics[2])
                previewGuidanceMetric(store.displayModel.metrics[3])
            }
            Text(store.copy.dataSourceTitle)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
    }

    private var previewWeekly: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.displayModel.statusLabel)
                    .font(.caption.bold())
                Spacer()
                Text(store.displayModel.confidenceText)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            Text(store.displayModel.defaultText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            previewGuidanceMetric(store.displayModel.metrics[3])
        }
    }

    private func previewGuidanceMetric(_ metric: CapsuleMetric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(metric.value)
                .font(.caption.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewMenu: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(store.visibleMenuBarText, systemImage: "gauge.with.dots.needle.33percent")
            Label(store.copy.refreshNowAction, systemImage: "arrow.clockwise")
            Label(store.copy.aboutFeedbackTitle, systemImage: "paperplane")
            Label(store.copy.languageMenuTitle, systemImage: "globe")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var previewFeedback: some View {
        VStack(alignment: .leading, spacing: 7) {
            previewLine("person.crop.circle", "Bono MA")
            previewLine("envelope", "mmz1218bono@gmail.com")
            previewLine("link", "@starlightsz0")
            previewLine("doc.on.doc", douyinID)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func previewLine(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .frame(width: 14)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func previewBar(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value)%")
                    .font(.caption2.bold())
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                Capsule()
                    .fill(toneColor(store.displayModel.tone))
                    .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 100)) / 100)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.12), in: Capsule())
            }
            .frame(height: 5)
        }
    }
}

struct GuideRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DouyinQRCodeView: View {
    let size: CGFloat

    init(size: CGFloat = 220) {
        self.size = size
    }

    var body: some View {
        Group {
            if let image = bundledImage(named: "douyin-qr-scan", extension: "png") ?? bundledImage(named: "douyin-qr", extension: "png") {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 68, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

private func openExternalURL(_ value: String) {
    guard let url = URL(string: value) else {
        return
    }
    openExternalURL(url)
}

private func openExternalURL(_ url: URL) {
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

    #if SWIFT_PACKAGE
    if let url = Bundle.module.url(forResource: name, withExtension: fileExtension) {
        return NSImage(contentsOf: url)
    }
    #endif

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

func onboardingHighlightColor() -> Color {
    Color(red: 0.16, green: 0.50, blue: 0.98)
}

@MainActor
func capsuleSurfaceColor() -> Color {
    if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
        return Color(red: 0.10, green: 0.12, blue: 0.13).opacity(0.86)
    }
    return Color(red: 0.92, green: 0.96, blue: 0.95).opacity(0.92)
}

@MainActor
func panelSurfaceColor() -> Color {
    if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
        return Color(red: 0.09, green: 0.10, blue: 0.11).opacity(0.88)
    }
    return Color(red: 0.90, green: 0.94, blue: 0.93).opacity(0.93)
}
