// TodayWeekBoard.swift
// fitbod
//
// Today's week at a glance (RM-010): seven day tiles and the week's working
// sets and workouts. The whole board opens Volume, where the per-muscle
// landmarks live. In a block it sits under the plan line, which names the
// block and week; without one it names the week itself.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO Image(systemName:)

import SwiftUI

/// Screens Today pushes that no other tab owns.
enum TodayRoute: Hashable {
    /// Volume: every muscle's sets against its landmarks.
    case volume
}

struct TodayWeekBoard: View {
    let week: TodayWeek
    /// Without a block, the board heads itself "This week · Nov 9–15".
    let showsHeader: Bool
    /// What today's tile says when no workout is finished today:
    /// "REST" on a rest day, "LIVE" while a workout is open, else nothing.
    let todayNote: String?
    /// A rest day draws today's tile dashed.
    let isRestDay: Bool
    let onOpenVolume: () -> Void

    var body: some View {
        Button(action: onOpenVolume) {
            VStack(alignment: .leading, spacing: 12) {
                if showsHeader {
                    Text("This week · \(week.rangeLabel)")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                }
                HStack(spacing: 4) {
                    ForEach(week.days) { tile($0) }
                }
                footer
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bruBg2)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.bruHair).frame(height: 1) }
        }
        .buttonStyle(.bruRow)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
        .accessibilityHint("Opens Volume")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("today.weekBoard")
    }

    // MARK: - Pieces

    private var footer: some View {
        HStack(spacing: 12) {
            if week.workouts == 0 {
                Text("No workouts yet this week.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            } else {
                Text(totals)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
            }
            Spacer(minLength: 0)
            Text("Volume ›")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruInk)
        }
    }

    private func tile(_ day: TodayWeek.Day) -> some View {
        let done = day.workouts > 0
        let lines: [String] = if done {
            [day.workoutName ?? "Workout", "\(day.workingSets)"]
        } else if day.isToday, let todayNote {
            [todayNote]
        } else {
            []
        }
        return VStack(alignment: .leading, spacing: 0) {
            Text(day.label)
                .font(BRUFont.labelMicro)
                .tracking(0.8)
            Spacer(minLength: 4)
            ForEach(lines.indices, id: \.self) { index in
                Text(lines[index])
                    .font(BRUFont.labelMicro)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(done ? Color.bruPaper : (day.isToday ? Color.bruInk : Color.bruMuted))
        .padding(5)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
        .background(done ? Color.bruInk : Color.clear)
        .overlay {
            if day.isToday {
                Rectangle().strokeBorder(
                    Color.bruSignal,
                    style: StrokeStyle(lineWidth: 2.5, dash: isRestDay && !done ? [5, 3] : [])
                )
            } else if !done {
                Rectangle().strokeBorder(Color.bruHair, lineWidth: 1.5)
            }
        }
    }

    // MARK: - Copy

    private var totals: String {
        "\(BRUCountLabel.text(week.workingSets, "working set")) · \(BRUCountLabel.text(week.workouts, "workout"))"
    }

    private var spokenSummary: String {
        let done = week.days.filter { $0.workouts > 0 }
            .map { "\($0.date.formatted(.dateTime.weekday(.wide))), \($0.workoutName ?? "Workout")" }
        let summary = week.workouts == 0 ? "No workouts yet" : totals
        return (["This week", summary] + done + (isRestDay ? ["Today is a rest day"] : [])).joined(separator: ". ")
    }
}
