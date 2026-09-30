//
//  DemoApp.swift
//  Demo
//

import SwiftUI

@main
struct DemoApp: App {
    init() {
        DemoMapProvider.configureSDK()
        XWAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            // `-example <slug>` opens straight to one example, laid out exactly as
            // it would be when pushed from the list. See ``ExampleCaptureMode``.
            if let example = ExampleCaptureMode.example {
                NavigationStack {
                    ExampleContainer {
                        example.destination()
                    }
                    .navigationTitle(example.title)
                }
                .onAppear { ExampleCaptureMode.didOpenExample() }
            } else {
                ExampleListView()
            }
        }
    }
}
