import SwiftData
import SwiftUI

@main
struct SelfManagerApp: App {
    /// ウィジェットでデータが変わったときは作り直して、最新の内容を読み込む
    @State private var container = SharedModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootTabView(onExternalChange: {
                container = SharedModelContainer.make()
            })
            .id(ObjectIdentifier(container))
            .modelContainer(container)
        }
    }
}
