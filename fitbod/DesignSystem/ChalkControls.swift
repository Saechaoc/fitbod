//
//  ChalkControls.swift
//  fitbod
//
//  Chalkline input + selection controls: filter chips, tags, the search
//  field, labelled text fields with inline errors, and the ± stepper.
//
//  Every control here keeps a ≥ 44 pt hit area and exposes its value to
//  VoiceOver (chips announce selection + count; steppers are adjustable).
//

import SwiftUI

// MARK: - Filter chip

/// A filter chip. Idle = paper with an ink outline; selected = inverted
/// (ink fill, canvas text) with an optional "+N" count for multi-select.
public struct ChalkChip: View {
    let title: String
    let isSelected: Bool
    let extraCount: Int
    let showsMenuIndicator: Bool
    let a11yLabel: String?
    let action: () -> Void

    public init(
        _ title: String,
        isSelected: Bool,
        extraCount: Int = 0,
        showsMenuIndicator: Bool = false,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.extraCount = extraCount
        self.showsMenuIndicator = showsMenuIndicator
        self.a11yLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Chalk.Space.xs) {
                Text(title)
                if extraCount > 0 {
                    Text("+\(extraCount)")
                }
                if showsMenuIndicator {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .font(.chalkChip)
            .textCase(.uppercase)
            .tracking(Chalk.Tracking.label)
            .lineLimit(1)
            .foregroundStyle(isSelected ? Color.chalkCanvas : Color.chalkInk)
            .padding(.horizontal, Chalk.Space.md)
            .frame(minHeight: Chalk.Size.chip)
            .background(
                isSelected ? Color.chalkInk : Color.chalkSurface,
                in: RoundedRectangle(cornerRadius: Chalk.Radius.sm, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Chalk.Radius.sm, style: .continuous)
                    .strokeBorder(Color.chalkInk, lineWidth: Chalk.Line.strong)
            }
            .frame(minHeight: Chalk.Size.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(a11yLabel ?? title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Tag

/// Small non-interactive label (intent, CUSTOM, NEXT, equipment).
public struct ChalkTag: View {
    public enum Style: Sendable {
        /// Ink fill, canvas text — the emphasized tag (e.g. STRENGTH).
        case solid
        /// Ink outline.
        case outline
        /// Sunken fill, accent-ink text — CUSTOM.
        case subtle
        /// Accent fill — NEXT.
        case accent
        /// Raised iron on a panel.
        case onPanel
    }

    let text: String
    let style: Style

    public init(_ text: String, style: Style = .outline) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(.chalkLabel)
            .textCase(.uppercase)
            .tracking(Chalk.Tracking.label)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, Chalk.Space.sm - 1)
            .padding(.vertical, Chalk.Space.xxs + 1)
            .background(fill, in: RoundedRectangle(cornerRadius: Chalk.Radius.sm, style: .continuous))
            .overlay {
                if style == .outline {
                    RoundedRectangle(cornerRadius: Chalk.Radius.sm, style: .continuous)
                        .strokeBorder(Color.chalkInk, lineWidth: Chalk.Line.hairline)
                }
            }
    }

    private var foreground: Color {
        switch style {
        case .solid: return .chalkCanvas
        case .outline: return .chalkInk
        case .subtle: return .chalkAccentInk
        case .accent: return .chalkOnAccent
        case .onPanel: return .chalkOnPanel
        }
    }

    private var fill: Color {
        switch style {
        case .solid: return .chalkInk
        case .outline: return .clear
        case .subtle: return .chalkSunken
        case .accent: return .chalkAccent
        case .onPanel: return .chalkPanelRaised
        }
    }
}

// MARK: - Search field

/// Sunken search well with a clear button. Owns its own focus so callers
/// only bind text.
public struct ChalkSearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, prompt: String) {
        self._text = text
        self.prompt = prompt
    }

    public var body: some View {
        HStack(spacing: Chalk.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(.chalkInk2)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Color.chalkInk3))
                .font(.chalkBody)
                .foregroundStyle(.chalkInk)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .accessibilityIdentifier("library.search")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.chalkInk2)
                        .frame(width: Chalk.Size.minTouch, height: Chalk.Size.minTouch)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, Chalk.Space.md)
        .padding(.trailing, text.isEmpty ? Chalk.Space.md : 0)
        .frame(minHeight: Chalk.Size.minTouch)
        .background(Color.chalkSunken, in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                .strokeBorder(isFocused ? Color.chalkAccent : Color.clear, lineWidth: Chalk.Line.focus)
        }
    }
}

// MARK: - Labelled text field

/// Form text field with an overline label and an optional inline error.
/// The error renders below the field (danger outline + icon + words) and
/// is announced as part of the field's accessibility value.
public struct ChalkTextField: View {
    let label: String
    @Binding var text: String
    let prompt: String
    let error: String?
    let isProminent: Bool
    let identifier: String?
    @FocusState private var isFocused: Bool

    public init(
        _ label: String,
        text: Binding<String>,
        prompt: String,
        error: String? = nil,
        isProminent: Bool = false,
        identifier: String? = nil
    ) {
        self.label = label
        self._text = text
        self.prompt = prompt
        self.error = error
        self.isProminent = isProminent
        self.identifier = identifier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.xs + 2) {
            Text(label)
                .chalkLabelStyle()
                .accessibilityHidden(true)
            TextField(label, text: $text, prompt: Text(prompt).foregroundStyle(Color.chalkInk3))
                .font(isProminent ? Font.title3.weight(.semibold) : .chalkBody)
                .foregroundStyle(.chalkInk)
                .focused($isFocused)
                .padding(.horizontal, Chalk.Space.md)
                .frame(minHeight: isProminent ? 52 : Chalk.Size.minTouch)
                .background(
                    error == nil ? Color.chalkSunken : Color.chalkSurface,
                    in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: error == nil ? Chalk.Line.focus : Chalk.Line.strong)
                }
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text(error.map { "\(text). Error: \($0)" } ?? text))
                .accessibilityIdentifier(identifier ?? label)
            if let error {
                ChalkValidationText(error)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return .chalkDanger }
        return isFocused ? .chalkAccent : .clear
    }
}

/// One-line inline validation message: danger icon + words (never color
/// alone).
public struct ChalkValidationText: View {
    let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.chalkDanger)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stepper

/// `−  value  +` stepper with 44 pt targets, ink outline, condensed
/// numerals. VoiceOver treats it as one adjustable element.
public struct ChalkStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let format: (Int) -> String
    let compact: Bool
    let identifier: String?

    public init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        compact: Bool = false,
        identifier: String? = nil,
        format: @escaping (Int) -> String = { "\($0)" }
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.compact = compact
        self.identifier = identifier
        self.format = format
    }

    public var body: some View {
        HStack(spacing: 0) {
            stepButton(systemImage: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }
            Text(format(value))
                .font(.chalkMetric)
                .foregroundStyle(.chalkInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: compact ? 30 : 44)
                .padding(.horizontal, Chalk.Space.xs)
            stepButton(systemImage: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .background(Color.chalkSurface, in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                .strokeBorder(Color.chalkInk, lineWidth: Chalk.Line.strong)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(format(value)))
        .accessibilityIdentifier(identifier ?? title)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(enabled ? Color.chalkInk : Color.chalkInk3)
                .frame(width: compact ? 36 : Chalk.Size.minTouch, height: Chalk.Size.minTouch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// A labelled stepper row ("Sets  − 4 +") with a hairline above, used in
/// the routine builder.
public struct ChalkStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let identifier: String?
    let format: (Int) -> String

    public init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        identifier: String? = nil,
        format: @escaping (Int) -> String = { "\($0)" }
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.identifier = identifier
        self.format = format
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).font(.chalkBody).foregroundStyle(.chalkInk)
                Spacer(minLength: Chalk.Space.sm)
                ChalkStepper(title, value: $value, in: range, step: step, identifier: identifier, format: format)
            }
            VStack(alignment: .leading, spacing: Chalk.Space.xs) {
                Text(title).font(.chalkBody).foregroundStyle(.chalkInk)
                ChalkStepper(title, value: $value, in: range, step: step, identifier: identifier, format: format)
            }
        }
        .padding(.vertical, Chalk.Space.xs)
    }
}

// MARK: - Formatting helpers shared by controls

public enum ChalkFormat {
    /// "3:00", "1:30", "0:45".
    public static func duration(seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "1:09:14" when ≥ 1 h, else "32:14".
    public static func clock(seconds: Int) -> String {
        let s = max(0, seconds)
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "185", "187.5", "-20" — trims trailing zeros.
    public static func weight(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// "8", "8.5".
    public static func rpe(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// "16,940" / "31.4K" for big totals.
    public static func volume(_ value: Double) -> String {
        if value >= 100_000 {
            return String(format: "%.0fK", value / 1000)
        }
        if value >= 10_000 {
            return String(format: "%.1fK", value / 1000)
        }
        return Int(value.rounded()).formatted(.number)
    }
}

#Preview("Controls") {
    @Previewable @State var search = ""
    @Previewable @State var sets = 4
    @Previewable @State var name = ""
    return ScrollView {
        VStack(alignment: .leading, spacing: Chalk.Space.lg) {
            ChalkSearchField(text: $search, prompt: "Search 702 exercises")
            HStack {
                ChalkChip("Muscle", isSelected: false, showsMenuIndicator: true) {}
                ChalkChip("Chest", isSelected: true, extraCount: 1, showsMenuIndicator: true) {}
                ChalkChip("Custom", isSelected: false) {}
            }
            HStack {
                ChalkTag("Strength", style: .solid)
                ChalkTag("Hypertrophy")
                ChalkTag("Custom", style: .subtle)
                ChalkTag("Next", style: .accent)
            }
            ChalkStepperRow("Sets", value: $sets, in: 1...20)
            ChalkTextField("Routine name", text: $name, prompt: "e.g. Push Day A", error: "Give this routine a name.", isProminent: true)
        }
        .padding()
    }
    .background(Color.chalkCanvas)
}
