import SwiftUI

@main
struct FingerFreeApp: App {
    @StateObject private var store = PracticeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
