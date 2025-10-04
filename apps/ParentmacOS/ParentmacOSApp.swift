import SwiftUI

@main
struct ParentmacOSApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("Claudex Parent (macOS)").font(.headline)
                Text("Scaffold ready. Hook up services next.")
            }.padding()
        }
    }
}

