import SwiftData
import SwiftUI

/// テーマ内の習慣To do一覧
struct RecurringTemplateListView: View {
    let theme: TodoTheme

    @Environment(\.modelContext) private var context
    @State private var editing: RecurringTemplateEditTarget?
    @State private var templateToDelete: RecurringTodoTemplate?

    var body: some View {
        List {
            let templates = theme.templates.sorted { $0.createdAt < $1.createdAt }
            if templates.isEmpty {
                Text("習慣To doはありません")
                    .foregroundStyle(.secondary)
            }
            ForEach(templates) { template in
                Button {
                    editing = .edit(template)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(template.title).foregroundStyle(.primary)
                            if !template.isActive {
                                Text("停止中")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .background(.gray.opacity(0.2), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(RecurrenceDescription.text(for: template.spec))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        templateToDelete = template
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("習慣To do")
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
            switch target {
            case .new:
                RecurringTemplateEditView(template: nil, theme: theme)
            case .edit(let template):
                RecurringTemplateEditView(template: template, theme: theme)
            }
        }
        .confirmationDialog(
            "習慣To doを削除しますか？",
            isPresented: Binding(presenting: $templateToDelete),
            titleVisibility: .visible,
            presenting: templateToDelete
        ) { template in
            Button("削除", role: .destructive) {
                context.delete(template)
                try? context.save()
                TodoActions.reloadWidgets()
            }
        } message: { _ in
            Text("これまでの達成・未達成の記録は残ります。表示中の回もそのまま残ります。")
        }
    }
}

enum RecurringTemplateEditTarget: Identifiable {
    case new
    case edit(RecurringTodoTemplate)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let t): return t.id.uuidString
        }
    }
}

struct RecurringTemplateEditView: View {
    let template: RecurringTodoTemplate?
    let theme: TodoTheme

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var memo = ""
    @State private var kind: RecurrenceKind = .weekly
    @State private var startWeekday = 2
    @State private var dueWeekday = 6
    @State private var startDay = 1
    @State private var dueDay = 10
    @State private var dueTime = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: .now) ?? .now
    @State private var isActive = true
    @State private var loaded = false

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var spec: RecurrenceSpec {
        let c = Calendar.current.dateComponents([.hour, .minute], from: dueTime)
        return RecurrenceSpec(
            kind: kind,
            startValue: kind == .weekly ? startWeekday : startDay,
            dueValue: kind == .weekly ? dueWeekday : dueDay,
            dueHour: c.hour ?? 23,
            dueMinute: c.minute ?? 59
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル（例：毎週の課題）", text: $title)
                    TextField("メモ", text: $memo, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Picker("繰り返し", selection: $kind) {
                        Text("毎週").tag(RecurrenceKind.weekly)
                        Text("毎月").tag(RecurrenceKind.monthly)
                    }
                    .pickerStyle(.segmented)

                    if kind == .weekly {
                        Picker("表示を始める曜日", selection: $startWeekday) {
                            ForEach(1...7, id: \.self) { Text("\(Weekday.name($0))曜日").tag($0) }
                        }
                        Picker("期限の曜日", selection: $dueWeekday) {
                            ForEach(1...7, id: \.self) { Text("\(Weekday.name($0))曜日").tag($0) }
                        }
                    } else {
                        Picker("表示を始める日", selection: $startDay) {
                            ForEach(1...31, id: \.self) { Text("\($0)日").tag($0) }
                        }
                        Picker("期限の日", selection: $dueDay) {
                            ForEach(1...31, id: \.self) { Text("\($0)日").tag($0) }
                        }
                    }
                    DatePicker("期限の時刻", selection: $dueTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("繰り返し")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(RecurrenceDescription.text(for: spec))
                        if kind == .monthly {
                            Text("その月にない日付（31日など）は月末として扱います。")
                        }
                        Text("期限までに達成しなかった回は、自動で「未達成」として記録されます。")
                    }
                }

                Section {
                    Toggle("有効", isOn: $isActive)
                }
            }
            .navigationTitle(template == nil ? "新しい習慣To do" : "習慣To doを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let template else { return }
        title = template.title
        memo = template.memo
        kind = template.kind
        isActive = template.isActive
        if template.kind == .weekly {
            startWeekday = template.startValue
            dueWeekday = template.dueValue
        } else {
            startDay = template.startValue
            dueDay = template.dueValue
        }
        dueTime = Calendar.current.date(bySettingHour: template.dueHour, minute: template.dueMinute,
                                        second: 0, of: .now) ?? dueTime
    }

    private func save() {
        let target: RecurringTodoTemplate
        if let template {
            target = template
        } else {
            target = RecurringTodoTemplate(title: trimmedTitle)
            context.insert(target)
            target.theme = theme
        }
        let s = spec
        target.title = trimmedTitle
        target.memo = memo
        target.kind = s.kind
        target.startValue = s.startValue
        target.dueValue = s.dueValue
        target.dueHour = s.dueHour
        target.dueMinute = s.dueMinute
        target.isActive = isActive
        try? context.save()
        TodoMaintenance.run(in: context)
        TodoActions.reloadWidgets()
        dismiss()
    }
}

enum RecurrenceDescription {
    static func text(for spec: RecurrenceSpec) -> String {
        let time = String(format: "%d:%02d", spec.dueHour, spec.dueMinute)
        switch spec.kind {
        case .weekly:
            let wraps = spec.dueValue < spec.startValue
            return "毎週\(Weekday.name(spec.startValue))曜日に表示され、\(wraps ? "翌週の" : "")\(Weekday.name(spec.dueValue))曜日 \(time) が期限"
        case .monthly:
            let wraps = spec.dueValue < spec.startValue
            return "毎月\(spec.startValue)日に表示され、\(wraps ? "翌月" : "")\(spec.dueValue)日 \(time) が期限"
        }
    }
}
