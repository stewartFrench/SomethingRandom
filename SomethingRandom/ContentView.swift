//
//  ContentView.swift
//  SomethingRandom
//
//  Created by Stewart French on 7/24/26.
//
//  Developed with significant assistance from Claude Sonnet 4.5 by
//  Anthropic.
// 

import SwiftUI
import AVFoundation


// -----------------------------------------

struct ContentView: View
{
    @StateObject private var wikipediaManager = WikipediaManager()
    @State private var showingShareSheet = false
    @State private var showingSettings = false
    
    
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            // Compact header and controls
            
            VStack(spacing: 15)
            {
                // Settings button in top right
                
                HStack
                {
                    Spacer()
                    
                    Button(action:
                    {
                        showingSettings = true
                    }) // Button
                    {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    } // Button
                    .padding(.trailing)
                } // HStack
                .padding(.top, 10)
                
                // Header with app icon
                
                VStack(spacing: 8)
                {
                    // App icon - using a bundled image
                    if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
                       let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
                       let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
                       let iconName = iconFiles.last,
                       let image = UIImage(named: iconName)
                    {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .cornerRadius(14)
                    } // if
                    else
                    {
                        // Fallback to custom icon or SF Symbol
                        Image(systemName: "book.circle.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(.blue)
                    } // else
                    
                    if !wikipediaManager.currentSpeakingTitle.isEmpty
                    {
                        // Extract just the title (first sentence before the first period)
                        let title = wikipediaManager.currentSpeakingTitle.components(separatedBy: ". ").first ??
                                    wikipediaManager.currentSpeakingTitle

                        Text(title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal)
                    } // if
                    else
                    {
                        Text("Curiosities From Wikipedia")
                            .font(.title3)
                            .fontWeight(.bold)
                    } // else
                } // VStack
                .padding(.top, 20)
                
                // Compact controls
                
                HStack(spacing: 10)
                {
                    Picker("Voice", selection: $wikipediaManager.selectedVoice)
                    {
                        ForEach(wikipediaManager.availableVoices, id: \.identifier)
                        {
                            voice in
                            Text(voice.name).tag(voice as AVSpeechSynthesisVoice?)
                        } // ForEach
                    } // Picker
                    .pickerStyle(.menu)
                    .onChange(of: wikipediaManager.selectedVoice)
                    {
                        oldValue, newValue in
                        wikipediaManager.saveVoiceSelection()
                    } // onChange
                    
                    HStack(spacing: 8)
                    {
                        Text("\(Int(wikipediaManager.frequencyMinutes))m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let nextTime = wikipediaManager.nextFactTime
                        {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(nextTime, style: .time)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } // if
                    } // HStack
                } // HStack
                .padding(.horizontal)
                
                // Frequency slider
                
                HStack
                {
                    Slider(value : $wikipediaManager.frequencyMinutes,
                           in    : 1...120,
                           step  : 1)
                    .onChange(of: wikipediaManager.frequencyMinutes)
                    {
                        oldValue, newValue in
                        wikipediaManager.updateFrequency(newValue)
                    } // onChange

                    Button(action:
                    {
                        wikipediaManager.isRandomTiming.toggle()
                        wikipediaManager.saveRandomTimingSetting()
                    }, // Button action
                    label:
                    {
                        Image(systemName: "shuffle")
                            .font(.caption)
                            .padding(8)
                            .background(wikipediaManager.isRandomTiming ?
                                        Color.blue :
                                        Color.gray.opacity(0.2))
                            .foregroundStyle(wikipediaManager.isRandomTiming ?
                                             .white :
                                             .primary)
                            .cornerRadius(8)
                    } // Button label
                    ) // Button
                } // HStack
                .padding(.horizontal)
                
                // Control buttons
                
                HStack(spacing: 10)
                {
                    Button(action:
                    {
                        if wikipediaManager.isEnabled
                        {
                            wikipediaManager.stopTimer()
                        } // if
                        else
                        {
                            wikipediaManager.startTimer()
                        } // else
                    }, // Button action
                    label:
                    {
                        Label(
                            wikipediaManager.isEnabled ? "Stop" : "Start",
                            systemImage: wikipediaManager.isEnabled ?
                                         "stop.circle.fill" :
                                         "play.circle.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth : .infinity)
                        .padding(.vertical, 12)
                        .background(wikipediaManager.isEnabled ? Color.red : Color.green)
                        .cornerRadius(10)
                    } // Button label
                    ) // Button
                    
                    Button(action:
                    {
                        Task
                        {
                            await wikipediaManager.fetchAndSpeakRandomFact()
                        } // Task
                    }, // Button action
                    label:
                    {
                        HStack
                        {
                            if wikipediaManager.isLoadingFact
                            {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } // if
                            else
                            {
                                Image(systemName: "speaker.wave.2.fill")
                            } // else

                            Text("Now")
                        } // HStack
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth : .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    } // Button label
                    ) // Button
                    .disabled(wikipediaManager.isLoadingFact)
                } // HStack
                .padding(.horizontal)
                .padding(.bottom, 10)
            } // VStack
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // Share button for fact history
            
            if !wikipediaManager.factHistory.isEmpty
            {
                HStack
                {
                    Spacer()

                    Button(action:
                    {
                        showingShareSheet = true
                    }, // Button action
                    label:
                    {
                        Label("Share All Facts", systemImage: "square.and.arrow.up")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    } // Button label
                    ) // Button
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                } // HStack
                .background(Color(UIColor.secondarySystemBackground))
            } // if
            
            Divider()
            
            // Wikipedia response text display - shows all facts in history
            
            ScrollView
            {
                ScrollViewReader
                {
                    proxy in

                    VStack(alignment: .leading, spacing: 0)
                    {
                        if wikipediaManager.factHistory.isEmpty
                        {
                            Text("Wikipedia facts will appear here...")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } // if
                        else
                        {
                            ForEach(wikipediaManager.factHistory)
                            {
                                fact in

                                let index = wikipediaManager.factHistory.firstIndex(where: { $0.id == fact.id }) ?? 0

                                VStack(alignment: .leading, spacing: 8)
                                {
                                    HStack
                                    {
                                        Text("Fact #\(index + 1)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.blue)

                                        Spacer()

                                        if index == wikipediaManager.factHistory.count - 1
                                        {
                                            Text("Latest")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.green)
                                        } // if
                                    } // HStack

                                    Text(fact.text)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("Category: \(fact.category)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)

                                    // Wikipedia link button
                                    Link(destination: fact.url)
                                    {
                                        HStack
                                        {
                                            Image(systemName: "link.circle.fill")
                                                .font(.caption)
                                            Text("Read more on Wikipedia")
                                                .font(.caption)
                                        } // HStack
                                        .foregroundStyle(.blue)
                                        .padding(.top, 4)
                                    } // Link
                                } // VStack
                                .padding()
                                .background(index == wikipediaManager.factHistory.count - 1 ?
                                            Color(UIColor.tertiarySystemBackground) :
                                            Color.clear)
                                .id("fact_\(fact.id)")

                                if index < wikipediaManager.factHistory.count - 1
                                {
                                    Divider()
                                } // if
                            } // ForEach
                        } // else
                    } // VStack
                    .onChange(of: wikipediaManager.factHistory.count)
                    {
                        oldValue, newValue in
                        withAnimation
                        {
                            if newValue > 0, let lastFact = wikipediaManager.factHistory.last
                            {
                                proxy.scrollTo("fact_\(lastFact.id)", anchor: .top)
                            } // if
                        } // withAnimation
                    } // onChange
                } // ScrollViewReader
            } // ScrollView
            .background(Color(UIColor.secondarySystemBackground))
            
            // Stop speaking button - fixed at bottom when speaking
            
            if wikipediaManager.isSpeaking
            {
                Button(action:
                {
                    wikipediaManager.stopSpeaking()
                }, // Button action
                label:
                {
                    Label("Stop Speaking", systemImage: "stop.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth : .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(10)
                } // Button label
                ) // Button
                .padding(.horizontal)
                .padding(.bottom, 20)
                .background(
                    Color(UIColor.systemBackground)
                        .shadow(color  : .black.opacity(0.1),
                                radius : 10,
                                x      : 0,
                                y      : -5)
                ) // background
                .transition(.move(edge: .bottom))
                .animation(.easeInOut(duration: 0.2), value: wikipediaManager.isSpeaking)
            } // if
        } // VStack
        .sheet(isPresented: $showingShareSheet)
        {
            ShareSheet(items: [createHTMLFile()])
        } // sheet
        .sheet(isPresented: $showingSettings)
        {
            SettingsView(wikipediaManager: wikipediaManager)
        } // sheet
    } // body
    
    
    
    // -----------------------------------------

    private func createShareText() -> String
    {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Curiosities From Wikipedia</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }
                h1 { color: #333; }
                .fact { margin-bottom: 20px; padding: 15px; background-color: #f5f5f5; border-radius: 8px; }
                .fact-number { font-size: 14px; font-weight: bold; color: #0066cc; margin-bottom: 8px; }
                .fact-text { font-size: 16px; line-height: 1.5; margin-bottom: 8px; }
                .fact-link { font-size: 14px; }
                a { color: #0066cc; text-decoration: none; }
                a:hover { text-decoration: underline; }
                .footer { margin-top: 30px; font-size: 14px; color: #666; text-align: center; }
            </style>
        </head>
        <body>
            <h1>Curiosities From Wikipedia</h1>
        
        """
        
        for (index, fact) in wikipediaManager.factHistory.enumerated()
        {
            html += """
                <div class="fact">
                    <div class="fact-number">Fact #\(index + 1)</div>
                    <div class="fact-text">\(fact.text)</div>
                    <div class="fact-link"><a href="\(fact.url.absoluteString)">Read more on Wikipedia</a></div>
                </div>
            
            """
        } // for
        
        html += """
            <div class="footer">Shared from the WikiCurios app</div>
        </body>
        </html>
        """
        
        return html
    } // createShareText
    
    
    
    // -----------------------------------------

    private func createHTMLFile() -> URL
    {
        let html = createShareText()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("WikiCurios_Facts.html")
        
        do
        {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
        } // do
        catch
        {
            // print("Failed to write HTML file: \(error)")
        } // catch
        
        return fileURL
    } // createHTMLFile
    
    
    
    // -----------------------------------------

    private func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String
    {
        let languageCode = voice.language
        return "\(voice.name) (\(languageCode))"
    } // voiceDisplayName
} // struct ContentView


// -----------------------------------------
// ShareSheet wrapper for UIActivityViewController

struct ShareSheet: UIViewControllerRepresentable
{
    let items: [Any]
    
    
    
    func makeUIViewController(context: Context) -> UIActivityViewController
    {
        let controller = UIActivityViewController(activityItems: items,
                                                    applicationActivities: nil)
        return controller
    } // makeUIViewController
    
    
    
    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                 context: Context)
    {
        // No update needed
    } // updateUIViewController
} // struct ShareSheet


#Preview {
    ContentView()
} // Preview
