import SwiftData
import SwiftUI

/// 「いつやる？」：空き時間を3つ提案し、選んだ枠を標準カレンダーに登録する
struct SlotSuggestionView: View {
    let title: String
    let deadline: Date?

    @EnvironmentObject private var calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @Query private var habits: [HabitSchedule]
    @AppStorage(AppSettings.noDeadlineSearchDaysKey) private var searchDays = AppSettings.defaultNoDeadlineSearchDays

    @State private var minutes = 60
    @State private var slots: [DateInterval]?
    @State private var selectedSlot: DateInterval?
    @State private var message: String?
    @State private var added = false

    private var searchEnd: Date {
        deadline ?? Calendar.current.date(byAdding: .day, value: searchDays, to: .now) ?? .now
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(title).font(.headline)
                }

                Section("所要時間") {
                    Stepper(durationText, value: $minutes, in: 15...600, step: 15)
                }

                Section {
                    Button {
                        search()
                    } label: {
                        Label("空き時間を探す", systemImage: "magnifyingglass")
                    }
                } footer: {
                    Text(rangeText)
                }

                if let slots {
                    Section("候補（タップでカレンダーに追加）") {
                        if slots.isEmpty {
                            Text("期限までに空き時間が見つかりませんでした。所要時間を短くしてみてください。")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(slots, id: \.start) { slot in
                            Button {
                                selectedSlot = slot
                            } label: {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                    Text(DateText.range(slot))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("いつやる？")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog(
                "カレンダーに追加しますか？",
                isPresented: Binding(presenting: $selectedSlot),
                titleVisibility: .visible,
                presenting: selectedSlot
            ) { slot in
                Button("追加する") { add(slot) }
            } message: { slot in
                Text("「\(title)」\n\(DateText.range(slot))")
            }
            .alert(added ? "追加しました" : "お知らせ",
                   isPresented: Binding(presenting: $message),
                   presenting: message) { _ in
                Button("OK") { if added { dismiss() } }
            } message: { message in
                Text(message)
            }
            .task {
                if !calendarService.isAuthorized && !calendarService.needsSettingsApp {
                    await calendarService.requestAccess()
                }
            }
        }
    }

    private var durationText: String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)分" }
        return m == 0 ? "\(h)時間" : "\(h)時間\(m)分"
    }

    private var rangeText: String {
        if let deadline {
            return "今から期限（\(DateText.short(deadline))）までの間で、別々の日から3つ提案します。"
        }
        return "期限がないので、今から\(searchDays)日先までの間で、別々の日から3つ提案します（日数は設定で変更できます）。"
    }

    private func search() {
        guard calendarService.isAuthorized else {
            message = "カレンダーへのアクセスが許可されていません。設定アプリ →「プライバシーとセキュリティ」→「カレンダー」で「フルアクセス」にしてください。"
            return
        }
        let now = Date.now
        let end = searchEnd
        guard end > now else {
            message = "期限を過ぎています。"
            return
        }
        let eventBusy = calendarService.events(from: now, to: end)
            .filter { !$0.isAllDay }
            .compactMap { event -> DateInterval? in
                guard let s = event.startDate, let e = event.endDate, e > s else { return nil }
                return DateInterval(start: s, end: e)
            }
        let habitBusy = SlotFinder.habitIntervals(habits.filter(\.isEnabled).map(\.rule), from: now, to: end)
        slots = SlotFinder.suggest(duration: TimeInterval(minutes * 60), from: now, to: end,
                                   busy: eventBusy + habitBusy, count: 3)
    }

    private func add(_ slot: DateInterval) {
        do {
            try calendarService.addTaskEvent(title: title, interval: slot)
            let calendarName = (try? calendarService.taskCalendar().title) ?? "To do"
            added = true
            message = "「\(calendarName)」カレンダーに追加しました。\n\(DateText.range(slot))"
        } catch {
            added = false
            message = error.localizedDescription
        }
    }
}
