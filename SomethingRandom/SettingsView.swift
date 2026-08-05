//
//  SettingsView.swift
//  SomethingRandom
//
//  Created by Stewart French on 7/26/26.
//

import SwiftUI


// ------------
struct SettingsView: View
{
    @ObservedObject var wikipediaManager: WikipediaManager
    @Environment(\.dismiss) var dismiss

    @State private var categoriesData: CategoriesData
    @State private var showingUsedFacts = false
    @State private var showResetConfirmation = false



    // -----------------------------------------
    init(wikipediaManager: WikipediaManager)
    {
        self.wikipediaManager = wikipediaManager
        _categoriesData = State(initialValue: CategoriesData.load())
    } // init



    // -----------------------------------------
    var body: some View
    {
        NavigationView
        {
            Form
            {
                // Categories Management

                Section
                {
                    NavigationLink(destination: CategoriesEditorView(categoriesData: $categoriesData, wikipediaManager: wikipediaManager))
                    {
                        HStack
                        {
                            Text("Manage Categories")

                            Spacer()

                            Text("\(categoriesData.categories.count)")
                                .foregroundColor(.secondary)
                        } // HStack
                    } // NavigationLink
                } // Section

                // Keywords Management

                Section
                {
                    NavigationLink(destination: KeywordsEditorView(categoriesData: $categoriesData, wikipediaManager: wikipediaManager))
                    {
                        HStack
                        {
                            Text("Manage Negative Keywords")

                            Spacer()

                            Text("\(categoriesData.negativeKeywords.count)")
                                .foregroundColor(.secondary)
                        } // HStack
                    } // NavigationLink
                } // Section

                // Humor Mode Section

                Section(header: Text("Content Filter"))
                {
                    Toggle("Humor Mode", isOn: $wikipediaManager.isHumorMode)
                        .onChange(of: wikipediaManager.isHumorMode)
                        {
                            oldValue, newValue in
                            wikipediaManager.saveHumorMode()
                        }
                    
                    Text("When enabled, only humorous and entertaining categories are used.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } // Section

                // Spoken Length Section

                Section(header: Text("Spoken Length"))
                {
                    Stepper(value : $wikipediaManager.maxSpokenSentences,
                            in    : 1...20)
                    {
                        Text("Limit speaking to \(wikipediaManager.maxSpokenSentences) " +
                             (wikipediaManager.maxSpokenSentences == 1 ? "sentence" : "sentences"))
                    } // Stepper
                    .onChange(of: wikipediaManager.maxSpokenSentences)
                    {
                        oldValue, newValue in
                        wikipediaManager.saveMaxSpokenSentences()
                    } // onChange

                    Text("Only the first \(wikipediaManager.maxSpokenSentences) " +
                         (wikipediaManager.maxSpokenSentences == 1 ? "sentence" : "sentences") +
                         " of each fact will be spoken, even if the full fact is longer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } // Section

                // Info Section

                Section(header: Text("Information"))
                {
                    VStack(alignment: .leading, spacing: 8)
                    {
                        Text("Total Categories: \(categoriesData.categories.count)")
                        Text("  • Default: \(categoriesData.categories.count - categoriesData.userAddedCategories.count)")
                            .font(.caption)
                        Text("  • My Categories: \(categoriesData.userAddedCategories.count)")
                            .font(.caption)

                        Divider()
                            .padding(.vertical, 4)

                        Text("Total Negative Keywords: \(categoriesData.negativeKeywords.count)")
                        Text("  • Default: \(categoriesData.negativeKeywords.count - categoriesData.userAddedKeywords.count)")
                            .font(.caption)
                        Text("  • My Negative Keywords: \(categoriesData.userAddedKeywords.count)")
                            .font(.caption)

                        Text("\nCategories determine which types of Wikipedia articles to fetch. Negative keywords filter out unwanted content.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } // VStack
                } // Section

                // Used Facts Section

                Section
                {
                    Button("View Used Fact Titles (\(wikipediaManager.usedFactTitlesCount))")
                    {
                        showingUsedFacts = true
                    } // Button
                    .foregroundColor(.blue)
                } // Section

                // Actions Section

                Section
                {
                    Button("Reset to Defaults")
                    {
                        showResetConfirmation = true
                    } // Button
                    .foregroundColor(.orange)
                } // Section
            } // Form
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .navigationBarTrailing)
                {
                    Button("Done")
                    {
                        dismiss()
                    } // Button
                } // ToolbarItem
            } // toolbar
            .sheet(isPresented: $showingUsedFacts)
            {
                UsedFactsView(wikipediaManager: wikipediaManager)
            } // sheet
            .alert("Reset to Defaults?", isPresented: $showResetConfirmation)
            {
                Button("Cancel", role: .cancel) { }
                
                Button("Reset", role: .destructive)
                {
                    do
                    {
                        try CategoriesData.resetToDefaults()
                        categoriesData = CategoriesData.load()
                        wikipediaManager.reloadCategories()
                    } // do
                    catch
                    {
                        // print("Failed to reset: \(error.localizedDescription)")
                    } // catch
                }
            } message: {
                Text("This will restore all categories to the default list and remove any custom categories you've added. This cannot be undone.")
            }
        } // NavigationView
    } // body
} // struct SettingsView



// ------------
struct CategoriesEditorView: View
{
    @Binding var categoriesData: CategoriesData
    @ObservedObject var wikipediaManager: WikipediaManager
    @State private var newCategory: String = ""
    @State private var isValidating: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var selectedCategory: String?
    @State private var showCategoryInfo: Bool = false
    @State private var categoryToDelete: String?
    @State private var showDeleteConfirmation: Bool = false
    @State private var isUserCategory: Bool = false



    // -----------------------------------------
    var body: some View
    {
        Form
        {
            // Browse Wikipedia Categories Link

            Section
            {
                Link(destination: URL(string: "https://en.wikipedia.org/wiki/Portal:Contents/Categories")!)
                {
                    HStack
                    {
                        Image(systemName: "safari")
                            .foregroundColor(.blue)

                        Text("Browse Wikipedia Categories")
                            .foregroundColor(.blue)

                        Spacer()

                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } // HStack
                } // Link
            } // Section

            // User Added Categories Section

            if !categoriesData.userAddedCategories.isEmpty
            {
                Section(header: Text("My Categories"))
                {
                    ForEach(categoriesData.userAddedCategories.sorted(), id: \.self)
                    {
                        category in

                        HStack
                        {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.blue)

                            Text(category.replacingOccurrences(of: "_", with: " "))
                                .font(.body)

                            Spacer()

                            Button(action:
                            {
                                categoryToDelete = category
                                isUserCategory = true
                                showDeleteConfirmation = true
                            }) // Button
                            {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            } // Button
                            .buttonStyle(BorderlessButtonStyle())
                        } // HStack
                        .contentShape(Rectangle())
                        .onTapGesture
                        {
                            selectedCategory = category
                            
                            // Load article count first, then show alert
                            Task
                            {
                                _ = await wikipediaManager.validateCategory(category)
                                await MainActor.run
                                {
                                    showCategoryInfo = true
                                }
                            }
                        }
                    } // ForEach
                } // Section
            } // if

            // Add Category Section

            Section
            {
                HStack
                {
                    TextField("Add new category", text: $newCategory)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(isValidating ? "Validating..." : "Add")
                    {
                        let trimmed = newCategory.trimmingCharacters(in: .whitespaces)

                        // Convert spaces to underscores for Wikipedia API compatibility
                        let categoryWithUnderscores = trimmed.replacingOccurrences(of: " ", with: "_")

                        if trimmed.isEmpty
                        {
                            return
                        }
                        
                        // Check if category already exists
                        if categoriesData.categories.contains(categoryWithUnderscores)
                        {
                            let displayName = categoryWithUnderscores.replacingOccurrences(of: "_", with: " ")
                            alertTitle = "Duplicate Category"
                            alertMessage = "'\(displayName)' is already in your category list."
                            showAlert = true
                            return
                        }
                        
                        isValidating = true
                        
                        Task
                        {
                            if let articleCount = await wikipediaManager.validateCategory(categoryWithUnderscores)
                            {
                                // Category is valid
                                await MainActor.run
                                {
                                    categoriesData.categories.append(categoryWithUnderscores)
                                    categoriesData.userAddedCategories.append(categoryWithUnderscores)
                                    newCategory = ""
                                    
                                    // Auto-save immediately
                                    try? categoriesData.save()
                                    wikipediaManager.reloadCategories()
                                    
                                    // Show success alert
                                    let displayName = categoryWithUnderscores.replacingOccurrences(of: "_", with: " ")
                                    alertTitle = "Category Added"
                                    alertMessage = "'\(displayName)' is valid with \(articleCount) article\(articleCount == 1 ? "" : "s")."
                                    showAlert = true
                                    isValidating = false
                                }
                            }
                            else
                            {
                                // Category is invalid
                                await MainActor.run
                                {
                                    let displayName = categoryWithUnderscores.replacingOccurrences(of: "_", with: " ")
                                    alertTitle = "Invalid Category"
                                    alertMessage = "'\(displayName)' was not found on Wikipedia or has no articles."
                                    showAlert = true
                                    isValidating = false
                                }
                            }
                        }
                    } // Button
                    .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                } // HStack
            } // Section

            // Default Categories Section

            Section(header: Text("Default Categories"))
            {
                ForEach(categoriesData.categories.filter { !categoriesData.userAddedCategories.contains($0) }.sorted(), id: \.self)
                {
                    category in

                    HStack
                    {
                        Text(category.replacingOccurrences(of: "_", with: " "))
                            .font(.body)

                        Spacer()

                        Button(action:
                        {
                            categoryToDelete = category
                            isUserCategory = false
                            showDeleteConfirmation = true
                        }) // Button
                        {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        } // Button
                        .buttonStyle(BorderlessButtonStyle())
                    } // HStack
                    .contentShape(Rectangle())
                    .onTapGesture
                    {
                        selectedCategory = category
                        
                        // Load article count first, then show alert
                        Task
                        {
                            _ = await wikipediaManager.validateCategory(category)
                            await MainActor.run
                            {
                                showCategoryInfo = true
                            }
                        }
                    }
                } // ForEach
            } // Section
        } // Form
        .navigationTitle("Manage Categories")
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle, isPresented: $showAlert)
        {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert(selectedCategory?.replacingOccurrences(of: "_", with: " ") ?? "Category Info", isPresented: $showCategoryInfo)
        {
            Button("OK", role: .cancel) { }
            
            if let category = selectedCategory
            {
                Button("View on Wikipedia")
                {
                    if let url = URL(string: "https://en.wikipedia.org/wiki/Category:\(category)")
                    {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } message: {
            if let category = selectedCategory,
               let count = wikipediaManager.categoryArticleCounts[category]
            {
                Text("This category has \(count) article\(count == 1 ? "" : "s").")
            }
        }
        .alert("Delete Category?", isPresented: $showDeleteConfirmation)
        {
            Button("Cancel", role: .cancel) { }
            
            Button("Delete", role: .destructive)
            {
                guard let category = categoryToDelete else { return }
                
                if isUserCategory
                {
                    // Remove from user added categories
                    if let index = categoriesData.userAddedCategories.firstIndex(of: category)
                    {
                        categoriesData.userAddedCategories.remove(at: index)
                    }
                }
                
                // Remove from main categories list
                if let catIndex = categoriesData.categories.firstIndex(of: category)
                {
                    categoriesData.categories.remove(at: catIndex)
                }
                
                // Auto-save immediately
                try? categoriesData.save()
                wikipediaManager.reloadCategories()
                
                categoryToDelete = nil
            }
        } message: {
            if let category = categoryToDelete
            {
                Text("Are you sure you want to delete '\(category.replacingOccurrences(of: "_", with: " "))'?")
            }
        }
    } // body
} // struct CategoriesEditorView



// ------------
struct KeywordsEditorView: View
{
    @Binding var categoriesData: CategoriesData
    @ObservedObject var wikipediaManager: WikipediaManager
    @State private var newKeyword: String = ""



    // -----------------------------------------
    var body: some View
    {
        Form
        {
            // Add Keyword Section

            Section
            {
                HStack
                {
                    TextField("Add new keyword", text: $newKeyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)

                    Button("Add")
                    {
                        let trimmed = newKeyword.trimmingCharacters(in: .whitespaces).lowercased()

                        if !trimmed.isEmpty && !categoriesData.negativeKeywords.contains(trimmed)
                        {
                            categoriesData.negativeKeywords.append(trimmed)
                            categoriesData.userAddedKeywords.append(trimmed)
                            newKeyword = ""
                            
                            // Auto-save immediately
                            
                            try? categoriesData.save()
                            wikipediaManager.reloadCategories()
                        } // if
                    } // Button
                    .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                } // HStack
            } // Section

            // User Added Keywords Section

            if !categoriesData.userAddedKeywords.isEmpty
            {
                Section(header: Text("My Negative Keywords"))
                {
                    ForEach(categoriesData.userAddedKeywords.sorted(), id: \.self)
                    {
                        keyword in

                        HStack
                        {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.blue)

                            Text(keyword)
                                .font(.body)

                            Spacer()

                            Button(action:
                            {
                                if let index = categoriesData.userAddedKeywords.firstIndex(of: keyword)
                                {
                                    categoriesData.userAddedKeywords.remove(at: index)

                                    if let kwIndex = categoriesData.negativeKeywords.firstIndex(of: keyword)
                                    {
                                        categoriesData.negativeKeywords.remove(at: kwIndex)
                                    } // if
                                    
                                    // Auto-save immediately
                                    
                                    try? categoriesData.save()
                                    wikipediaManager.reloadCategories()
                                } // if
                            }) // Button
                            {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            } // Button
                        } // HStack
                    } // ForEach
                } // Section
            } // if

            // Default Negative Keywords Section

            Section(header: Text("Default Negative Keywords"))
            {
                ForEach(categoriesData.negativeKeywords.filter { !categoriesData.userAddedKeywords.contains($0) }.sorted(), id: \.self)
                {
                    keyword in

                    HStack
                    {
                        Text(keyword)
                            .font(.body)

                        Spacer()

                        Button(action:
                        {
                            if let index = categoriesData.negativeKeywords.firstIndex(of: keyword)
                            {
                                categoriesData.negativeKeywords.remove(at: index)
                                
                                // Auto-save immediately
                                
                                try? categoriesData.save()
                                wikipediaManager.reloadCategories()
                            } // if
                        }) // Button
                        {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        } // Button
                    } // HStack
                } // ForEach
            } // Section
        } // Form
        .navigationTitle("Manage Keywords")
        .navigationBarTitleDisplayMode(.inline)
    } // body
} // struct KeywordsEditorView



// ------------
struct UsedFactsView: View
{
    @ObservedObject var wikipediaManager: WikipediaManager
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteAllAlert = false



    // -----------------------------------------
    var body: some View
    {
        NavigationView
        {
            VStack(spacing: 0)
            {
                // Share All Titles Button at top
                
                if !wikipediaManager.usedFactTitlesList.isEmpty
                {
                    ShareLink(item: createHTMLFile())
                    {
                        Label("Share All Titles", systemImage: "square.and.arrow.up")
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                    } // ShareLink
                    .padding()
                } // if
                
                List
                {
                    ForEach(wikipediaManager.usedFactTitlesList, id: \.self)
                {
                    usedFact in

                    Link(destination: wikipediaURL(for: usedFact.title))
                    {
                        HStack
                        {
                            VStack(alignment: .leading, spacing: 4)
                            {
                                Text(usedFact.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 4)
                                {
                                    Text("Category: \(usedFact.category)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let count = wikipediaManager.categoryArticleCounts[usedFact.category.replacingOccurrences(of: " ", with: "_")]
                                    {
                                        Text("(\(count) articles)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } // VStack
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } // HStack
                        .padding(.vertical, 4)
                    } // Link
                } // ForEach
                .onDelete(perform: deleteTitle)
            } // List
            
            // Delete All Button at bottom
            
            if !wikipediaManager.usedFactTitlesList.isEmpty
            {
                Button(action:
                {
                    showingDeleteAllAlert = true
                }) // Button
                {
                    Text("Delete All Used Titles")
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                } // Button
                .padding()
            } // if
        } // VStack
            .navigationTitle("Used Fact Titles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .navigationBarTrailing)
                {
                    Button("Done")
                    {
                        dismiss()
                    } // Button
                } // ToolbarItem
            } // toolbar
            .alert("Delete All Titles", isPresented: $showingDeleteAllAlert)
            {
                Button("Cancel", role: .cancel) { }
                
                Button("Delete All", role: .destructive)
                {
                    wikipediaManager.clearAllUsedFactTitles()
                    dismiss()
                } // Button
            } message:
            {
                Text("Are you sure you want to delete all used fact titles? This cannot be undone.")
            } // alert
        } // NavigationView
    } // body



    // -----------------------------------------
    private func deleteTitle(at offsets: IndexSet)
    {
        let titles = wikipediaManager.usedFactTitlesList
        
        for index in offsets
        {
            let title = titles[index]
            wikipediaManager.removeUsedFactTitle(title)
        } // for
    } // deleteTitle
    
    
    
    // -----------------------------------------
    private func createShareText() -> String
    {
        let usedFacts = wikipediaManager.usedFactTitlesList
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Used Wikipedia Fact Titles</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }
                h1 { color: #333; }
                .fact { margin-bottom: 20px; padding: 15px; background-color: #f5f5f5; border-radius: 8px; }
                .title { font-size: 18px; font-weight: bold; color: #0066cc; margin-bottom: 5px; }
                .category { font-size: 14px; color: #666; margin-bottom: 5px; }
                .url { font-size: 14px; }
                a { color: #0066cc; text-decoration: none; }
                a:hover { text-decoration: underline; }
            </style>
        </head>
        <body>
            <h1>Used Wikipedia Fact Titles</h1>
        
        """
        
        for (index, usedFact) in usedFacts.enumerated()
        {
            let url = wikipediaURL(for: usedFact.title)
            html += """
                <div class="fact">
                    <div class="title">\(index + 1). \(usedFact.title)</div>
                    <div class="category">Category: \(usedFact.category)</div>
                    <div class="url"><a href="\(url.absoluteString)">\(url.absoluteString)</a></div>
                </div>
            
            """
        } // for
        
        html += """
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
    private func wikipediaURL(for title: String) -> URL
    {
        // Convert title to Wikipedia URL format
        // Replace spaces with underscores and encode special characters

        let urlTitle = title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title

        return URL(string: "https://en.wikipedia.org/wiki/\(urlTitle)")!
    } // wikipediaURL
} // struct UsedFactsView

