//
//  keyqApp.swift
//  keyq
//
//  Created by Dean Turpin on 12/01/2026.
//

import SwiftUI

@main
struct keyqApp: App {
    private let hostModel = AudioUnitHostModel()

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel)
        }
    }
}
