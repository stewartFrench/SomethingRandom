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
    @Published var maxSpokenSentences : Int                        = 3
    @Published var isHumorMode        : Bool                       = false
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
    private var timer            : Timer?
    private var audioPlayer      : AVAudioPlayer?
    private var factUtterance    : AVSpeechUtterance?
    private var pendingFactText  : String?
    private var isStopping       : Bool = false
    private var speechStartTimer : Timer?
    private var recoveryAttempts : Int = 0
    @Published private var usedFactTitles 
                                 : Set<UsedFactTitle> = []
    private var categoriesData   : CategoriesData
    @Published var categoryArticleCounts: [String: Int] = [:]
    private var categoryCountsTimestamp: Date?
    
    // Humorous categories for Humor Mode filtering
    private var humorousCategories: Set<String>
    {
        Set(categoriesData.humorousCategories + categoriesData.userAddedHumorousCategories)
    }
    
    
    
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
        loadMaxSpokenSentences()
        loadRandomTimingSetting()
        loadHumorMode()
        loadUsedFactTitles()
        loadCategoryArticleCounts()
        configureAudioSession()
        setupSilentAudioPlayer()
        
        // Observe audio session interruptions to restart silent audio
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Monitor app lifecycle to maintain background audio
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
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

    deinit
    {
        NotificationCenter.default.removeObserver(self)
    } // deinit
    
    
    
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

            // Use .playback with .voicePrompt for reliable background audio and CarPlay compatibility
            // .mixWithOthers allows music to continue playing during speech

            try audioSession.setCategory(.playback, 
                                          mode: .voicePrompt, 
                                          options: [.mixWithOthers])
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
        guard let player = audioPlayer else { return }
        
        if !player.isPlaying
        {
            player.play()
            
            // Verify playback started after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
            {
                [weak self] in
                if self?.audioPlayer?.isPlaying == false
                {
                    // Retry if failed - reconfigure audio session and try again
                    self?.configureAudioSession()
                    self?.audioPlayer?.play()
                } // if
            } // asyncAfter
        } // if
    } // startSilentAudio
    
    
    
    // -----------------------------------------

    private func stopSilentAudio()
    {
        audioPlayer?.stop()
    } // stopSilentAudio
    
    
    
    // -----------------------------------------
    // MARK: - Notification Handlers
    
    
    
    // -----------------------------------------
    
    @objc private func handleAudioSessionInterruption(notification: Notification)
    {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else
        {
            return
        } // guard
        
        if type == .ended
        {
            // Interruption ended - restart silent audio if timer is running
            if isEnabled
            {
                do
                {
                    try AVAudioSession.sharedInstance().setActive(true)
                    startSilentAudio()
                    
                    // Verify timer is still valid after interruption
                    if timer == nil || timer!.isValid == false
                    {
                        rescheduleNextFact()
                    } // if
                } // do
                catch
                {
                    // print("Failed to reactivate audio session after interruption: \(error)")
                } // catch
            } // if
        } // if
    } // handleAudioSessionInterruption
    
    
    
    // -----------------------------------------
    
    @objc private func handleAudioSessionRouteChange(notification: Notification)
    {
        // Restart silent audio if it stopped
        if isEnabled && audioPlayer?.isPlaying == false
        {
            startSilentAudio()
        } // if
    } // handleAudioSessionRouteChange
    
    
    
    // -----------------------------------------
    
    @objc private func appDidEnterBackground()
    {
        // Ensure silent audio is playing when entering background
        if isEnabled
        {
            startSilentAudio()
            
            // Verify timer is still valid - reschedule if needed
            if timer == nil || timer!.isValid == false
            {
                rescheduleNextFact()
            } // if
        } // if
    } // appDidEnterBackground
    
    
    
    // -----------------------------------------
    
    @objc private func appWillEnterForeground()
    {
        // Verify everything is still running when returning to foreground
        if isEnabled
        {
            if audioPlayer?.isPlaying == false
            {
                startSilentAudio()
            } // if
            
            // Verify timer is still valid
            if timer == nil || timer!.isValid == false
            {
                rescheduleNextFact()
            } // if
        } // if
    } // appWillEnterForeground
    
    
    
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




    private func loadMaxSpokenSentences()
    {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "maxSpokenSentences") != nil
        {
            maxSpokenSentences = defaults.integer(forKey: "maxSpokenSentences")
            // print("Restored max spoken sentences: \(maxSpokenSentences)")
        } // if
        else
        {
            // print("Using default max spoken sentences: \(maxSpokenSentences)")
        } // else
    } // loadMaxSpokenSentences



    // -----------------------------------------

    func saveMaxSpokenSentences()
    {
        let defaults = UserDefaults.standard
        defaults.set(maxSpokenSentences, forKey: "maxSpokenSentences")
    } // saveMaxSpokenSentences



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

    nonisolated private func truncateToSentences(_ text: String, maxSentences: Int) -> String
    {
        // Truncate text to first N sentences using natural-language segmentation
        
        var sentences: [String] = []
        var sentenceCount = 0
        
        text.enumerateSubstrings(in       : text.startIndex..<text.endIndex,
                                  options : .bySentences)
        {
            substring, _, _, stop in
            
            if let substring = substring,
               !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                sentences.append(substring)
                sentenceCount += 1
                
                if sentenceCount >= maxSentences
                {
                    stop = true
                } // if
            } // if
        } // enumerateSubstrings
        
        return sentences.joined()
    } // truncateToSentences
    
    
    
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

    private func loadHumorMode()
    {
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: "isHumorMode") != nil
        {
            isHumorMode = defaults.bool(forKey: "isHumorMode")
        }
    } // loadHumorMode
    
    
    
    // -----------------------------------------

    func saveHumorMode()
    {
        let defaults = UserDefaults.standard
        defaults.set(isHumorMode, forKey: "isHumorMode")
    } // saveHumorMode
    
    
    
    // -----------------------------------------

    private func loadUsedFactTitles()
    {
        let defaults = UserDefaults.standard
        
        // Try loading new format first (with categories and pageid)
        
        if let savedData = defaults.data(forKey: "usedFactTitlesWithCategories"),
           let savedTitles = try? JSONDecoder().decode([UsedFactTitle].self, from: savedData)
        {
            usedFactTitles = Set(savedTitles)
            // print("Restored \(usedFactTitles.count) used fact titles with categories")
        } // if
        else if let oldTitles = defaults.array(forKey: "usedFactTitles") as? [String]
        {
            // Migrate old format (titles only) to new format
            // Use pageid=0 for migrated data since we don't have the pageid

            usedFactTitles = Set(oldTitles.map { UsedFactTitle(title: $0, category: "Unknown", pageid: 0) })
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

    private func loadCategoryArticleCounts()
    {
        let defaults = UserDefaults.standard
        
        if let savedData = defaults.data(forKey: "categoryArticleCounts"),
           let timestamp = defaults.object(forKey: "categoryCountsTimestamp") as? Date,
           let counts = try? JSONDecoder().decode([String: Int].self, from: savedData)
        {
            // Only use cached data if less than 24 hours old
            if Date().timeIntervalSince(timestamp) < 24 * 60 * 60
            {
                categoryArticleCounts = counts
                categoryCountsTimestamp = timestamp
            }
        }
    } // loadCategoryArticleCounts
    
    
    
    // -----------------------------------------

    private func saveCategoryArticleCounts()
    {
        let defaults = UserDefaults.standard
        
        if let encodedData = try? JSONEncoder().encode(categoryArticleCounts)
        {
            defaults.set(encodedData, forKey: "categoryArticleCounts")
            defaults.set(Date(), forKey: "categoryCountsTimestamp")
        }
    } // saveCategoryArticleCounts
    
    
    
    // -----------------------------------------

    private func isFactTitleUsed(_ title: String) -> Bool
    {
        return usedFactTitles.contains(where: { $0.title == title })
    } // isFactTitleUsed
    

    // -----------------------------------------

    private func isFactPageIdUsed(_ pageid: Int) -> Bool
    {
        return usedFactTitles.contains(where: { $0.pageid == pageid })
    } // isFactPageIdUsed
    
    
    
    // -----------------------------------------

    private func markFactTitleAsUsed(_ title: String, category: String, pageid: Int)
    {
        let usedFact = UsedFactTitle(title: title, category: category, pageid: pageid)
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
        // Prevent concurrent fetches - if already loading or speaking, skip this request
        let shouldProceed = await MainActor.run
        {
            if isLoadingFact || isSpeaking
            {
                return false
            }
            isLoadingFact = true
            return true
        } // MainActor
        
        guard shouldProceed else
        {
            // print("Skipping fetch - already loading or speaking")
            return
        }

        do
        {
            let fact = try await fetchRandomWikipediaFact()

            await MainActor.run
            {
                isLoadingFact = false
                
                // Mark as used immediately to prevent duplicates in concurrent fetches
                if fact.category != "Error"
                {
                    markFactTitleAsUsed(fact.title, category: fact.category, pageid: fact.pageid)
                }
                
                factHistory.append(fact)
                speakFact(fact)
            } // MainActor
            
            // Fetch article count for this category in background (for display)
            let categoryWithUnderscores = fact.category.replacingOccurrences(of: " ", with: "_")
            if await MainActor.run(body: { self.categoryArticleCounts[categoryWithUnderscores] }) == nil
            {
                _ = await validateCategory(categoryWithUnderscores)
            }
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
                    category: "Error",
                    pageid: 0
                )
                speakFact(errorFact)
            } // MainActor
        } // catch
    } // fetchAndSpeakRandomFact
    
    
    
    // -----------------------------------------

    nonisolated private func fetchRandomWikipediaFact() async throws -> WikipediaFact
    {
        // Load categories and keywords from configuration
        var categories = await MainActor.run { self.categoriesData.categories }
        let isHumorModeEnabled = await MainActor.run { self.isHumorMode }
        
        // Filter to only humorous categories if Humor Mode is enabled
        if isHumorModeEnabled
        {
            categories = categories.filter { humorousCategories.contains($0) }
            
            // Fallback to all categories if no humorous ones are available
            if categories.isEmpty
            {
                categories = await MainActor.run { self.categoriesData.categories }
            }
        }
        
        let negativeKeywords = await MainActor.run { self.categoriesData.negativeKeywords }

        // Try up to 30 times to get a usable article
        for _ in 0..<30
        {
            // Pick a random category
            let category = categories.randomElement() ?? "Science"

            // Fetch random page from category
            if let fact = try await fetchFromCategory(category,
                                                       negativeKeywords: negativeKeywords)
            {
                return fact
            }
        } // for
        
        // If we couldn't find a suitable fact after 30 attempts, throw an error
        throw URLError(.cannotFindHost)
    } // fetchRandomWikipediaFact
    
    
    
    // -----------------------------------------





    // -----------------------------------------
    // -----------------------------------------

    // Validates a Wikipedia category and returns the article count
    // Returns nil if category is invalid or has no articles
    
    func validateCategory(_ category: String) async -> Int?
    {
        // Check cache first
        if let cachedCount = await MainActor.run(body: { self.categoryArticleCounts[category] })
        {
            return cachedCount
        }
        
        let urlString = "https://en.wikipedia.org/w/api.php?action=query&format=json&list=categorymembers&cmtitle=Category:\(category)&cmlimit=500&cmnamespace=0"
        
        guard let encodedURL = urlString.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else
        {
            return nil
        } // guard
        
        var request = URLRequest(url: url)
        request.setValue("WikiCurios/1.0 (iOS app; contact: stewart.french@gmail.com)", 
                         forHTTPHeaderField: "User-Agent")
        
        do
        {
            let (data, _) = try await URLSession.shared.data(for: request)
            let categoryResponse = try JSONDecoder().decode(WikipediaCategoryResponse.self, from: data)
            
            let count = categoryResponse.query.categorymembers.count
            if count > 0
            {
                // Cache the result
                await MainActor.run
                {
                    self.categoryArticleCounts[category] = count
                    self.saveCategoryArticleCounts()
                }
                return count
            }
            return nil
        }
        catch
        {
            return nil
        }
    } // validateCategory
    
    
    
    // -----------------------------------------

    nonisolated private func fetchFromCategory(_ category: String,
                                                negativeKeywords: [String]) async throws -> WikipediaFact?
    {
        // Wikipedia API endpoint to get random pages from a category
        let urlString = "https://en.wikipedia.org/w/api.php?action=query&format=json&list=categorymembers&cmtitle=Category:\(category)&cmlimit=50&cmnamespace=0"
        
        guard let encodedURL = urlString.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else
        {
            return nil
        } // guard
        
        var request = URLRequest(url: url)
        request.setValue("WikiCurios/1.0 (iOS app; contact: stewart.french@gmail.com)", 
                         forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse category members
        let categoryResponse = try JSONDecoder().decode(WikipediaCategoryResponse.self, from: data)
        
        guard !categoryResponse.query.categorymembers.isEmpty else
        {
            return nil
        } // guard

        // Pick a random page from the category
        guard let randomMember = categoryResponse.query.categorymembers.randomElement() else
        {
            return nil
        } // guard
        
        // Fetch the page summary
        let pageTitle = randomMember.title.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed) ?? randomMember.title
        let summaryURLString = "https://en.wikipedia.org/api/rest_v1/page/summary/\(pageTitle)"
        
        guard let summaryURL = URL(string: summaryURLString) else
        {
            return nil
        } // guard
        
        var summaryRequest = URLRequest(url: summaryURL)
        summaryRequest.setValue("WikiCurios/1.0 (iOS app; contact: stewart.french@gmail.com)", 
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
                return nil
            } // if
        } // for

        // Check if we've already used this fact (by pageid or title)
        let factTitle = summaryResponse.title
        let factPageId = summaryResponse.pageid
        
        if await MainActor.run(body: { self.isFactPageIdUsed(factPageId) || self.isFactTitleUsed(factTitle) })
        {
            // print("Filtered out duplicate fact: '\(factTitle)' (pageid: \(factPageId))")
            return nil
        } // if
        
        // Create a fact from the title and extract
        let factText = "\(summaryResponse.title). \(summaryResponse.extract)"
        
        // Get the Wikipedia URL from the response or construct it
        let wikiUrlString = summaryResponse.content_urls?.desktop?.page ?? 
                            "https://en.wikipedia.org/wiki/\(pageTitle)"
        
        guard let url = URL(string: wikiUrlString) else
        {
            return nil
        } // guard
        
        // Format category name for display (remove underscores)
        
        let displayCategory = category.replacingOccurrences(of: "_", with: " ")
        
        let fact = WikipediaFact(title: summaryResponse.title,
                                 text: factText,
                                 url: url,
                                 category: displayCategory,
                                 pageid: summaryResponse.pageid)

        return fact
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
        
        // If synthesizer is already speaking, stop it first and clean up state
        
        if synthesizer.isSpeaking || isSpeaking
        {
            // print("DEBUG: Synthesizer was already speaking, stopping first")
            
            // Clean up any pending state from interrupted speech
            pendingFactText = nil
            factUtterance = nil
            currentSpeakingTitle = ""
            isSpeaking = false
            
            // Cancel speech start timeout if any
            speechStartTimer?.invalidate()
            speechStartTimer = nil
            
            synthesizer.stopSpeaking(at: .immediate)
            
            // Wait briefly for the stop to complete
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)
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
        
        // Set the title immediately when we start speaking
        currentSpeakingTitle = fact.title
        
        // Truncate the fact text to maxSpokenSentences before speaking
        let truncatedText = truncateToSentences(fact.text, maxSentences: maxSpokenSentences)
        
        // Store the truncated fact text to be spoken after intro
        pendingFactText = truncatedText

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
        
        // DO NOT deactivate audio session - keep it active for background audio
        // Deactivating the session causes iOS to suspend the app in background
        
        // Clear stopping flag after a brief delay
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)
        {
            [weak self] in
            self?.isStopping = false
            // print("DEBUG: Stopping flag cleared")
        } // asyncAfter

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
        
        // Clean up all speech state
        isSpeaking = false
        currentSpeakingTitle = ""
        factUtterance = nil
        pendingFactText = nil
        
        // Cancel any pending speech start timeout
        speechStartTimer?.invalidate()
        speechStartTimer = nil

        // print("DEBUG: State after cancel - isSpeaking: \(isSpeaking), synthesizer.isSpeaking: \(synthesizer.isSpeaking)")
    } // speechSynthesizer didCancel
} // class WikipediaManager


// ------------
// Model for Wikipedia API response

struct WikipediaRandomResponse: Codable, Sendable
{
    let title   : String
    let extract : String
    let pageid  : Int
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
    let pageid: Int
} // struct WikipediaFact



// ------------
// Model to store a used fact title with its category

@preconcurrency struct UsedFactTitle: Codable, Identifiable, Sendable
{
    let id: UUID
    let title: String
    let category: String
    let pageid: Int
    
    init(title: String, category: String, pageid: Int)
    {
        self.id = UUID()
        self.title = title
        self.category = category
        self.pageid = pageid
    } // init
    
    // -----------------------------------------
    // Custom decoder for backward compatibility with data that doesn't have pageid

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.category = try container.decode(String.self, forKey: .category)
        // Default to 0 if pageid is missing (backward compatibility)
        self.pageid = try container.decodeIfPresent(Int.self, forKey: .pageid) ?? 0
    } // init(from:)
    
    // ------------
    private enum CodingKeys: String, CodingKey
    {
        case id, title, category, pageid
    } // CodingKeys
    
    // -----------------------------------------
    // Custom Hashable implementation - use pageid as primary identifier
    // Fall back to title+category for backward compatibility with old data
    
    static func == (lhs: UsedFactTitle, rhs: UsedFactTitle) -> Bool
    {
        // If both have valid pageids, compare those (most reliable)
        if lhs.pageid > 0 && rhs.pageid > 0 {
            return lhs.pageid == rhs.pageid
        }
        // Otherwise fall back to title+category comparison
        return lhs.title == rhs.title && lhs.category == rhs.category
    } // ==
    
    // -----------------------------------------

    func hash(into hasher: inout Hasher)
    {
        // Use pageid as primary hash if available
        if pageid > 0 {
            hasher.combine(pageid)
        } else {
            // Fall back to title+category for backward compatibility
            hasher.combine(title)
            hasher.combine(category)
        }
    } // hash
} // struct UsedFactTitle

extension UsedFactTitle: Hashable { }
