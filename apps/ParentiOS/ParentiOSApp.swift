import SwiftUI
import Core
import PointsEngine
import ScreenTimeService

@main
struct ParentiOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Claudex Parent (iOS)").font(.headline)
            Text("Scaffold ready. Hook up services next.")
        }.padding()
    }
}

