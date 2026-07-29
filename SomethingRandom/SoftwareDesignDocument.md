# Software Design Document
## WikiCurios (Curiosities From Wikipedia) iOS Application
## Built in Xcode as "SomethingRandom"

**Version:** 1.0

**Date:** July 27, 2026

**Author:** Stewart French, Claude Sonnet 4.5 by Anthropic

---

## Public Domain Dedication

This software and all associated documentation are dedicated to the **public domain**
worldwide under the **Creative Commons CC0 1.0 Universal (CC0 1.0) Public Domain
Dedication**.

To the extent possible under law, the author has waived all copyright and related or
neighboring rights to this work. This work is published from: United States.

**You are free to:**

  - Copy, modify, distribute and perform the work
  - Use the work for commercial purposes
  - Use the work without any restrictions whatsoever

**No Copyright - No Warranty:**

The work is provided "as is", without warranty of any kind, express or implied,
including but not limited to the warranties of merchantability, fitness for a
particular purpose and noninfringement.

For more information, please refer to:

  - <https://creativecommons.org/publicdomain/zero/1.0/>

---

## Table of Contents

  1. [Executive Summary](#executive-summary)
  2. [Project Overview](#project-overview)
  3. [System Architecture](#system-architecture)
  4. [Feature Specifications](#feature-specifications)
  5. [Technical Implementation](#technical-implementation)
  6. [Data Management](#data-management)
  7. [Background Execution](#background-execution)
  8. [User Interface Design](#user-interface-design)
  9. [Copyright and Legal Analysis](#copyright-and-legal-analysis)
  10. [Code Style Guidelines](#code-style-guidelines)
  11. [Testing and Validation](#testing-and-validation)
  12. [Future Enhancements](#future-enhancements)

---

## 1. Executive Summary

**WikiCurios (Curiosities From Wikipedia)** is an iOS application that speaks random
curious and odd facts from Wikipedia at configurable intervals. The app runs in the
background and in standby mode.  It provides entertainment and education through
text-to-speech technology without requiring user interaction.

**Key Features:**

  - Text-to-speech delivery of Wikipedia facts with customizable voices
  - Configurable frequency (1-120 minutes)
  - Random timing mode for unpredictable fact delivery
  - Background and standby operation
  - Curated content filtering (strange, curious, and odd topics only)
  - Negative content filtering (no murder, war, death, crime, etc)
  - Persistent state across app launches
  - Portrait-only orientation
  - Fact history display with clickable Wikipedia links
  - Category display for each fact (in history and used facts list)
  - Share functionality for all facts
  - Dynamic title display during speech
  - Next fact time display (updates with slider and random toggle)
  - Stop speaking button for immediate interruption
  - Duplicate fact prevention with persistent tracking
  - Comprehensive settings with category and keyword management
  - Auto-save settings changes
  - View and manage used fact titles with categories and deletion support

---

## 2. Project Overview

### 2.1 Purpose

WikiCurios delivers curious and odd facts from Wikipedia throughout the day by speaking
them at random or fixed intervals. The app is designed for users who want to learn
interesting trivia while their phone is in their pocket, on a desk, or in standby mode.

### 2.2 Target Platform

  - **Platform:** iOS 15.0+
  - **Language:** Swift 5.9+
  - **UI Framework:** SwiftUI
  - **Device Support:** iPhone only (Portrait orientation)
  - **Display Name:** WikiCurios

### 2.3 Project Goals

1. Provide reliable background audio playback
2. Fetch interesting Wikipedia content from curated categories
3. Filter out negative topics automatically
4. Maintain state persistence across app launches
5. Offer flexible timing controls
6. Support multiple voice options
7. Display fact history with Wikipedia links
8. Prevent duplicate facts across all app sessions
9. Meet App Store guidelines

---

## 3. System Architecture

### 3.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│               SomethingRandomApp                        │
│              (Application Entry)                        │
└────────────────────┬────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
┌─────────▼─────────┐  ┌────────▼──────────┐
│   ContentView     │  │   AppDelegate     │
│  (Main UI)        │  │  (Lifecycle)      │
└─────────┬─────────┘  └────────┬──────────┘
          │                     │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │  WikipediaManager   │
          │  (Business Logic)   │
          └──────────┬──────────┘
                     │
     ┌───────────────┼───────────────┐
     │               │               │
┌────▼─────┐  ┌──────▼─────┐  ┌──────▼─────┐
│Wikipedia │  │AVSpeech    │  │UserDefaults│
│   API    │  │Synthesizer │  │  (State)   │
└──────────┘  └────────────┘  └────────────┘
```

### 3.2 Component Responsibilities

**SomethingRandomApp:**

  - Application entry point
  - App delegate configuration
  - Audio session initialization

**ContentView:**

  - User interface presentation
  - User interaction handling
  - Voice selection UI
  - Frequency slider
  - Control buttons
  - Fact history display with links
  - Share functionality

**WikipediaManager:**

  - Core business logic
  - Wikipedia API integration
  - Fact fetching and filtering
  - Speech synthesis
  - Timer management
  - Background audio maintenance
  - State persistence

**AppDelegate:**

  - Background audio session setup
  - Application lifecycle management

---

## 4. Feature Specifications

### 4.1 Fact Playback

**Description:** Speaks random curious facts from Wikipedia using text-to-speech.

**Requirements:**

  - Fetch facts from Wikipedia API
  - Filter by curated categories (strange, curious, odd)
  - Filter out negative content
  - Check for duplicate facts
  - Discard facts exceeding the user-set sentence limit
  - Speak fact using configured voice
  - Display fact title during speaking
  - Store facts in history
  - Mark fact titles as used

**Technical Details:**

  - Uses Wikipedia REST API v1
  - Category-based random selection
  - Keyword filtering for negative content
  - AVSpeechSynthesizer for text-to-speech
  - Two-utterance system: "Wikipedia" intro + fact

### 4.2 Content Curation

**Description:** Automatically select interesting, positive content.

**Requirements:**

  - 50+ curated Wikipedia categories
  - Focus on: strange, curious, odd, unusual
  - Filter out: murder, war, death, crime, violence
  - Up to 10 retry attempts per fact

**Categories Include:**

  - Strange & Unusual: Paradoxes, Optical illusions, Urban legends
  - Odd Science: Bioluminescence, Extremophiles, Carnivorous plants
  - Bizarre Inventions: Obsolete tech, Failed products, Rube Goldberg
  - Weird Geography: Ghost towns, Micronations, Sinkholes
  - Curious Customs: Festivals, Superstitions, Folklore
  - And many more...

### 4.3 Frequency Control

**Description:** User-configurable interval between facts.

**Requirements:**

  - Slider range: 1-120 minutes
  - Default: 5 minutes
  - Live updates when timer is running
  - Visual feedback of current setting
  - Dynamic timer rescheduling on adjustment

**Technical Details:**

  - Timer-based scheduling
  - RunLoop integration for background reliability
  - Reschedules timer from current moment

### 4.4 Random Timing Mode

**Description:** Randomize the interval between facts for unpredictable delivery.

**Requirements:**

  - Toggle button (shuffle icon) to enable/disable
  - Visual feedback (blue background when active)
  - Facts delivered at random intervals between 1 minute and slider value
  - Persists across app launches

**Technical Details:**

  - `getNextInterval()` returns random value when enabled
  - Each fact triggers scheduling of next random interval
  - State saved to UserDefaults

### 4.5 Voice Selection

**Description:** Choose from available English voices.

**Requirements:**

  - Display all available English voices
  - Show voice name and language variant
  - Default voice: Daniel (en-GB)
  - Persistent selection across app launches

**Technical Details:**

  - Queries AVSpeechSynthesisVoice.speechVoices()
  - Filters for English language variants
  - Sorted alphabetically by name
  - Saved to UserDefaults by voice identifier

### 4.6 Background Operation

**Description:** Continue playing facts when app is backgrounded or device is in standby.

**Requirements:**

  - Continue timer execution in background
  - Play audio while app is not in foreground
  - Work in silent mode
  - Maintain state across background transitions

**Technical Details:**

  - Silent audio looping technique
  - Background audio mode enabled
  - AVAudioSession configured for playback
  - Timer added to RunLoop with .common mode

### 4.7 Fact History Display

**Description:** Show all spoken facts in scrollable view with Wikipedia links.

**Requirements:**

  - Display all facts in numbered list
  - Show "Latest" indicator on newest fact
  - Clickable "Read more on Wikipedia" links
  - Auto-scroll to latest fact when added
  - Distinct styling for latest fact

**Technical Details:**

  - ScrollView with ForEach over factHistory
  - Link component opens Wikipedia article
  - Opens Wikipedia app if installed, Safari otherwise
  - ScrollViewReader for auto-scrolling

### 4.8 Share Functionality

**Description:** Share all facts via iOS share sheet.

**Requirements:**

  - Share button above fact history
  - Formatted text with fact numbers
  - Include Wikipedia URLs for each fact
  - Standard iOS share sheet

**Technical Details:**

  - UIActivityViewController wrapper
  - Formats text with titles and URLs
  - Compatible with Messages, Mail, Notes, etc.

### 4.9 Dynamic Title Display

**Description:** Show fact title in header during speech.

**Requirements:**

  - Extract title (first sentence before period)
  - Display when speaking begins
  - Keep visible throughout speech
  - Revert to "Curiosities From Wikipedia" when done
  - Single transition (no flickering)

**Technical Details:**

  - currentSpeakingTitle published property
  - Set at beginning of speakFact()
  - Cleared only when final utterance finishes
  - Identity check on utterance object

### 4.10 Immediate Launch Behavior

**Description:** Speak one fact immediately when app launches.

**Requirements:**

  - Speak fact 1 second after app starts
  - Auto-schedule next fact based on interval
  - Enable background audio automatically
  - Only once per launch

**Technical Details:**

  - hasSpokenOnLaunch flag
  - DispatchQueue.asyncAfter delay
  - scheduleNextFactAfterLaunch() method

### 4.11 Duplicate Fact Prevention

**Description:** Prevent the same fact from being spoken twice across all app sessions.

**Requirements:**

  - Track all fact titles that have been spoken with their categories
  - Store titles persistently across app launches
  - Check each new fact against stored titles before accepting
  - Reject duplicate facts and fetch alternatives
  - Never expire or clear the duplicate list automatically
  - Display category with each fact for context

**Technical Details:**

  - usedFactTitles Set<UsedFactTitle> property
  - UsedFactTitle struct stores title, category, and UUID
  - loadUsedFactTitles() loads from UserDefaults on init
  - saveUsedFactTitles() persists array to UserDefaults
  - isFactTitleUsed() checks if title already spoken
  - markFactTitleAsUsed() adds UsedFactTitle to set and saves
  - fetchFromCategory() checks for duplicates before returning fact
  - speakFact() marks title as used when speaking begins
  - Both the duplicate check and the "mark as used" step use the exact Wikipedia article title, stored on WikipediaFact.title, so the compared and recorded strings always match
  - UserDefaults key: "usedFactTitlesWithCategories"
  - Backward compatible with old "usedFactTitles" key (migrates automatically)

**Benefits:**

  - Never hear the same fact twice
  - Works across app restarts
  - Automatic and transparent to user
  - Integrates with existing retry logic
  - User can manage via settings (view, delete individual, clear all)

### 4.12 Settings Management

**Description:** Comprehensive settings interface for managing categories, negative keywords, and used fact titles.

**Requirements:**

  - Manage Wikipedia categories (add, delete, view defaults)
  - Manage negative keywords (add, delete, view defaults)
  - View and delete used fact titles
  - Browse Wikipedia categories via external link
  - Reset categories and keywords to defaults
  - Auto-save all changes immediately

**Technical Details:**

  - SettingsView: Main settings container with navigation
  - CategoriesEditorView: Dedicated view for category management
  - KeywordsEditorView: Dedicated view for keyword management
  - UsedFactsView: View and manage previously heard fact titles
  - Auto-save on every add/delete operation
  - No explicit Save/Cancel buttons needed
  - Single Done button to dismiss settings
  - Real-time updates via @ObservedObject and @Published
  - Categories and keywords persist via CategoriesData.save()
  - WikipediaManager.reloadCategories() refreshes after changes

**UI Components:**

  - Navigate to Manage Categories (shows count)
  - Navigate to Manage Negative Keywords (shows count)
  - Information section showing category/keyword counts
  - View Used Fact Titles button (shows count)
  - Reset to Defaults button
  - Browse Wikipedia Categories link (in categories view)

**Category Management:**

  - My Categories section (user-added, deletable)
  - Add new category text field with Add button
  - Default Categories section (deletable)
  - Spaces converted to underscores for Wikipedia API
  - Auto-save on add/delete

**Keyword Management:**

  - Add new keyword section at top
  - My Negative Keywords section (user-added, deletable)
  - Default Negative Keywords section (deletable)
  - Keywords automatically lowercased
  - Auto-save on add/delete

**Used Fact Titles Management:**

  - Share All Titles button at top (creates HTML file attachment)
  - List all previously heard fact titles with categories (sorted)
  - Category display below each title
  - Swipe-to-delete individual titles
  - Delete All button at bottom (with confirmation)
  - Each title is clickable Wikipedia link
  - Real-time count updates via @Published property
  - Shared HTML file includes styled list with titles, categories, and clickable URLs
  - HTML formatting ensures proper display in email clients

**Benefits:**

  - Simplified user experience with auto-save
  - No risk of losing changes
  - Clear organization with separate views
  - Immediate feedback on all changes
  - Ability to customize content filtering
  - Full control over duplicate prevention

---

## 5. Technical Implementation

### 5.1 Technology Stack

**Languages & Frameworks:**

  - Swift 5.9+
  - SwiftUI
  - Combine
  - AVFoundation
  - Foundation

**Apple Frameworks:**

  - AVSpeechSynthesizer (Text-to-speech)
  - AVAudioSession (Audio management)
  - AVAudioPlayer (Silent audio playback)
  - Timer (Scheduling)
  - UserDefaults (Persistence)
  - URLSession (Wikipedia API)

### 5.2 File Structure

```
SomethingRandom/
├── SomethingRandomApp.swift       # App entry point and delegate
├── ContentView.swift              # Main UI view
├── SettingsView.swift             # Settings UI with categories/keywords management
├── WikipediaManager.swift         # Business logic and API integration
├── CategoriesData.swift           # Categories and keywords model
├── categories.json                # Default categories and keywords
├── Info.plist                     # App configuration
├── Assets.xcassets/               # Images and app icon
├── format_rules.md                # Code formatting guidelines
├── README.md                      # Project readme
└── SoftwareDesignDocument.md      # This document
```

### 5.3 Key Classes and Structures

#### 5.3.1 WikipediaFact (Struct)

**Purpose:** Store fact text with Wikipedia URL and category

**Properties:**

  - `id: UUID` - Unique identifier (auto-generated)
  - `text: String` - Full fact text
  - `url: URL` - Wikipedia article URL
  - `category: String` - Wikipedia category name (for display)

**Conformance:** Identifiable

#### 5.3.2 UsedFactTitle (Struct)

**Purpose:** Store used fact titles with categories for duplicate prevention

**Properties:**

  - `id: UUID` - Unique identifier (auto-generated)
  - `title: String` - Wikipedia article title
  - `category: String` - Wikipedia category name

**Conformance:** Codable, Hashable, Identifiable, Sendable

#### 5.3.3 WikipediaRandomResponse (Struct)

**Purpose:** Decode Wikipedia API summary response

**Properties:**

  - `title: String`   - Article title
  - `extract: String`   - Article summary text
  - `content_urls: ContentUrls?`   - URLs object

#### 5.3.4 WikipediaCategoryResponse (Struct)

**Purpose:** Decode Wikipedia category members

**Properties:**

  - `query: WikipediaQuery`   - Query results

#### 5.3.5 WikipediaManager (Class)

**Purpose:** Core application logic

**Properties:**

```swift
@Published var isEnabled          : Bool
@Published var frequencyMinutes   : Double
@Published var isRandomTiming     : Bool
@Published var maxSentences       : Int
@Published var availableVoices    : [AVSpeechSynthesisVoice]
@Published var selectedVoice      : AVSpeechSynthesisVoice?
@Published var isSpeaking         : Bool
@Published var nextFactTime       : Date?
@Published var lastFact           : String
@Published var currentSpeakingTitle : String
@Published var isLoadingFact      : Bool
@Published var factHistory        : [WikipediaFact]

private let synthesizer           : AVSpeechSynthesizer
private var timer                 : Timer?
private var audioPlayer           : AVAudioPlayer?
private var factUtterance         : AVSpeechUtterance?
@Published private var usedFactTitles : Set<UsedFactTitle>

var usedFactTitlesCount           : Int
var usedFactTitlesList            : [UsedFactTitle]
```

**Key Methods:**

  - `fetchAndSpeakRandomFact()`   - Main fact retrieval and playback
  - `fetchRandomWikipediaFact()`   - Select category and fetch; retries in rounds of 10 and raises the sentence limit if a round fails only due to the sentence filter
  - `fetchFromCategory(_:negativeKeywords:maxSentences:)`   - Get random from category; returns a `FactFetchResult` (`.found`, `.tooManySentences`, or `.filtered`)
  - `sentenceCount(in:)`   - Count sentences in text via `.bySentences` enumeration
  - `speakFact(_:)`   - Text-to-speech with intro
  - `startTimer()`   - Begin periodic fact playback
  - `stopTimer()`   - End periodic playback
  - `updateFrequency(_:)`   - Adjust timer interval
  - `loadVoiceSelection()`   - Restore voice from UserDefaults
  - `saveVoiceSelection()`   - Persist voice choice
  - `setupSilentAudioPlayer()`   - Create background audio
  - `startSilentAudio()`   - Begin silent loop
  - `stopSilentAudio()`   - End silent loop
  - `configureAudioSession()`   - Setup AVAudioSession
  - `loadUsedFactTitles()`   - Restore used titles from UserDefaults
  - `saveUsedFactTitles()`   - Persist used titles to UserDefaults
  - `isFactTitleUsed(_:)`   - Check if title already used
  - `markFactTitleAsUsed(_:category:)`   - Mark title as used with category and save
  - `removeUsedFactTitle(_:)`   - Remove single UsedFactTitle and save
  - `clearAllUsedFactTitles()`   - Clear all titles and save
  - `reloadCategories()`   - Reload categories from CategoriesData
  - `saveRandomTimingSetting()`   - Save random timing and update next fact time
  - `loadMaxSentences()`   - Restore max sentence limit from UserDefaults
  - `saveMaxSentences()`   - Persist max sentence limit to UserDefaults

#### 5.3.6 ContentView (Struct)

**Purpose:** SwiftUI user interface

**Components:**

  - Settings button (top right corner)
  - App icon display (70x70 with fallback)
  - Dynamic title (fact title or "Curiosities From Wikipedia")
  - Compact voice picker
  - Frequency display with next fact time (e.g., "5m • 2:30 PM")
  - Frequency slider with random timing button
  - Start/Stop and "Now" buttons side-by-side
  - Share button (when facts exist, shares as HTML file attachment)
  - Scrollable fact history with numbered entries
  - Category display for each fact (below fact text)
  - Wikipedia links for each fact
  - Stop speaking button (overlay, orange, appears during speech)

**Behavior:**

  - Share creates formatted HTML file (WikiCurios_Facts.html) as attachment
  - HTML includes styled boxes with fact numbers, fact text, and clickable "Read more on Wikipedia" links
  - HTML formatting ensures proper display in email clients

**Helper Methods:**

  - `createShareText()` - Generates HTML document with styled fact list
  - `createHTMLFile()` - Writes HTML to temporary file and returns URL for sharing
  - `voiceDisplayName(_:)` - Formats voice name with language code

#### 5.3.7 SettingsView (Struct)

**Purpose:** Settings navigation and management

**Components:**

  - Navigate to Manage Categories (with count badge)
  - Navigate to Manage Negative Keywords (with count badge)
  - Fact Length section (stepper to set the max sentence limit, range 1–20)
  - Information section (category/keyword statistics)
  - View Used Fact Titles button (with count badge)
  - Reset to Defaults button
  - Done button in toolbar
  - Auto-saves all changes via child views (max sentence limit saved on change)

**State:**

  - `@ObservedObject var wikipediaManager: WikipediaManager`
  - `@State private var categoriesData: CategoriesData`
  - `@State private var showingUsedFacts: Bool`

#### 5.3.8 CategoriesEditorView (Struct)

**Purpose:** Manage Wikipedia categories

**Components:**

  - Browse Wikipedia Categories link (opens Safari)
  - My Categories section (user-added with delete buttons)
  - Add new category text field with Add button
  - Default Categories section (deletable)

**State:**

  - `@Binding var categoriesData: CategoriesData`
  - `@ObservedObject var wikipediaManager: WikipediaManager`
  - `@State private var newCategory: String`

**Behavior:**

  - Auto-saves on every add/delete
  - Converts spaces to underscores for Wikipedia API
  - Reloads WikipediaManager after changes

#### 5.3.9 KeywordsEditorView (Struct)

**Purpose:** Manage negative keywords

**Components:**

  - Add new keyword section at top
  - My Negative Keywords section (user-added with delete buttons)
  - Default Negative Keywords section (deletable)

**State:**

  - `@Binding var categoriesData: CategoriesData`
  - `@ObservedObject var wikipediaManager: WikipediaManager`
  - `@State private var newKeyword: String`

**Behavior:**

  - Auto-saves on every add/delete
  - Automatically lowercases keywords
  - Reloads WikipediaManager after changes

#### 5.3.10 UsedFactsView (Struct)

**Purpose:** View, share, and delete used fact titles

**Components:**

  - Share All Titles button at top (blue background)
  - Sorted list of all used fact titles
  - Swipe-to-delete gesture for individual titles
  - Delete All button at bottom (with confirmation alert)
  - Each title is clickable Wikipedia link
  - Done button in toolbar

**State:**

  - `@ObservedObject var wikipediaManager: WikipediaManager`
  - `@State private var showingDeleteAllAlert: Bool`

**Behavior:**

  - Share creates formatted HTML file (WikiCurios_Facts.html) as attachment
  - HTML includes styled boxes with titles, categories, and clickable URLs
  - Real-time count updates via @Published usedFactTitles
  - Confirmation dialog before deleting all titles
  - Dismisses view after Delete All
  - Opens Wikipedia in Safari when title tapped

**Helper Methods:**

  - `createShareText()` - Generates HTML document with styled fact list
  - `createHTMLFile()` - Writes HTML to temporary file and returns URL for sharing
  - `wikipediaURL(for:)` - Converts title to Wikipedia URL
  - `deleteTitle(at:)` - Removes individual title from set

#### 5.3.11 CategoriesData (Struct)

**Purpose:** Model for categories and keywords with persistence

**Properties:**

  - `categories: [String]` - All active categories
  - `negativeKeywords: [String]` - All active keywords
  - `userAddedCategories: [String]` - User-added categories
  - `userAddedKeywords: [String]` - User-added keywords

**Methods:**

  - `static func load() -> CategoriesData` - Load from file or defaults
  - `func save() throws` - Persist to documents directory
  - `static func resetToDefaults() throws` - Delete custom file

**Persistence:**

  - Saves to documents directory as categories.json
  - Falls back to default categories.json from bundle
  - Tracks user additions separately for UI display

---

## 6. Data Management

### 6.1 Wikipedia API Integration

**Base URL:** https://en.wikipedia.org

**Endpoints Used:**

1. **Category Members**
   - `/w/api.php?action=query&format=json&list=categorymembers`
   - Returns list of articles in a category

2. **Page Summary**
   - `/api/rest_v1/page/summary/{title}`
   - Returns article title, extract, and URL

**Request Headers:**

  - User-Agent: "WikiCurios/1.0 (iOS app; contact: {email})"
  - Required by Wikipedia API etiquette

**Error Handling:**

  - Try up to 10 categories to find suitable fact
  - Graceful fallback on network errors
  - Speak error message if all attempts fail

### 6.2 Content Filtering

**Category Selection:**

  - 50+ curated categories
  - Randomly selected for each fact
  - Focus on strange, curious, unusual topics

**Negative Keyword Filter:**

  - 30+ blocked keywords
  - Checks title and extract
  - Rejects articles containing: murder, death, war, crime, etc.
  - Logs rejected articles for debugging

**Duplicate Fact Filter:**

  - Checks title against Set of used titles
  - Persistent storage across app sessions
  - Rejects previously spoken facts
  - Logs rejected duplicates for debugging
  - No expiration or limit on stored titles

**Sentence Length Filter:**

  - User-configurable maximum sentence count (`maxSentences`, default 2, range 1–20)
  - Sentence count measured on the article extract via `.bySentences` enumeration
  - Facts exceeding the limit are discarded and never spoken or recorded as used
  - If a full round of 10 attempts fails only because of this filter, the limit is
    raised by 1 (persisted) and fetching retries; escalation is capped at 20
  - Rejections for other reasons (keyword, duplicate) do not raise the limit

**Quality Assurance:**

  - Multiple retry attempts
  - Diverse category selection
  - Automatic content validation
  - Duplicate prevention

### 6.3 Fact History

**Storage:**

  - In-memory array of WikipediaFact objects
  - Not persisted across launches (by design)
  - Each fact includes title, text, URL, and category

**Display:**

  - Numbered list (Fact #1, #2, etc.)
  - Latest fact highlighted
  - Clickable links to Wikipedia
  - Auto-scroll to newest

### 6.4 Persistence Strategy

**Storage:** UserDefaults

**Keys:**

  - `frequencyMinutes`   - Double value for timer interval
  - `isRandomTiming`   - Boolean for random timing mode
  - `maxSentences`   - Int value for the maximum fact sentence limit
  - `selectedVoiceIdentifier`   - String for voice persistence
  - `usedFactTitlesWithCategories`   - JSON encoded array of UsedFactTitle for duplicate prevention
  - `usedFactTitles`   - Legacy key (migrated to usedFactTitlesWithCategories)

**Save Points:**

  - When frequency slider changes
  - When random button toggled
  - When the sentence limit stepper changes, or when it is auto-raised during fetching
  - When voice selection changes
  - When each fact is spoken (title marked as used)

**Load Points:**

  - App initialization
  - First launch uses defaults

---

## 7. Background Execution

### 7.1 Challenge

iOS aggressively suspends apps in the background. Timers typically don't fire when
an app is backgrounded or the device is in standby mode.

### 7.2 Solution: Silent Audio Technique

**Strategy:** Play continuous silent audio to maintain "active audio app" status

**Implementation:**

1. Generate 1-second silent audio buffer (44.1kHz, mono, zeros)
2. Write buffer to temporary CAF file
3. Create AVAudioPlayer with silent file
4. Configure for infinite loop (`numberOfLoops = -1`)
5. Set volume to 0.0
6. Start playback when timer starts
7. Stop playback when timer stops

**Benefits:**

  - Keeps app active in background
  - Timer fires reliably
  - Works in standby mode
  - Minimal battery impact
  - Standard technique for background apps

### 7.3 Audio Session Configuration

**Category:** `.playback`
**Mode:** `.voicePrompt`
**Options:** `[.mixWithOthers]`

**Reasoning:**

  - `.playback` enables background audio
  - `.voicePrompt` optimized for speech
  - `.mixWithOthers` allows other apps' audio simultaneously
  - Works even in silent mode

**Note on Audio Ducking:**

  - Attempted `.duckOthers` option
  - Caused issues with music playback
  - Reverted to `.mixWithOthers` for better compatibility

### 7.4 Background Modes

**Configuration:** Added via project settings

**Required for:**

  - Background audio playback
  - Timer execution while backgrounded
  - Speech synthesis in background

**User Action Required:**

Must manually enable in Xcode:
1. Select target
2. Signing & Capabilities tab
3. Add "Background Modes" capability
4. Check "Audio, AirPlay, and Picture in Picture"

---

## 8. User Interface Design

### 8.1 Design Principles

  - **Efficiency:** Compact header, maximized content area
  - **Information:** Large scrollable fact history
  - **Visual Feedback:** Dynamic title display during speech
  - **Accessibility:** Clickable Wikipedia links
  - **Portrait Only:** Locked orientation

### 8.2 Layout Structure

**Vertical Stack:**

  1. Compact Header
       - App icon (70x70)
       - Dynamic title (fact or app name)
  2. Controls Row
       - Voice picker
       - Time interval display
  3. Frequency Slider
       - With random timing shuffle button
  4. Action Buttons
       - Start/Stop (green/red)
       - "Now" button (blue)
  5. Divider
  6. Share Button (when facts exist)
  7. Divider
  8. Scrollable Fact History
       - Numbered facts
       - Wikipedia links
       - Latest indicator
  9. Stop Speaking Button (overlay when speaking)

### 8.3 Color Scheme

  - **Primary:** Blue (links, active elements)
  - **Success:** Green (Start button, Latest indicator)
  - **Warning:** Orange (Stop Speaking button)
  - **Danger:** Red (Stop Facts button)
  - **Neutral:** System colors for backgrounds

### 8.4 Fact History Design

**Entry Format:**

  - Header: "Fact #X" with "Latest" badge
  - Body: Full fact text
  - Footer: "Read more on Wikipedia" link with icon

**Styling:**

  - Latest fact: tertiary background color
  - Other facts: clear background
  - Dividers between entries
  - Left-aligned text

### 8.5 Dynamic Title Behavior

**States:**

  - Default: "Curiosities From Wikipedia"
  - Speaking: First sentence of current fact
  - Truncated to 2 lines maximum

**Transition:**

  - Single change when speaking begins
  - Remains throughout speech
  - Reverts when speech ends

### 8.6 Share Sheet Integration

**Format:**

```
Curiosities From Wikipedia

Fact #1:
{fact text}
Read more: {url}

Fact #2:
...

Shared from Curiosities From Wikipedia app
```

**Compatibility:**

  - Messages
  - Mail
  - Notes
  - Copy to clipboard
  - Third-party apps

---

## 9. Copyright and Legal Analysis

### 9.1 Software Code

**Status:** Public Domain (CC0 1.0)

All source code is dedicated to the public domain. Anyone may use, modify, distribute,
or sell this software without restriction.

### 9.2 Wikipedia Content

**License:** Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)

**Legal Status:** Fully compliant and legal

**Requirements Met:**

1. **Attribution**
   - ✅ "Curiosities From Wikipedia" in UI
   - ✅ "Read more on Wikipedia" links
   - ✅ Wikipedia mentioned in shared content
   - ✅ App description includes attribution

2. **API Usage**
   - ✅ User-Agent header with contact info
   - ✅ Wikipedia API etiquette guidelines followed
   - ✅ No API key required (public API)
   - ✅ Free for commercial use

3. **Content Handling**
   - ✅ Content displayed verbatim (not modified)
   - ✅ ShareAlike provision satisfied (no modifications)
   - ✅ Links back to source articles

**App Store Submission Text:**

"All facts displayed in this app are sourced from Wikipedia and are used in accordance
with Wikipedia's Creative Commons Attribution-ShareAlike 4.0 International License
(CC BY-SA 4.0). Content is retrieved via the Wikipedia API and presented verbatim
without modification. Appropriate attribution is provided throughout the app interface
and in shared content. Wikipedia® is a registered trademark of the Wikimedia Foundation,
Inc. This app is not affiliated with or endorsed by the Wikimedia Foundation."

### 9.3 App Store Considerations

**Compliance Points:**

  - ✅ No copyright infringement
  - ✅ Proper attribution
  - ✅ Educational content
  - ✅ No user-generated content
  - ✅ No objectionable material (filtered)
  - ✅ Background audio legitimately used

**Content Filtering:**

  - Curated categories exclude controversial topics
  - Negative keyword filtering prevents inappropriate content
  - Educational and entertainment value
  - Family-friendly content

---

## 10. Code Style Guidelines

### 10.1 Formatting Rules

  - Braces on separate lines with matching alignment
  - Comments on same line as closing braces
  - Function parameters on separate lines with aligned colons
  - 12 dashes before top-level classes/structs
  - 4 dashes before function declarations
  - 2 blank lines before each function
  - 2-space indentation
  - Colons aligned in property definitions

### 10.2 Swift Concurrency

**Approach:**

  - Async/await for API calls
  - nonisolated functions for network operations
  - MainActor for UI updates
  - Sendable conformance for data models

**Threading:**

  - Network calls on background threads
  - UI updates on MainActor
  - Speech synthesis on main thread
  - Timer on RunLoop.main with .common mode

---

## 11. Testing and Validation

### 11.1 Functional Testing

**Wikipedia Integration:**

  - API calls succeed
  - Category selection works
  - Content filtering effective
  - URL parsing correct
  - Error handling functional

**Fact Playback:**

  - Facts fetch and speak
  - Voice selection applies
  - Two-utterance system works
  - Speech can be stopped
  - Title displays correctly

**Timer Functionality:**

  - Timer starts and stops
  - Frequency adjustment works
  - Random timing functions
  - Background execution reliable
  - Immediate launch fact works

**Fact History:**

  - Facts append correctly
  - Links open Wikipedia
  - Scrolling works
  - Auto-scroll to latest
  - Share functionality works

### 11.2 UI Testing

**Layout:**

  - Portrait-only orientation
  - Compact header
  - Large scrollable area
  - Stop button overlay
  - No layout issues

**Interactions:**

  - All buttons respond
  - Slider updates frequency
  - Voice picker changes voice
  - Links open correctly
  - Share sheet appears

### 11.3 Device Testing

**Tested on:**

  - iPhone (iOS 15.0+)
  - Background mode
  - Standby mode
  - Silent mode
  - Various voices

### 11.4 Edge Cases

**Handled:**

  - Network failures (error message spoken)
  - All categories exhausted (tries 10 times per round)
  - Sentence limit too low to find a fact (limit auto-raised by 1 per failed round, capped at 20)
  - No voices available (fallback)
  - Empty fact history (placeholder text)
  - UserDefaults corruption (defaults used)
  - Wikipedia app not installed (opens Safari)

---

## 12. Future Enhancements

### 12.1 Potential Features

**Content Options:**

  - Favorite facts
  - Fact ratings
  - Filter by topic
  - Language selection

**Playback Options:**

  - Speed control
  - Volume control
  - Multiple fact mode
  - Fact length preference

**History Management:**

  - Search history

**Social Features:**

  - Fact of the day
  - Most popular facts

**Scheduling:**

  - Quiet hours
  - Custom schedules
  - Weekend vs weekday

---

## Appendix A: Version History

**Version 1.0 (July 26, 2026)**

  - Initial release
  - Wikipedia API integration
  - 50+ curated categories
  - Negative content filtering
  - Duplicate fact prevention with persistent tracking
  - Category display for all facts (history and used facts list)
  - Next fact time display with automatic updates
  - Background operation with silent audio
  - Voice selection with persistence
  - Frequency control (1-120 minutes)
  - Random timing mode
  - Immediate launch behavior
  - Fact history with Wikipedia links
  - Share functionality
  - Dynamic title display during speech
  - Stop speaking button
  - Portrait-only orientation
  - Comprehensive settings management
  - Category and keyword customization
  - Auto-save settings changes
  - Used fact titles management with categories and deletion
  - Browse Wikipedia categories link
  - Public domain dedication (CC0 1.0)

---

## Appendix B: Dependencies

**System Frameworks:**

  - Foundation
  - SwiftUI
  - AVFoundation
  - Combine

**No Third-Party Libraries**

  - Pure Swift/SwiftUI implementation
  - No external dependencies
  - No package managers required

---

## Appendix C: Build Configuration

**Minimum iOS Version:** 15.0
**Supported Devices:** iPhone
**Orientation:** Portrait only
**Background Modes:** Audio (manually enabled)
**Swift Version:** 5.9+
**Xcode Version:** 15.0+
**Display Name:** WikiCurios

**Build Settings:**
  - Deployment target: iOS 15.0
  - Swift language version: 5
  - Enable background audio (manual capability)

---

## Appendix D: Contact and Support

**Project:** WikiCurios (Curiosities From Wikipedia)
**Author:** Stewart French
**Date Created:** July 26, 2026
**License:** CC0 1.0 Universal (Public Domain)

**Support:**

This is public domain software provided as-is without warranty or support.
Users are free to modify and redistribute as desired.

---

*End of Software Design Document*
