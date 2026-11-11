import EventKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var calendarService: CalendarService
    @AppStorage(AppSettings.noDeadlineSearchDaysKey) private var searchDays = AppSettings.defaultNoDeadlineSearchDays

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        HabitScheduleListView()
                    } label: {
                        Label("習慣的な予定（学校・睡眠など）", systemImage: "bed.double")
                    }
                    Stepper("期限なしの場合：\(searchDays)日先まで探す", value: $searchDays, in: 1...60)
                    if calendarService.isAuthorized {
                        Picker("提案した予定の登録先", selection: $calendarService.taskCalendarIdentifier) {
                            Text("自動（「To do」カレンダー）").tag(String?.none)
                            ForEach(calendarService.writableCalendars, id: \.calendarIdentifier) { calendar in
                                Text(calendar.title).tag(Optional(calendar.calendarIdentifier))
                            }
                        }
                    }
                } header: {
                    Text("空き時間の提案")
                } footer: {
                    Text("カレンダーには入れない予定（学校・睡眠など）を登録すると、その時間は提案から外れます。")
                }

                Section("カレンダー") {
                    NavigationLink {
                        CategoryManageView()
                    } label: {
                        Label("カテゴリ（色分け）", systemImage: "paintpalette")
                    }
                    if !calendarService.isAuthorized {
                        Button("カレンダーへのアクセスを許可") {
                            if calendarService.needsSettingsApp {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } else {
                                Task { await calendarService.requestAccess() }
                            }
                        }
                    }
                }

                Section("ウィジェット") {
                    Text("ホーム画面を長押し →「＋」→「自己管理」からTo doウィジェットを追加できます。追加後に長押しして「ウィジェットを編集」でテーマを選んでください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
        }
    }
}
