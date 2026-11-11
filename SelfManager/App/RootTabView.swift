import SwiftData
import SwiftUI

struct RootTabView: View {
    let onExternalChange: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @StateObject private var calendarService = CalendarService()
    @SceneStorage("selectedTab") private var selectedTab = 0
    @State private var lastWidgetToken = AppGroup.widgetChangeToken

    var body: some View {
        TabView(selection: $selectedTab) {
            TodoHomeView()
                .tabItem { Label("To do", systemImage: "checklist") }
                .tag(0)
            CalendarHomeView()
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(1)
            MemoHomeView()
                .tabItem { Label("メモ", systemImage: "note.text") }
                .tag(2)
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(3)
        }
        .environmentObject(calendarService)
        .task {
            TodoMaintenance.run(in: context)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if AppGroup.widgetChangeToken != lastWidgetToken {
                    onExternalChange()
                    return
                }
                TodoMaintenance.run(in: context)
                calendarService.updateStatus()
            case .background:
                try? context.save()
                TodoActions.reloadWidgets()
            default:
                break
            }
        }
    }
}

extension Binding where Value == Bool {
    /// Optional の値があるあいだ true になる Binding（ダイアログ表示用）
    init<T>(presenting value: Binding<T?>) {
        self.init(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
    }
}
