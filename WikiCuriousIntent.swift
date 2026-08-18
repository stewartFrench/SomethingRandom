//
//  WikiCuriousIntent.swift
//  SomethingRandom
//
//  Created by Claude Sonnet 4.5
//  Copyright © 2026 Stewart French. All rights reserved.
//

import AppIntents
import Foundation



// ------------
struct WikiCuriousIntent: AppIntent
{
    static var title         : LocalizedStringResource = "Get WikiCurious"
    static var description   : IntentDescription?      = IntentDescription("Speak a random curiosity from Wikipedia")
    static var openAppWhenRun: Bool                    = false
    
    
    
    // -----------------------------------------
    @MainActor
    func perform() async throws -> some IntentResult
    {
        // Access the shared WikipediaManager instance
        let manager = WikipediaManager.shared
        
        // Fetch and speak a single random fact without starting the timer
        await manager.fetchAndSpeakSingleFact()
        
        // Return empty result - no "Done" spoken
        return .result()
    } // perform
} // struct WikiCuriousIntent



// ------------
enum WikiCuriousError: Error, CustomLocalizedStringResourceConvertible
{
    case managerNotFound
    
    var localizedStringResource: LocalizedStringResource
    {
        switch self
        {
            case .managerNotFound:
                return "Could not access WikiCurios. Please open the app first."
        }
    }
} // enum WikiCuriousError



// ------------
struct WikiCuriousShortcuts: AppShortcutsProvider
{
    static var appShortcuts: [AppShortcut]
    {
        AppShortcut(
            intent: WikiCuriousIntent(),
            phrases: [
                "WikiCurious in \(.applicationName)",
                "Get curious with \(.applicationName)",
                "\(.applicationName)",
                "Random fact in \(.applicationName)",
                "Tell me something from \(.applicationName)"
            ],
            shortTitle: "Get Curious",
            systemImageName: "book.circle"
        )
    }
} // struct WikiCuriousShortcuts
