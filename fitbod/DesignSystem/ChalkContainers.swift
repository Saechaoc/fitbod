//
//  ChalkContainers.swift
//  fitbod
//
//  Chalkline structure: screen + section headers with ink rules, paper
//  cards, iron panels, metric readouts, inline messages, empty states,
//  and the thumb-zone bottom action bar.
//

import SwiftUI

// MARK: - Headers

/// In-content screen header: optional overline, condensed display title,
/// heavy 3 pt ink rule. Marked as a heading for VoiceOver rotor navigation.
public struct ChalkScreenHeader<Trailing: View>: View {
    let title: String
    let overline: String?
    let subtitle: String?
    let trailing: Trailing

    public init(
        _ title: String,
        overline: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.overline = overline
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.xs) {
            if let overline {
                Text(overline).chalkLabelStyle()
            }
            HStack(alignment: .lastTextBaseline, spacing: Chalk.Space.md) {
                Text(title)
                    .font(.chalkDisplay)
                    .textCase(.uppercase)
                    .foregroundStyle(.chalkInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                trailing
            }
            if let subtitle {
                Text(subtitle)
                    .font(.chalkFootnote)
                    .foregroundStyle(.chalkInk2)
            }
            Rectangle()
                .fill(Color.chalkInk)
                .frame(height: Chalk.Line.heavy)
                .accessibilityHidden(true)
        }
    }
}

extension ChalkScreenHeader where Trailing == EmptyView {
    public init(_ title: String, overline: String? = nil, subtitle: String? = nil) {
        self.init(title, overline: overline, subtitle: subtitle) { EmptyView() }
    }
}

/// Section header: condensed caps title, optional trailing accessory,
/// 1.5 pt ink rule beneath.
public struct ChalkSectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    public init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.sm) {
                Text(title)
                    .font(.chalkSubtitle)
                    .textCase(.uppercase)
                    .tracking(Chalk.Tracking.title)
                    .foregroundStyle(.chalkInk)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                trailing
            }
            Rectangle()
                .fill(Color.chalkInk)
                .frame(height: Chalk.Line.strong)
                .accessibilityHidden(true)
        }
    }
}

extension ChalkSectionHeader where Trailing == EmptyView {
    public init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

// MARK: - Card + panel

/// Paper card: surface fill, hairline outline, 16 pt radius.
public struct ChalkCard<Content: View>: View {
    let padding: CGFloat
    let emphasized: Bool
    let content: Content

    public init(padding: CGFloat = Chalk.Space.md, emphasized: Bool = false, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.emphasized = emphasized
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.chalkSurface, in: RoundedRectangle(cornerRadius: Chalk.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Chalk.Radius.lg, style: .continuous)
                    .strokeBorder(
                        emphasized ? Color.chalkInk : Color.chalkDivider,
                        lineWidth: emphasized ? Chalk.Line.strong : Chalk.Line.hairline
                    )
            }
    }
}

/// Iron panel — reserved for live state (active workout, rest timer,
/// resume card, a finished workout's hero). Content should use the
/// on-panel colors.
public struct ChalkPanel<Content: View>: View {
    let padding: CGFloat
    let radius: CGFloat
    let content: Content

    public init(padding: CGFloat = Chalk.Space.lg, radius: CGFloat = Chalk.Radius.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.chalkOnPanel)
            .background(Color.chalkPanel, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.chalkPanelBorder, lineWidth: Chalk.Line.hairline)
            }
            // A container element: children stay individually focusable,
            // and an identifier on the panel lands on one element.
            .accessibilityElement(children: .contain)
    }
}

// MARK: - Metric

/// A label + number readout. `onPanel` switches to panel colors.
public struct ChalkMetric: View {
    public enum Emphasis: Sendable { case regular, large }

    let label: String
    let value: String
    let caption: String?
    let onPanel: Bool
    let emphasis: Emphasis
    let valueColor: Color?

    public init(
        _ label: String,
        value: String,
        caption: String? = nil,
        onPanel: Bool = false,
        emphasis: Emphasis = .regular,
        valueColor: Color? = nil
    ) {
        self.label = label
        self.value = value
        self.caption = caption
        self.onPanel = onPanel
        self.emphasis = emphasis
        self.valueColor = valueColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
            Text(label)
                .chalkLabelStyle(color: onPanel ? .chalkOnPanel2 : .chalkInk2)
            Text(value)
                .font(emphasis == .large ? .chalkMetricLarge : .chalkMetric)
                .foregroundStyle(valueColor ?? (onPanel ? Color.chalkOnPanel : Color.chalkInk))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption)
                    .font(.chalkFootnote)
                    .foregroundStyle(onPanel ? Color.chalkOnPanel2 : Color.chalkInk2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A metric inside its own paper tile.
public struct ChalkMetricTile: View {
    let label: String
    let value: String
    let caption: String?

    public init(_ label: String, value: String, caption: String? = nil) {
        self.label = label
        self.value = value
        self.caption = caption
    }

    public var body: some View {
        ChalkCard(padding: Chalk.Space.md) {
            ChalkMetric(label, value: value, caption: caption)
        }
    }
}

// MARK: - Progress bar

/// Thin accent progress bar on a raised track (panel or paper).
public struct ChalkProgressBar: View {
    let progress: Double
    let onPanel: Bool

    public init(progress: Double, onPanel: Bool = true) {
        self.progress = progress
        self.onPanel = onPanel
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(onPanel ? Color.chalkPanelRaised : Color.chalkSunken)
                Capsule()
                    .fill(Color.chalkAccent)
                    .frame(width: proxy.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Inline message

/// Inline banner. `.error` is used for validation summaries ("Fix 2
/// things to save…"), `.info` for neutral context.
public struct ChalkInlineMessage: View {
    public enum Kind: Sendable { case error, info }

    let kind: Kind
    let message: String

    public init(_ message: String, kind: Kind = .info) {
        self.message = message
        self.kind = kind
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.sm) {
            Image(systemName: kind == .error ? "exclamationmark.circle.fill" : "info.circle")
                .accessibilityHidden(true)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(kind == .error ? Font.subheadline.weight(.semibold) : .subheadline)
        .foregroundStyle(kind == .error ? Color.chalkDanger : Color.chalkInk)
        .padding(.horizontal, Chalk.Space.md)
        .padding(.vertical, Chalk.Space.md)
        .background(
            kind == .error ? Color.chalkSurface : Color.chalkSunken,
            in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                .strokeBorder(kind == .error ? Color.chalkDanger : Color.clear, lineWidth: Chalk.Line.strong)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty state

/// Dashed-outline empty state with a condensed title, one sentence, and
/// up to two actions (primary accent + secondary outline).
public struct ChalkEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    let primaryTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String,
        primaryTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.chalkInk2)
                .accessibilityHidden(true)
            Text(title)
                .font(.chalkTitle)
                .textCase(.uppercase)
                .foregroundStyle(.chalkInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.chalkBody)
                .foregroundStyle(.chalkInk2)
                .fixedSize(horizontal: false, vertical: true)
            if let primaryTitle, let primaryAction {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.chalk(.primary, size: .large, fullWidth: true))
                    .padding(.top, Chalk.Space.xs)
            }
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.chalk(.secondary, fullWidth: true))
            }
        }
        .padding(Chalk.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: Chalk.Radius.lg, style: .continuous)
                .strokeBorder(Color.chalkDivider, style: StrokeStyle(lineWidth: Chalk.Line.strong, dash: [6, 4]))
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Bottom action bar

/// Thumb-zone container for a screen's primary action, docked above the
/// home indicator via `.safeAreaInset(edge: .bottom)`.
public struct ChalkBottomBar<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.chalkDivider)
                .frame(height: Chalk.Line.hairline)
            content
                .padding(.horizontal, Chalk.Space.gutter)
                .padding(.top, Chalk.Space.md)
                .padding(.bottom, Chalk.Space.sm)
        }
        .background(Color.chalkCanvas)
    }
}

#Preview("Containers") {
    ScrollView {
        VStack(alignment: .leading, spacing: Chalk.Space.xl) {
            ChalkScreenHeader("Push Day A", overline: "Saturday · Oct 4", subtitle: "4 exercises · 14 sets")
            ChalkSectionHeader("Your history") {
                Button("See all") {}.buttonStyle(.chalk(.ghost, size: .compact))
            }
            ChalkPanel {
                HStack {
                    ChalkMetric("Elapsed", value: "32:14", onPanel: true)
                    ChalkMetric("Sets", value: "7/14", onPanel: true)
                    ChalkMetric("Volume lb", value: "8,450", onPanel: true)
                }
            }
            HStack {
                ChalkMetricTile("Best set", value: "205 × 3", caption: "+10 lb vs last")
                ChalkMetricTile("Est. 1RM", value: "225")
            }
            ChalkInlineMessage("Fix 2 things to save: name the routine and add an exercise.", kind: .error)
            ChalkInlineMessage("Previous values come from your last strength session.")
            ChalkEmptyState(
                systemImage: "list.bullet.rectangle",
                title: "No routines yet",
                message: "Build a routine to start logging workouts.",
                primaryTitle: "New routine",
                primaryAction: {}
            )
        }
        .padding()
    }
    .background(Color.chalkCanvas)
}
