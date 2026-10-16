// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import SwiftUI
import NWaysMaps

@main
struct NWaysSampleApp: App {
    init() {
        // From Config.xcconfig / Secrets.xcconfig, through Info.plist.
        let key = (Bundle.main.object(forInfoDictionaryKey: "NWaysApiKey") as? String) ?? ""
        NWaysMaps.configure(apiKey: key.isEmpty ? "YOUR_API_KEY" : key)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
