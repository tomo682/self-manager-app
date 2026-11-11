import EventKit
import SwiftUI

/// カテゴリ（= 標準カレンダーのカレンダー）の管理。色は標準カレンダーアプリにも反映される
struct CategoryManageView: View {
    var showsDoneButton = false

    @EnvironmentObject private var calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CategoryEditTarget?
    @State private var calendarToDelete: EKCalendar?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if !calendarService.isAuthorized {
                Text("カレンダーへのアクセスが許可されていません。カレンダータブから許可してください。")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(calendarService.writableCalendars, id: \.calendarIdentifier) { calendar in
                        Button {
                            editing = .edit(calendar)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(calendar.swiftUIColor)
                                    .frame(width: 14, height: 14)
                                Text(calendar.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(calendar.source.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                calendarToDelete = calendar
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("ここで作ったカテゴリ（遊び・部活・学校など）は、iPhone標準のカレンダーアプリにも同じ名前・色で表示されます。")
                }
            }
        }
        .navigationTitle("カテゴリ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完了") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = .new
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!calendarService.isAuthorized)
            }
        }
        .sheet(item: $editing) { target in
            CategoryEditSheet(target: target)
        }
        .confirmationDialog(
            "カテゴリを削除しますか？",
            isPresented: Binding(presenting: $calendarToDelete),
            titleVisibility: .visible,
            presenting: calendarToDelete
        ) { calendar in
            Button("削除", role: .destructive) {
                do {
                    try calendarService.deleteCalendar(calendar)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } message: { calendar in
            Text("「\(calendar.title)」に入っている予定もすべて削除されます。標準のカレンダーアプリからも消えます。")
        }
        .alert("エラー", isPresented: Binding(presenting: $errorMessage), presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }
}

enum CategoryEditTarget: Identifiable {
    case new
    case edit(EKCalendar)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let calendar): return calendar.calendarIdentifier
        }
    }
}

struct CategoryEditSheet: View {
    let target: CategoryEditTarget

    @EnvironmentObject private var calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color: Color = .blue
    @State private var errorMessage: String?
    @State private var loaded = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("カテゴリ名（例：遊び、部活、学校）", text: $name)
                ColorPicker("色", selection: $color, supportsOpacity: false)
            }
            .navigationTitle(isNew ? "新しいカテゴリ" : "カテゴリを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .alert("エラー", isPresented: Binding(presenting: $errorMessage), presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if case .edit(let calendar) = target {
                    name = calendar.title
                    color = calendar.swiftUIColor
                } else {
                    color = Color(hex: ThemePalette.color(at: calendarService.writableCalendars.count))
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func save() {
        do {
            switch target {
            case .new:
                _ = try calendarService.createCalendar(title: trimmedName, color: color)
            case .edit(let calendar):
                try calendarService.updateCalendar(calendar, title: trimmedName, color: color)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
