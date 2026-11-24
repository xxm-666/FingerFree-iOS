import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayPlanView()
                .tabItem {
                    Label("今日训练", systemImage: "guitars.fill")
                }

            ProgressAndGuideView()
                .tabItem {
                    Label("进度与原则", systemImage: "chart.bar.doc.horizontal.fill")
                }
        }
    }
}
