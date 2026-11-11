import EventKit
import SwiftUI

struct CalendarHomeView: View {
    @EnvironmentObject private var calendarService: CalendarService
    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var editing: EventEditTarget?
    @State private var showCategories = false

    var body: some View {
        NavigationStack {
            Group {
                if calendarService.isAuthorized {
                    content
                } else {
                    accessView
                }
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if calendarService.isAuthorized {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("カテゴリ") { showCategories = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("今日") {
                            month = Calendar.current.startOfMonth(for: .now)
                            selectedDate = Calendar.current.startOfDay(for: .now)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editing = .new(selectedDate)
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(item: $editing) { target in
                EventEditView(target: target)
            }
            .sheet(isPresented: $showCategories) {
                NavigationStack {
                    CategoryManageView(showsDoneButton: true)
                }
            }
        }
    }

    private var accessView: some View {
        ContentUnavailableView {
            Label("カレンダーへのアクセス", systemImage: "calendar")
        } description: {
            Text("iPhoneの標準カレンダーの予定を表示・追加するために、カレンダーへのフルアクセスを許可してください。")
        } actions: {
            if calendarService.needsSettingsApp {
                Button("設定アプリを開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("許可する") {
                    Task { await calendarService.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var content: some View {
        let calendar = Calendar.current
        let days = MonthGrid.days(for: month, calendar: calendar)
        let eventsByDay = MonthGrid.eventsByDay(
            calendarService.events(from: days.first ?? month,
                                   to: calendar.date(byAdding: .day, value: 1, to: days.last ?? month) ?? month),
            calendar: calendar
        )
        let selectedEvents = eventsByDay[selectedDate] ?? []
        _ = calendarService.changeToken

        return List {
            Section {
                MonthGridView(month: $month, selectedDate: $selectedDate, days: days, eventsByDay: eventsByDay)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            Section(DateText.day(selectedDate)) {
                if selectedEvents.isEmpty {
                    Text("予定はありません")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(selectedEvents.enumerated()), id: \.offset) { _, event in
                    Button {
                        editing = .edit(event)
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.calendar.swiftUIColor)
                                .frame(width: 4)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(event.title ?? "（タイトルなし）")
                                        .foregroundStyle(.primary)
                                    if event.hasRecurrenceRules {
                                        Image(systemName: "repeat")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text("\(event.timeText)・\(event.calendar.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

enum MonthGrid {
    /// 月表示に並べる42日分（日曜始まり）
    static func days(for month: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfMonth(for: month)
        let offset = (calendar.component(.weekday, from: start) - 1 + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// 日付（0時）ごとの予定。複数日にまたがる予定はそれぞれの日に入れる
    static func eventsByDay(_ events: [EKEvent], calendar: Calendar) -> [Date: [EKEvent]] {
        var result: [Date: [EKEvent]] = [:]
        for event in events {
            guard let start = event.startDate, let end = event.endDate else { continue }
            var day = calendar.startOfDay(for: start)
            // 0:00ちょうどに終わる予定は前日までとして扱う
            let lastMoment = end > start ? end.addingTimeInterval(-1) : start
            let lastDay = calendar.startOfDay(for: lastMoment)
            var guardCount = 0
            while day <= lastDay && guardCount < 400 {
                result[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                guardCount += 1
            }
        }
        for key in result.keys {
            result[key]?.sort { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.startDate < b.startDate
            }
        }
        return result
    }
}

struct MonthGridView: View {
    @Binding var month: Date
    @Binding var selectedDate: Date
    let days: [Date]
    let eventsByDay: [Date: [EKEvent]]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let calendar = Calendar.current
        VStack(spacing: 8) {
            HStack {
                Button {
                    month = calendar.date(byAdding: .month, value: -1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Spacer()
                Text(month.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                Spacer()
                Button {
                    month = calendar.date(byAdding: .month, value: 1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(1...7, id: \.self) { weekday in
                    Text(Weekday.name(weekday))
                        .font(.caption2)
                        .foregroundStyle(weekday == 1 ? .red : weekday == 7 ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                }
                ForEach(days, id: \.self) { day in
                    DayCell(
                        day: day,
                        isInMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(day),
                        colors: dotColors(for: day)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = day
                        if !calendar.isDate(day, equalTo: month, toGranularity: .month) {
                            month = calendar.startOfMonth(for: day)
                        }
                    }
                }
            }
        }
    }

    /// その日の予定のカテゴリ色（最大3色）
    private func dotColors(for day: Date) -> [Color] {
        var seen: [String] = []
        var colors: [Color] = []
        for event in eventsByDay[day] ?? [] {
            let id = event.calendar.calendarIdentifier
            if !seen.contains(id) {
                seen.append(id)
                colors.append(event.calendar.swiftUIColor)
            }
            if colors.count == 3 { break }
        }
        return colors
    }
}

private struct DayCell: View {
    let day: Date
    let isInMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let colors: [Color]

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(foreground)
                .frame(width: 30, height: 30)
                .background {
                    if isSelected {
                        Circle().fill(isToday ? Color.red : Color.accentColor)
                    } else if isToday {
                        Circle().stroke(Color.red, lineWidth: 1)
                    }
                }
            HStack(spacing: 2) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .opacity(isInMonth ? 1 : 0.35)
    }

    private var foreground: Color {
        if isSelected { return .white }
        if isToday { return .red }
        return .primary
    }
}
