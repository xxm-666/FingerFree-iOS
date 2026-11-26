import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayPlanView()
                .tabItem {
                    Label("进阶路径", systemImage: "guitars.fill")
                }

            ProgressAndGuideView()
                .tabItem {
                    Label("能力画像", systemImage: "chart.bar.doc.horizontal.fill")
                }
        }
    }
}
