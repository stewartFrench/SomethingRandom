//
//  WikipediaManager.swift
//  SomethingRandom
//
//  Created by Stewart French on 7/24/26.
// 
//  Developed with significant assistance from Claude Sonnet 4.5 by
//  Anthropic.
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine

// -----------------------------------------
// Manager class to handle fetching and speaking Wikipedia facts

class WikipediaManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate
{
    @Published var isEnabled          : Bool                       = false
    @Published var frequencyMinutes   : Double                     = 5.0
    @Published var isRandomTiming     : Bool                       = false
    @Published var maxSentences       : Int                        = 2
    @Published var availableVoices    : [AVSpeechSynthesisVoice]   = []
    @Published var selectedVoice      : AVSpeechSynthesisVoice?
    @Published var isSpeaking         : Bool                       = false
    @Published var nextFactTime       : Date?
    @Published var lastFact           : String                     = ""
    @Published var currentSpeakingTitle : String                   = ""
    @Published var isLoadingFact      : Bool                       = false
    @Published var hasSpokenOnLaunch  : Bool                       = false
    @Published var factHistory        : [WikipediaFact]            = []
    
    var usedFactTitlesCount: Int
    {
        return usedFactTitles.count
    } // usedFactTitlesCount
    
    var usedFactTitlesList: [UsedFactTitle]
    {
        return Array(usedFactTitles).sorted { $0.title < $1.title }
    } // usedFactTitlesList
    
    private var synthesizer = AVSpeechSynthesizer()
    private var timer       : Timer?
    private var audioPlayer : AVAudioPlayer?
    private var factUtterance : AVSpeechUtterance?
    private var pendingFactText : String?
    private var isStopping : Bool = false
    private var speechStartTimer : Timer?
    private var recoveryAttempts : Int = 0
    @Published private var usedFactTitles : Set<UsedFactTitle> = []
    private var categoriesData : CategoriesData
    
    
    
    // -----------------------------------------

    override init()
    {
        // Load categories data before calling super.init
        categoriesData = CategoriesData.load()
        
        super.init()
        synthesizer.delegate = self
        loadAvailableVoices()
        loadVoiceSelection()
        loadFrequency()
        loadMaxSentences()
        loadRandomTimingSetting()
        loadUsedFactTitles()
        configureAudioSession()
        setupSilentAudioPlayer()
        
        // Speak one fact on launch after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            Task
            {
                await self.speakFactOnLaunch()
            } // Task
        } // DispatchQueue.main.asyncAfter
    } // init
    
    
    
    // -----------------------------------------

    private func speakFactOnLaunch() async
    {
        let shouldSpeak = await MainActor.run
        {
            if hasSpokenOnLaunch
            {
                return false
            } // if
            
            hasSpokenOnLaunch = true
            return true
        } // MainActor
        
        guard shouldSpeak else { return }
        
        await fetchAndSpeakRandomFact()
        
        // Schedule the next fact after speaking the launch fact
        await MainActor.run
        {
            scheduleNextFactAfterLaunch()
        } // MainActor
    } // speakFactOnLaunch
    
    
    
    // -----------------------------------------

    private func scheduleNextFactAfterLaunch()
    {
        // Start silent audio to keep app active in background
        startSilentAudio()
        
        // Calculate interval
        let intervalSeconds = getNextInterval()
        
        // Set next fact time
        nextFactTime = Date().addingTimeInterval(intervalSeconds)
        
        // Create timer for subsequent facts
        timer = Timer.scheduledTimer(withTimeInterval : intervalSeconds,
                                      repeats          : !isRandomTiming)
        {
            [weak self] _ in
            
            Task
            {
                await self?.fetchAndSpeakRandomFact()
            } // Task

            // If random timing, schedule next fact with new random interval

            if self?.isRandomTiming == true
            {
                self?.scheduleNextRandomFact()
            } // if
            else
            {
                // For fixed timing, update next fact time

                if let interval = self?.frequencyMinutes
                {
                    self?.nextFactTime = Date().addingTimeInterval(interval * 60)
                } // if
            } // else
        } // timer
        
        // Add timer to run loop for background execution
        
        if let timer = timer
        {
            RunLoop.main.add(timer, forMode: .common)
        } // if
        
        isEnabled = true
    } // scheduleNextFactAfterLaunch
    
    
    
    // -----------------------------------------

    private func loadAvailableVoices()
    {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter
            {
                $0.language.hasPrefix("en")
            } // filter
            .sorted
            {
                $0.name < $1.name
            } // sorted
    } // loadAvailableVoices
    
    
    
    // -----------------------------------------

    private func loadVoiceSelection()
    {
        let defaults = UserDefaults.standard
        
        if let savedVoiceIdentifier = defaults.string(forKey: "selectedVoiceIdentifier")
        {
            // Try to find the saved voice
            selectedVoice = availableVoices.first
            {
                $0.identifier == savedVoiceIdentifier
            } // first

            if selectedVoice != nil
            {
                // print("Restored voice: \(selectedVoice!.name) (\(selectedVoice!.language))")
            } // if
            else
            {
                // Saved voice not found, use default
                setDefaultVoice()
            } // else
        } // if
        else
        {
            // No saved voice, use default
            setDefaultVoice()
        } // else
    } // loadVoiceSelection
    
    
    
    // -----------------------------------------

    private func setDefaultVoice()
    {
        // Set default voice to Samantha (en-US)
        
        selectedVoice = availableVoices.first
        {
            $0.name == "Samantha" && $0.language == "en-US"
        } // first
        ?? availableVoices.first
        {
            $0.name == "Samantha"
        } // first
        ?? availableVoices.first
        {
            $0.language == "en-US"
        } // first
        ?? availableVoices.first
        
        if selectedVoice != nil
        {
            // print("Selected default voice: \(selectedVoice!.name) (\(selectedVoice!.language))")
            saveVoiceSelection()
        } // if
    } // setDefaultVoice
    
    
    
    // -----------------------------------------

    func saveVoiceSelection()
    {
        let defaults = UserDefaults.standard
        
        if let voice = selectedVoice
        {
            defaults.set(voice.identifier, forKey: "selectedVoiceIdentifier")
            // print("Saved voice: \(voice.name) (\(voice.language))")
        } // if
    } // saveVoiceSelection
    
    
    
    // -----------------------------------------
    private func configureAudioSession()
    {
        do
        {
            let audioSession = AVAudioSession.sharedInstance()

            // Use .playback category to ensure audio plays even in silent mode

            try audioSession.setCategory(.playback,
                                          mode    : .voicePrompt,
                                          options : [.mixWithOthers])
            try audioSession.setActive(true)
        } // do
        catch
        {
            // print("Failed to configure audio session: \(error)")
        } // catch
    } // configureAudioSession
    
    
    
    // -----------------------------------------

    private func setupSilentAudioPlayer()
    {
        // Create a 1 second silent audio buffer
        
        let sampleRate = 44100.0
        let duration   = 1.0
        let frameCount = UInt32(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate : sampleRate,
                                          channels                    : 1),
              let buffer = AVAudioPCMBuffer(pcmFormat      : format,
                                             frameCapacity : frameCount) else
        {
            // print("Failed to create audio buffer")
            return
        } // guard
        
        buffer.frameLength = frameCount
        
        // Fill with silence (zeros)
        
        if let channelData = buffer.floatChannelData
        {
            let data = channelData[0]
            for i in 0..<Int(frameCount)
            {
                data[i] = 0.0
            } // for
        } // if
        
        // Create temporary file for silent audio
        
        let tempDir    = FileManager.default.temporaryDirectory
        let silenceURL = tempDir.appendingPathComponent("silence.caf")
        
        do
        {
            // Write silent audio to file

            let audioFile = try AVAudioFile(forWriting : silenceURL,
                                             settings   : format.settings)
            try audioFile.write(from: buffer)

            // Setup audio player with the silent file

            audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume        = 0.0
            audioPlayer?.prepareToPlay()
        } // do
        catch
        {
            // print("Failed to setup silent audio player: \(error)")
        } // catch
    } // setupSilentAudioPlayer
    
    
    
    // -----------------------------------------

    private func startSilentAudio()
    {
        audioPlayer?.play()
    } // startSilentAudio
    
    
    
    // -----------------------------------------

    private func stopSilentAudio()
    {
        audioPlayer?.stop()
    } // stopSilentAudio
    
    
    
    // -----------------------------------------

    private func loadFrequency()
    {
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: "frequencyMinutes") != nil
        {
            frequencyMinutes = defaults.double(forKey: "frequencyMinutes")
            // print("Restored frequency: \(Int(frequencyMinutes)) minutes")
        } // if
        else
        {
            // print("Using default frequency: \(Int(frequencyMinutes)) minutes")
        } // else
    } // loadFrequency
    
    
    
    // -----------------------------------------

    private func saveFrequency()
    {
        let defaults = UserDefaults.standard
        defaults.set(frequencyMinutes, forKey: "frequencyMinutes")
    } // saveFrequency



    // -----------------------------------------

    private func loadMaxSentences()
    {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "maxSentences") != nil
        {
            maxSentences = defaults.integer(forKey: "maxSentences")
            // print("Restored max sentences: \(maxSentences)")
        } // if
        else
        {
            // print("Using default max sentences: \(maxSentences)")
        } // else
    } // loadMaxSentences



    // -----------------------------------------

    func saveMaxSentences()
    {
        let defaults = UserDefaults.standard
        defaults.set(maxSentences, forKey: "maxSentences")
    } // saveMaxSentences



    // -----------------------------------------

    nonisolated private func sentenceCount(in text: String) -> Int
    {
        // Count sentences using the system's natural-language segmentation,
        // which handles abbreviations better than naive punctuation splitting.

        var count = 0

        text.enumerateSubstrings(in       : text.startIndex..<text.endIndex,
                                  options : .bySentences)
        {
            substring, _, _, _ in

            if let substring = substring,
               !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                count += 1
            } // if
        } // enumerateSubstrings

        return count
    } // sentenceCount
    
    
    
    // -----------------------------------------

    private func loadRandomTimingSetting()
    {
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: "isRandomTiming") != nil
        {
            isRandomTiming = defaults.bool(forKey: "isRandomTiming")
            // print("Restored random timing: \(isRandomTiming)")
        } // if
        else
        {
            // print("Using default random timing: \(isRandomTiming)")
        } // else
    } // loadRandomTimingSetting
    
    
    
    // -----------------------------------------

    func saveRandomTimingSetting()
    {
        let defaults = UserDefaults.standard
        defaults.set(isRandomTiming, forKey: "isRandomTiming")
        
        // If timer is running, restart it with new random setting
        
        if isEnabled
        {
            updateFrequency(frequencyMinutes)
        } // if
    } // saveRandomTimingSetting
    
    
    
    // -----------------------------------------

    private func loadUsedFactTitles()
    {
        let defaults = UserDefaults.standard
        
        // Try loading new format first (with categories)
        
        if let savedData = defaults.data(forKey: "usedFactTitlesWithCategories"),
           let savedTitles = try? JSONDecoder().decode([UsedFactTitle].self, from: savedData)
        {
            usedFactTitles = Set(savedTitles)
            // print("Restored \(usedFactTitles.count) used fact titles with categories")
        } // if
        else if let oldTitles = defaults.array(forKey: "usedFactTitles") as? [String]
        {
            // Migrate old format (titles only) to new format

            usedFactTitles = Set(oldTitles.map { UsedFactTitle(title: $0, category: "Unknown") })
            // print("Migrated \(usedFactTitles.count) used fact titles from old format")

            // Save in new format

            saveUsedFactTitles()
        } // else if
        else
        {
            // print("No used fact titles found - starting fresh")
        } // else
    } // loadUsedFactTitles
    
    
    
    // -----------------------------------------

    private func saveUsedFactTitles()
    {
        let defaults = UserDefaults.standard
        let titlesArray = Array(usedFactTitles)
        
        if let encodedData = try? JSONEncoder().encode(titlesArray)
        {
            defaults.set(encodedData, forKey: "usedFactTitlesWithCategories")
        } // if
    } // saveUsedFactTitles
    
    
    
    // -----------------------------------------

    private func isFactTitleUsed(_ title: String) -> Bool
    {
        return usedFactTitles.contains(where: { $0.title == title })
    } // isFactTitleUsed
    
    
    
    // -----------------------------------------

    private func markFactTitleAsUsed(_ title: String, category: String)
    {
        let usedFact = UsedFactTitle(title: title, category: category)
        usedFactTitles.insert(usedFact)
        saveUsedFactTitles()
    } // markFactTitleAsUsed
    
    
    
    // -----------------------------------------

    func removeUsedFactTitle(_ usedFact: UsedFactTitle)
    {
        usedFactTitles.remove(usedFact)
        saveUsedFactTitles()
    } // removeUsedFactTitle
    
    
    
    // -----------------------------------------

    func clearAllUsedFactTitles()
    {
        usedFactTitles.removeAll()
        saveUsedFactTitles()
    } // clearAllUsedFactTitles
    
    
    
    // -----------------------------------------

    func reloadCategories()
    {
        categoriesData = CategoriesData.load()
        // print("Reloaded categories: \(categoriesData.categories.count) categories, \(categoriesData.negativeKeywords.count) keywords")
    } // reloadCategories
    
    
    
    // -----------------------------------------

    func fetchAndSpeakRandomFact() async
    {
        await MainActor.run
        {
            isLoadingFact = true
        } // MainActor

        do
        {
            let fact = try await fetchRandomWikipediaFact()

            await MainActor.run
            {
                isLoadingFact = false
                factHistory.append(fact)
                speakFact(fact)
            } // MainActor
        } // do
        catch
        {
            await MainActor.run
            {
                isLoadingFact = false
                // print("Failed to fetch Wikipedia fact: \(error)")

                // Speak an error message
                let errorFact = WikipediaFact(
                    title: "Sorry, I couldn't fetch a random fact from Wikipedia right now.",
                    text: "Sorry, I couldn't fetch a random fact from Wikipedia right now.",
                    url: URL(string: "https://en.wikipedia.org")!,
                    category: "Error"
                )
                speakFact(errorFact)
            } // MainActor
        } // catch
    } // fetchAndSpeakRandomFact
    
    
    
    // -----------------------------------------

    nonisolated private func fetchRandomWikipediaFact() async throws -> WikipediaFact
    {
        // Load categories and keywords from configuration
        let categories = await MainActor.run { self.categoriesData.categories }
        let negativeKeywords = await MainActor.run { self.categoriesData.negativeKeywords }
        var maxSentences = await MainActor.run { self.maxSentences }

        // Upper bound for automatically raising the sentence limit. Matches the
        // range of the Settings stepper so the persisted value stays in range.
        let sentenceLimitCeiling = 20

        // Keep trying, raising the sentence limit if a full round of attempts
        // fails only because facts kept exceeding the current limit.
        while true
        {
            var sawTooManySentences = false

            // Try up to 10 times to get a usable article
            for _ in 0..<10
            {
                // Pick a random category
                let category = categories.randomElement() ?? "Science"

                // Fetch random page from category
                let result = try await fetchFromCategory(category,
                                                          negativeKeywords: negativeKeywords,
                                                          maxSentences: maxSentences)

                switch result
                {
                    case .found(let fact):
                        return fact

                    case .tooManySentences:
                        sawTooManySentences = true

                    case .filtered:
                        break
                } // switch
            } // for

            // If the round failed and at least one candidate was rejected purely
            // for exceeding the sentence limit, raise the limit by 1, persist it,
            // and try again. Otherwise give up.

            guard sawTooManySentences, maxSentences < sentenceLimitCeiling else
            {
                throw URLError(.cannotFindHost)
            } // guard

            maxSentences += 1
            let newLimit = maxSentences

            await MainActor.run
            {
                self.maxSentences = newLimit
                self.saveMaxSentences()
            } // MainActor
        } // while
    } // fetchRandomWikipediaFact
    
    
    
    // -----------------------------------------

    // Outcome of a single fetch attempt. Distinguishes a rejection due to the
    // sentence limit from other rejections so the caller can decide whether to
    // raise the limit and retry.

    private enum FactFetchResult
    {
        case found(WikipediaFact)
        case tooManySentences
        case filtered
    } // FactFetchResult



    // -----------------------------------------

    nonisolated private func fetchFromCategory(_ category: String,
                                                negativeKeywords: [String],
                                                maxSentences: Int) async throws -> FactFetchResult
    {
        // Wikipedia API endpoint to get random pages from a category
        let urlString = "https://en.wikipedia.org/w/api.php?action=query&format=json&list=categorymembers&cmtitle=Category:\(category)&cmlimit=50&cmnamespace=0"
        
        guard let encodedURL = urlString.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else
        {
            return .filtered
        } // guard
        
        var request = URLRequest(url: url)
        request.setValue("SLFRandom/1.0 (iOS app; contact: stewart.french@gmail.com)", 
                         forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse category members
        let categoryResponse = try JSONDecoder().decode(WikipediaCategoryResponse.self, from: data)
        
        guard !categoryResponse.query.categorymembers.isEmpty else
        {
            return .filtered
        } // guard

        // Pick a random page from the category
        guard let randomMember = categoryResponse.query.categorymembers.randomElement() else
        {
            return .filtered
        } // guard
        
        // Fetch the page summary
        let pageTitle = randomMember.title.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed) ?? randomMember.title
        let summaryURLString = "https://en.wikipedia.org/api/rest_v1/page/summary/\(pageTitle)"
        
        guard let summaryURL = URL(string: summaryURLString) else
        {
            return .filtered
        } // guard
        
        var summaryRequest = URLRequest(url: summaryURL)
        summaryRequest.setValue("SLFRandom/1.0 (iOS app; contact: stewart.french@gmail.com)", 
                                 forHTTPHeaderField: "User-Agent")
        
        let (summaryData, _) = try await URLSession.shared.data(for: summaryRequest)
        let summaryResponse = try JSONDecoder().decode(WikipediaRandomResponse.self, 
                                                         from: summaryData)
        
        // Filter out articles with negative keywords
        let combinedText = "\(summaryResponse.title) \(summaryResponse.extract)".lowercased()
        
        for keyword in negativeKeywords
        {
            if combinedText.contains(keyword.lowercased())
            {
                // print("Filtered out article containing '\(keyword)': \(summaryResponse.title)")
                return .filtered
            } // if
        } // for

        // Discard facts whose body exceeds the maximum sentence count

        if sentenceCount(in: summaryResponse.extract) > maxSentences
        {
            // print("Filtered out article with too many sentences: \(summaryResponse.title)")
            return .tooManySentences
        } // if

        // Check if we've already used this fact title
        let factTitle = summaryResponse.title
        
        if await MainActor.run(body: { self.isFactTitleUsed(factTitle) })
        {
            // print("Filtered out duplicate fact: '\(factTitle)'")
            return .filtered
        } // if
        
        // Create a fact from the title and extract
        let factText = "\(summaryResponse.title). \(summaryResponse.extract)"
        
        // Get the Wikipedia URL from the response or construct it
        let wikiUrlString = summaryResponse.content_urls?.desktop?.page ?? 
                            "https://en.wikipedia.org/wiki/\(pageTitle)"
        
        guard let url = URL(string: wikiUrlString) else
        {
            return .filtered
        } // guard
        
        // Format category name for display (remove underscores)
        
        let displayCategory = category.replacingOccurrences(of: "_", with: " ")
        
        let fact = WikipediaFact(title: summaryResponse.title,
                                 text: factText,
                                 url: url,
                                 category: displayCategory)

        return .found(fact)
    } // fetchFromCategory
    
    
    
    // -----------------------------------------

    private func speakFact(_ fact: WikipediaFact)
    {
        // print("Speaking: '\(fact.text.prefix(50))...'")
        // print("DEBUG: synthesizer.isSpeaking = \(synthesizer.isSpeaking)")
        // print("DEBUG: isSpeaking flag = \(isSpeaking)")
        // print("DEBUG: isStopping flag = \(isStopping)")
        // print("DEBUG: factUtterance = \(factUtterance != nil ? "exists" : "nil")")
        
        // If we're in the middle of stopping, wait and try again
        
        if isStopping
        {
            // print("DEBUG: Currently stopping, will retry after delay")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6)
            {
                [weak self] in
                self?.speakFact(fact)
            } // asyncAfter
            
            return
        } // if
        
        // If synthesizer is already speaking, stop it first and wait for it to stop
        
        if synthesizer.isSpeaking
        {
            // print("DEBUG: Synthesizer was already speaking, stopping first")
            synthesizer.stopSpeaking(at: .immediate)
            
            // Wait briefly for the stop to complete
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
            {
                [weak self] in
                self?.performSpeech(fact: fact)
            } // asyncAfter
            
            return
        } // if
        
        performSpeech(fact: fact)
    } // speakFact
    
    
    
    // -----------------------------------------

    private func performSpeech(fact: WikipediaFact)
    {
        // print("DEBUG: performSpeech starting")
        // print("DEBUG: synthesizer.isSpeaking at start of performSpeech: \(synthesizer.isSpeaking)")
        
        // Make absolutely sure synthesizer is stopped
        
        if synthesizer.isSpeaking
        {
            // print("DEBUG: Synthesizer still speaking in performSpeech, stopping again")
            synthesizer.stopSpeaking(at: .immediate)
            
            // Try again after a delay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)
            {
                [weak self] in
                self?.performSpeech(fact: fact)
            } // asyncAfter
            
            return
        } // if
        
        // Mark the title as used (use the stored title so the value recorded
        // exactly matches the one checked in fetchFromCategory)
        markFactTitleAsUsed(fact.title, category: fact.category)
        
        // Set the title immediately when we start speaking
        currentSpeakingTitle = fact.title
        
        // Store the fact text to be spoken after intro
        pendingFactText = fact.text

        // print("DEBUG: About to speak intro utterance")

        // First speak "Wikipedia" with a long pause after
        let introUtterance = AVSpeechUtterance(string: "Wikipedia")
        introUtterance.voice              = selectedVoice ?? 
                                            AVSpeechSynthesisVoice(language: "en-US")
        introUtterance.rate               = 0.52
        introUtterance.pitchMultiplier    = 1.1
        introUtterance.volume             = 1.0
        introUtterance.preUtteranceDelay  = 0.1
        introUtterance.postUtteranceDelay = 1.5  // Long pause after "Wikipedia"
        
        synthesizer.speak(introUtterance)

        // print("DEBUG: Intro utterance speak() called, synthesizer.isSpeaking now: \(synthesizer.isSpeaking)")
        // print("DEBUG: Intro utterance queued, fact will be queued after intro finishes")
        
        // Start a timeout to detect if speech never starts
        
        speechStartTimer?.invalidate()
        speechStartTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false)
        {
            [weak self] _ in
            self?.handleSpeechStartTimeout(fact: fact)
        } // Timer
        
        // If timer is running, reschedule next fact from now
        
        if isEnabled
        {
            rescheduleNextFact()
        } // if
    } // performSpeech
    
    
    
    // -----------------------------------------

    private func handleSpeechStartTimeout(fact: WikipediaFact)
    {
        // If didStart was never called within 1 second, synthesizer is stuck
        
        if !isSpeaking && pendingFactText != nil
        {
            recoveryAttempts += 1

            // print("DEBUG: Speech never started! Attempting recovery (attempt \(recoveryAttempts)/3)...")
            
            // Give up after 3 attempts
            
            if recoveryAttempts > 3
            {
                // print("DEBUG: Recovery failed after 3 attempts, giving up")

                // Clear all state
                
                pendingFactText = nil
                factUtterance = nil
                currentSpeakingTitle = ""
                isSpeaking = false
                recoveryAttempts = 0
                
                return
            } // if
            
            // Force stop and clear everything
            
            synthesizer.stopSpeaking(at: .immediate)
            pendingFactText = nil
            factUtterance = nil
            currentSpeakingTitle = ""
            
            // Recreate the synthesizer (this is the nuclear option)

            // print("DEBUG: Recreating synthesizer...")
            synthesizer = AVSpeechSynthesizer()
            synthesizer.delegate = self
            
            // Try to reset audio session
            
            do
            {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                try audioSession.setActive(true)
                // print("DEBUG: Audio session reset for recovery")
            } // do
            catch
            {
                // print("DEBUG: Failed to reset audio session: \(error)")
            } // catch
            
            // Try speaking again after a delay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
            {
                [weak self] in
                // print("DEBUG: Retrying speech after timeout recovery")
                self?.performSpeech(fact: fact)
            } // asyncAfter
        } // if
    } // handleSpeechStartTimeout
    
    
    
    // -----------------------------------------

    func startTimer()
    {
        stopTimer()
        isEnabled = true
        
        // Start silent audio to keep app active in background
        
        startSilentAudio()
        
        // Calculate interval (random if enabled, fixed otherwise)
        
        let intervalSeconds = getNextInterval()
        
        // Set next fact time
        
        nextFactTime = Date().addingTimeInterval(intervalSeconds)
        
        timer = Timer.scheduledTimer(withTimeInterval : intervalSeconds,
                                      repeats          : !isRandomTiming)
        {
            [weak self] _ in
            
            Task
            {
                await self?.fetchAndSpeakRandomFact()
            } // Task

            // If random timing, schedule next fact with new random interval

            if self?.isRandomTiming == true
            {
                self?.scheduleNextRandomFact()
            } // if
            else
            {
                // For fixed timing, update next fact time

                if let interval = self?.frequencyMinutes
                {
                    self?.nextFactTime = Date().addingTimeInterval(interval * 60)
                } // if
            } // else
        } // timer
        
        // Add timer to run loop for background execution
        
        if let timer = timer
        {
            RunLoop.main.add(timer, forMode: .common)
        } // if
        
        // Speak one immediately when starting

        Task
        {
            await fetchAndSpeakRandomFact()
        } // Task
    } // startTimer
    
    
    
    // -----------------------------------------

    private func getNextInterval() -> TimeInterval
    {
        if isRandomTiming
        {
            // Random interval between 1 minute and the slider value

            let randomMinutes = Double.random(in: 1...frequencyMinutes)
            // print("Next fact in \(Int(randomMinutes)) minutes (random, max: " +
            //       "\(Int(frequencyMinutes)))")
            return randomMinutes * 60
        } // if
        else
        {
            return frequencyMinutes * 60
        } // else
    } // getNextInterval
    
    
    
    // -----------------------------------------

    private func scheduleNextRandomFact()
    {
        // Invalidate current timer
        
        timer?.invalidate()
        timer = nil
        
        // Schedule next fact with new random interval
        
        let intervalSeconds = getNextInterval()
        
        // Set next fact time
        
        nextFactTime = Date().addingTimeInterval(intervalSeconds)
        
        timer = Timer.scheduledTimer(withTimeInterval : intervalSeconds,
                                      repeats          : false)
        {
            [weak self] _ in

            Task
            {
                await self?.fetchAndSpeakRandomFact()
            } // Task

            self?.scheduleNextRandomFact()
        } // timer
        
        // Add timer to run loop for background execution
        
        if let timer = timer
        {
            RunLoop.main.add(timer, forMode: .common)
        } // if
    } // scheduleNextRandomFact
    
    
    
    // -----------------------------------------

    func stopTimer()
    {
        timer?.invalidate()
        timer        = nil
        isEnabled    = false
        nextFactTime = nil
        
        // Stop silent audio when timer is stopped
        
        stopSilentAudio()
    } // stopTimer
    
    
    
    // -----------------------------------------

    func updateFrequency(_ minutes: Double)
    {
        frequencyMinutes = minutes
        saveFrequency()
        
        if isEnabled
        {
            // Reschedule next fact with new frequency

            rescheduleNextFact()
        } // if
    } // updateFrequency
    
    
    
    // -----------------------------------------

    private func rescheduleNextFact()
    {
        // Stop current timer
        
        timer?.invalidate()
        timer = nil
        
        // Calculate new interval
        
        let intervalSeconds = getNextInterval()
        
        // Set next fact time from now
        
        nextFactTime = Date().addingTimeInterval(intervalSeconds)
        
        // Create new timer
        
        timer = Timer.scheduledTimer(withTimeInterval : intervalSeconds,
                                      repeats          : !isRandomTiming)
        {
            [weak self] _ in
            
            Task
            {
                await self?.fetchAndSpeakRandomFact()
            } // Task

            // If random timing, schedule next fact with new random interval

            if self?.isRandomTiming == true
            {
                self?.scheduleNextRandomFact()
            } // if
            else
            {
                // For fixed timing, update next fact time

                if let interval = self?.frequencyMinutes
                {
                    self?.nextFactTime = Date().addingTimeInterval(interval * 60)
                } // if
            } // else
        } // timer
        
        // Add timer to run loop for background execution
        
        if let timer = timer
        {
            RunLoop.main.add(timer, forMode: .common)
        } // if
    } // rescheduleNextFact
    
    
    
    // -----------------------------------------

    func stopSpeaking()
    {
        // print("DEBUG: stopSpeaking() called, synthesizer.isSpeaking = \(synthesizer.isSpeaking)")

        isStopping = true
        
        // Cancel any pending speech start timer
        
        speechStartTimer?.invalidate()
        speechStartTimer = nil
        
        synthesizer.stopSpeaking(at: .immediate)
        
        // Reset state immediately
        isSpeaking = false
        currentSpeakingTitle = ""
        factUtterance = nil
        pendingFactText = nil
        
        // Reset audio session to ensure clean state
        
        do
        {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Small delay before reactivating
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
            {
                [weak self] in
                
                do
                {
                    try AVAudioSession.sharedInstance().setActive(true)
                    // print("DEBUG: Audio session reactivated")
                } // do
                catch
                {
                    // print("DEBUG: Failed to reactivate audio session: \(error)")
                } // catch
                
                // Clear stopping flag after audio session is reset
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)
                {
                    self?.isStopping = false
                    // print("DEBUG: Stopping flag cleared")
                } // asyncAfter
            } // asyncAfter
        } // do
        catch
        {
            // print("DEBUG: Failed to deactivate audio session: \(error)")

            // Still clear stopping flag

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
            {
                [weak self] in
                self?.isStopping = false
                // print("DEBUG: Stopping flag cleared (after error)")
            } // asyncAfter
        } // catch

        // print("DEBUG: stopSpeaking() completed")
    } // stopSpeaking
    
    
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    
    
    // -----------------------------------------

    func speechSynthesizer(     _ synthesizer : AVSpeechSynthesizer,
                           didStart utterance : AVSpeechUtterance)
    {
        // print("DEBUG: didStart called for: \(utterance.speechString.prefix(30))...")
        // print("DEBUG: Is intro: \(utterance.speechString == "Wikipedia"), is fact: \(utterance === factUtterance)")

        // Cancel timeout timer since speech started successfully
        
        speechStartTimer?.invalidate()
        speechStartTimer = nil
        
        // Reset recovery attempts on successful start
        
        recoveryAttempts = 0
        
        isSpeaking = true
    } // speechSynthesizer didStart
    
    
    
    // -----------------------------------------

    func speechSynthesizer(      _ synthesizer : AVSpeechSynthesizer,
                           didFinish utterance : AVSpeechUtterance)
    {
        // print("DEBUG: didFinish called")

        // Check if this is the intro utterance finishing

        if utterance.speechString == "Wikipedia", let pendingText = pendingFactText
        {
            // print("DEBUG: Intro finished, now queuing fact utterance")
            
            // Now speak the actual fact

            factUtterance = AVSpeechUtterance(string: pendingText)
            factUtterance!.voice              = selectedVoice ?? 
                                                AVSpeechSynthesisVoice(language: "en-US")
            factUtterance!.rate               = 0.52
            factUtterance!.pitchMultiplier    = 1.1
            factUtterance!.volume             = 1.0
            factUtterance!.preUtteranceDelay  = 0.1
            factUtterance!.postUtteranceDelay = 0.2
            
            synthesizer.speak(factUtterance!)
            pendingFactText = nil

            // print("DEBUG: Fact utterance queued")
        } // if
        else if utterance === factUtterance
        {
            // print("DEBUG: Fact utterance finished")
            isSpeaking = false
            currentSpeakingTitle = ""
            factUtterance = nil
        } // else if
    } // speechSynthesizer didFinish
    
    
    
    // -----------------------------------------

    func speechSynthesizer(_ synthesizer : AVSpeechSynthesizer,
                           didCancel utterance : AVSpeechUtterance)
    {
        // print("DEBUG: didCancel called, utterance was: \(utterance.speechString.prefix(30))...")
        // print("DEBUG: Was intro: \(utterance.speechString == "Wikipedia"), was fact: \(utterance === factUtterance)")
        isSpeaking = false
        currentSpeakingTitle = ""
        factUtterance = nil
        pendingFactText = nil

        // print("DEBUG: State after cancel - isSpeaking: \(isSpeaking), synthesizer.isSpeaking: \(synthesizer.isSpeaking)")
    } // speechSynthesizer didCancel
} // class WikipediaManager


// ------------
// Model for Wikipedia API response

struct WikipediaRandomResponse: Codable, Sendable
{
    let title   : String
    let extract : String
    let content_urls: ContentUrls?
    
    struct ContentUrls: Codable, Sendable
    {
        let desktop: DesktopUrl?

        struct DesktopUrl: Codable, Sendable
        {
            let page: String
        } // struct DesktopUrl
    } // struct ContentUrls
} // struct WikipediaRandomResponse


// ------------
// Model for Wikipedia category query response

struct WikipediaCategoryResponse: Codable, Sendable
{
    let query: WikipediaQuery
} // struct WikipediaCategoryResponse


// ------------

struct WikipediaQuery: Codable, Sendable
{
    let categorymembers: [WikipediaCategoryMember]
} // struct WikipediaQuery


// ------------

struct WikipediaCategoryMember: Codable, Sendable
{
    let title: String
} // struct WikipediaCategoryMember


// ------------
// Model to store a fact with its Wikipedia URL

struct WikipediaFact: Identifiable
{
    let id = UUID()
    let title: String
    let text: String
    let url: URL
    let category: String
} // struct WikipediaFact



// ------------
// Model to store a used fact title with its category

@preconcurrency struct UsedFactTitle: Codable, Hashable, Identifiable, Sendable
{
    let id: UUID
    let title: String
    let category: String
    
    init(title: String, category: String)
    {
        self.id = UUID()
        self.title = title
        self.category = category
    } // init
} // struct UsedFactTitle
