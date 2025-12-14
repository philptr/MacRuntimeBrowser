//
//  MacRuntimeBrowserApp.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

@main
struct MacRuntimeBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            RuntimeBrowserCommands()
        }
    }
}

