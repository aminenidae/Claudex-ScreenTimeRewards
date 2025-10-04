import SwiftUI

@main
struct ChildiOSApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("Claudex Child (iOS)").font(.headline)
                Text("Scaffold ready. Hook up pairing next.")
            }.padding()
        }
    }
}

