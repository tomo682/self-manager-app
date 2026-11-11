import EventKit
import SwiftUI

enum EventEditTarget: Identifiable {
    case new(Date)
    case edit(EKEvent)

    var id: String {
        switch self {
        case .new(let date): return "new-\(date.timeIntervalSince1970)"
        case .edit(let event): return "\(event.eventIdentifier ?? "")-\(event.startDate.timeIntervalSince1970)"
        }
    }
}

enum RepeatOption: String, CaseIterable, Identifiable {
    case none = "なし"
    case daily = "毎日"
    case weekly = "毎週"
    case monthly = "毎月"
    case yearly = "毎年"

    var id: String { rawValue }

    var frequency: EKRecurrenceFrequency? {
        switch self {
        case .none: return nil
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        }
    }

    init(frequency: EKRecurrenceFrequency?) {
        switch frequency {
        case .daily: self = .daily
        case .weekly: self = .weekly
        case .monthly: self = .monthly
        case .yearly: self = .yearly
        default: self = .none
        }
    }
}

struct EventEditView: View {
    let target: EventEditTarget

    @EnvironmentObject private var calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var isAnnualEvent = false
    @State private var isAllDay = false
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(3600)
    @State private var calendarID = ""
    @State private var repeatOption: RepeatOption = .none
    @State private var notes = ""
    @State private var pendingAction: PendingAction?
    @State private var errorMessage: String?
    @State private var loaded = false

    enum PendingAction: Identifiable {
        case save, delete
        var id: Int { self == .save ? 0 : 1 }
    }

    private var existingEvent: EKEvent? {
        if case .edit(let event) = target { return event }
        return nil
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル", text: $title)
                    Toggle("イベント（誕生日など・終日で毎年）", isOn: $isAnnualEvent)
                }

                Section {
                    Toggle("終日", isOn: $isAllDay)
                        .disabled(isAnnualEvent)
                    DatePicker("開始", selection: $start,
                               displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("終了", selection: $end, in: start...,
                               displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                }

                Section {
                    Picker("カテゴリ", selection: $calendarID) {
                        ForEach(calendarService.writableCalendars, id: \.calendarIdentifier) { cal in
                            Label {
                                Text(cal.title)
                            } icon: {
                                Image(systemName: "circle.fill").foregroundStyle(cal.swiftUIColor)
                            }
                            .tag(cal.calendarIdentifier)
                        }
                    }
                    Picker("繰り返し", selection: $repeatOption) {
                        ForEach(RepeatOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .disabled(isAnnualEvent)
                } footer: {
                    Text(repeatFooter)
                }

                Section {
                    TextField("メモ", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if existingEvent != nil {
                    Section {
                        Button("この予定を削除", role: .destructive) {
                            if existingEvent?.hasRecurrenceRules == true {
                                pendingAction = .delete
                            } else {
                                perform(.delete, span: .thisEvent)
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingEvent == nil ? "新しい予定" : "予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if existingEvent?.hasRecurrenceRules == true {
                            pendingAction = .save
                        } else {
                            perform(.save, span: .thisEvent)
                        }
                    }
                    .disabled(trimmedTitle.isEmpty || calendarID.isEmpty)
                }
            }
            .onChange(of: isAnnualEvent) { _, annual in
                if annual {
                    isAllDay = true
                    repeatOption = .yearly
                }
            }
            .onChange(of: start) { _, newStart in
                if end < newStart {
                    end = isAllDay ? newStart : newStart.addingTimeInterval(3600)
                }
            }
            .confirmationDialog(
                "繰り返しの予定です",
                isPresented: Binding(presenting: $pendingAction),
                titleVisibility: .visible,
                presenting: pendingAction
            ) { action in
                Button("この予定のみ") { perform(action, span: .thisEvent) }
                Button("これ以降のすべての予定") { perform(action, span: .futureEvents) }
            }
            .alert("エラー", isPresented: Binding(presenting: $errorMessage), presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .onAppear(perform: load)
        }
    }

    private var repeatFooter: String {
        let day = Calendar.current.component(.day, from: start)
        switch repeatOption {
        case .none: return ""
        case .daily: return "毎日繰り返します。"
        case .weekly: return "毎週\(Weekday.name(Calendar.current.component(.weekday, from: start)))曜日に繰り返します。"
        case .monthly: return "毎月\(day)日に繰り返します。"
        case .yearly: return "毎年\(start.formatted(.dateTime.month().day()))に繰り返します。"
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch target {
        case .new(let date):
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                let nextHour = calendar.nextDate(after: .now, matching: DateComponents(minute: 0),
                                                 matchingPolicy: .nextTime) ?? .now
                start = nextHour
            } else {
                start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            }
            end = start.addingTimeInterval(3600)
            let defaultID = calendarService.defaultCalendar.flatMap {
                $0.allowsContentModifications ? $0.calendarIdentifier : nil
            }
            calendarID = defaultID ?? calendarService.writableCalendars.first?.calendarIdentifier ?? ""
        case .edit(let event):
            title = event.title ?? ""
            isAllDay = event.isAllDay
            start = event.startDate
            end = event.endDate
            calendarID = event.calendar.calendarIdentifier
            repeatOption = RepeatOption(frequency: event.recurrenceRules?.first?.frequency)
            isAnnualEvent = event.isAllDay && repeatOption == .yearly
            notes = event.notes ?? ""
        }
    }

    private func perform(_ action: PendingAction, span: EKSpan) {
        do {
            switch action {
            case .save:
                let event = existingEvent ?? calendarService.newEvent()
                event.title = trimmedTitle
                event.isAllDay = isAllDay
                event.startDate = start
                event.endDate = max(end, start)
                event.notes = notes.isEmpty ? nil : notes
                guard let calendar = calendarService.calendar(withIdentifier: calendarID) else {
                    throw CalendarError.calendarNotFound
                }
                event.calendar = calendar
                if let frequency = repeatOption.frequency {
                    event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil)]
                } else {
                    event.recurrenceRules = nil
                }
                try calendarService.save(event, span: span)
            case .delete:
                if let event = existingEvent {
                    try calendarService.delete(event, span: span)
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
