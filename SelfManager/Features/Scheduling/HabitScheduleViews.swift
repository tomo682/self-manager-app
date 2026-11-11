import SwiftData
import SwiftUI

/// 習慣的な予定（学校・睡眠など）の一覧
struct HabitScheduleListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HabitSchedule.createdAt) private var habits: [HabitSchedule]
    @State private var editing: HabitEditTarget?

    var body: some View {
        List {
            Section {
                if habits.isEmpty {
                    Text("まだ登録されていません")
                        .foregroundStyle(.secondary)
                }
                ForEach(habits) { habit in
                    Button {
                        editing = .edit(habit)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(habit.name).foregroundStyle(.primary)
                                if !habit.isEnabled {
                                    Text("停止中")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(HabitDescription.text(for: habit))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(habits[index]) }
                    try? context.save()
                }
            } footer: {
                Text("ここに登録した時間は、「いつやる？」の空き時間の提案から外れます。カレンダーには表示されません。")
            }
        }
        .navigationTitle("習慣的な予定")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = .new
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editing) { target in
            HabitScheduleEditView(target: target)
        }
    }
}

enum HabitEditTarget: Identifiable {
    case new
    case edit(HabitSchedule)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let h): return h.id.uuidString
        }
    }
}

enum HabitDescription {
    static func text(for habit: HabitSchedule) -> String {
        let days = habit.weekdays.sorted().map(Weekday.name).joined()
        let start = timeText(habit.startMinutes)
        let end = timeText(habit.endMinutes)
        let overnight = habit.endMinutes <= habit.startMinutes ? "翌" : ""
        var text = "\(days.isEmpty ? "曜日未設定" : days) \(start)〜\(overnight)\(end)"
        if habit.validFrom != nil || habit.validTo != nil {
            let from = habit.validFrom.map(DateText.fullDay) ?? ""
            let to = habit.validTo.map(DateText.fullDay) ?? ""
            text += "（\(from)〜\(to)）"
        }
        if !habit.exceptionDates.isEmpty {
            text += " 例外\(habit.exceptionDates.count)日"
        }
        return text
    }

    static func timeText(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

struct HabitScheduleEditView: View {
    let target: HabitEditTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var weekdays: Set<Int> = []
    @State private var startTime = Calendar.current.date(on: .now, minutes: 8 * 60 + 30)
    @State private var endTime = Calendar.current.date(on: .now, minutes: 16 * 60)
    @State private var hasValidity = false
    @State private var validFrom = Date()
    @State private var validTo = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var exceptions: [Date] = []
    @State private var newException = Date()
    @State private var isEnabled = true
    @State private var loaded = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var startMinutes: Int { Calendar.current.minutesFromMidnight(startTime) }
    private var endMinutes: Int { Calendar.current.minutesFromMidnight(endTime) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前（例：学校、睡眠）", text: $name)
                }

                Section("曜日") {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            let on = weekdays.contains(day)
                            Text(Weekday.name(day))
                                .font(.callout.bold())
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(on ? Color.accentColor : Color.gray.opacity(0.15),
                                            in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(on ? .white : .primary)
                                .onTapGesture {
                                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                                }
                        }
                    }
                    HStack {
                        Button("平日") { weekdays = [2, 3, 4, 5, 6] }
                        Spacer()
                        Button("毎日") { weekdays = Set(1...7) }
                        Spacer()
                        Button("クリア") { weekdays = [] }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                Section {
                    DatePicker("開始", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: $endTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("時間")
                } footer: {
                    if endMinutes <= startMinutes {
                        Text("終了が開始より前なので、翌日の\(HabitDescription.timeText(endMinutes))までとして扱います（例：睡眠）。")
                    }
                }

                Section {
                    Toggle("期間を指定する", isOn: $hasValidity)
                    if hasValidity {
                        DatePicker("開始日", selection: $validFrom, displayedComponents: .date)
                        DatePicker("終了日", selection: $validTo, in: validFrom..., displayedComponents: .date)
                    }
                } header: {
                    Text("有効期間")
                } footer: {
                    Text("学期中だけ、など。期間外（長期休みなど）は空き時間として扱います。")
                }

                Section {
                    ForEach(exceptions.sorted(), id: \.self) { date in
                        Text(DateText.day(date))
                    }
                    .onDelete { offsets in
                        let sorted = exceptions.sorted()
                        let removing = offsets.map { sorted[$0] }
                        exceptions.removeAll { removing.contains($0) }
                    }
                    HStack {
                        DatePicker("日付", selection: $newException, displayedComponents: .date)
                            .labelsHidden()
                        Spacer()
                        Button("追加") {
                            let day = Calendar.current.startOfDay(for: newException)
                            if !exceptions.contains(day) { exceptions.append(day) }
                        }
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text("例外の日（この日は予定なし）")
                } footer: {
                    Text("祝日や行事で学校が休みの日など。")
                }

                Section {
                    Toggle("有効", isOn: $isEnabled)
                }
            }
            .navigationTitle(isNew ? "習慣的な予定を追加" : "習慣的な予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty || weekdays.isEmpty || startMinutes == endMinutes)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard case .edit(let habit) = target else { return }
        let calendar = Calendar.current
        name = habit.name
        weekdays = Set(habit.weekdays)
        startTime = calendar.date(on: .now, minutes: habit.startMinutes)
        endTime = calendar.date(on: .now, minutes: habit.endMinutes)
        hasValidity = habit.validFrom != nil || habit.validTo != nil
        validFrom = habit.validFrom ?? Date()
        validTo = habit.validTo ?? validTo
        exceptions = habit.exceptionDates
        isEnabled = habit.isEnabled
    }

    private func save() {
        let habit: HabitSchedule
        if case .edit(let existing) = target {
            habit = existing
        } else {
            habit = HabitSchedule(name: trimmedName)
            context.insert(habit)
        }
        habit.name = trimmedName
        habit.weekdays = weekdays.sorted()
        habit.startMinutes = startMinutes
        habit.endMinutes = endMinutes
        habit.validFrom = hasValidity ? Calendar.current.startOfDay(for: validFrom) : nil
        habit.validTo = hasValidity ? Calendar.current.startOfDay(for: validTo) : nil
        habit.exceptionDates = exceptions.sorted()
        habit.isEnabled = isEnabled
        try? context.save()
        dismiss()
    }
}
