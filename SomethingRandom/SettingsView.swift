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
        } // NavigationView
    } // body
} // struct SettingsView



// ------------
struct CategoriesEditorView: View
{
    @Binding var categoriesData: CategoriesData
    @ObservedObject var wikipediaManager: WikipediaManager
    @State private var newCategory: String = ""



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
                                if let index = categoriesData.userAddedCategories.firstIndex(of: category)
                                {
                                    categoriesData.userAddedCategories.remove(at: index)

                                    if let catIndex = categoriesData.categories.firstIndex(of: category)
                                    {
                                        categoriesData.categories.remove(at: catIndex)
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

            // Add Category Section

            Section
            {
                HStack
                {
                    TextField("Add new category", text: $newCategory)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("Add")
                    {
                        let trimmed = newCategory.trimmingCharacters(in: .whitespaces)

                        // Convert spaces to underscores for Wikipedia API compatibility
                        let categoryWithUnderscores = trimmed.replacingOccurrences(of: " ", with: "_")

                        if !trimmed.isEmpty && !categoriesData.categories.contains(categoryWithUnderscores)
                        {
                            categoriesData.categories.append(categoryWithUnderscores)
                            categoriesData.userAddedCategories.append(categoryWithUnderscores)
                            newCategory = ""
                            
                            // Auto-save immediately
                            
                            try? categoriesData.save()
                            wikipediaManager.reloadCategories()
                        } // if
                    } // Button
                    .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
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
                            if let index = categoriesData.categories.firstIndex(of: category)
                            {
                                categoriesData.categories.remove(at: index)
                                
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
        .navigationTitle("Manage Categories")
        .navigationBarTitleDisplayMode(.inline)
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
                                
                                Text("Category: \(usedFact.category)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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

