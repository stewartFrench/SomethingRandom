//
//  CategoriesData.swift
//  SomethingRandom
//
//  Created by Stewart French on 7/26/26.
//

import Foundation


// ------------
// Model for loading categories and negative keywords from JSON
struct CategoriesData: Codable, Sendable
{
    var categories       : [String]
    var negativeKeywords : [String]
    var userAddedCategories : [String]
    var userAddedKeywords   : [String]
    
    
    
    // -----------------------------------------
    init(categories: [String], negativeKeywords: [String], userAddedCategories: [String] = [], userAddedKeywords: [String] = [])
    {
        self.categories = categories
        self.negativeKeywords = negativeKeywords
        self.userAddedCategories = userAddedCategories
        self.userAddedKeywords = userAddedKeywords
    } // init
    
    
    
    // -----------------------------------------
    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = try container.decode([String].self, forKey: .categories)
        negativeKeywords = try container.decode([String].self, forKey: .negativeKeywords)
        
        // These fields are optional for backward compatibility
        userAddedCategories = try container.decodeIfPresent([String].self, forKey: .userAddedCategories) ?? []
        userAddedKeywords = try container.decodeIfPresent([String].self, forKey: .userAddedKeywords) ?? []
    } // init
    
    
    
    // -----------------------------------------
    static func load() -> CategoriesData
    {
        // Try to load from documents directory first (user customizations)
        
        if let documentsData = loadFromDocumentsDirectory()
        {
            return documentsData
        } // if
        
        // Fall back to bundle (default categories)
        
        return loadFromBundle()
    } // load
    
    
    
    // -----------------------------------------
    private static func loadFromDocumentsDirectory() -> CategoriesData?
    {
        guard let documentsURL = FileManager.default.urls(
            for        : .documentDirectory,
            in         : .userDomainMask
        ).first else
        {
            return nil
        } // guard
        
        let fileURL = documentsURL.appendingPathComponent("categories.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else
        {
            return nil
        } // guard
        
        do
        {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let categoriesData = try decoder.decode(CategoriesData.self, from: data)
            // print("Loaded categories from documents directory")
            return categoriesData
        } // do
        catch
        {
            // print("Failed to load categories from documents: \(error)")
            return nil
        } // catch
    } // loadFromDocumentsDirectory
    
    
    
    // -----------------------------------------
    private static func loadFromBundle() -> CategoriesData
    {
        guard let url = Bundle.main.url(forResource   : "categories",
                                        withExtension : "json") else
        {
            // print("Failed to find categories.json in bundle, using defaults")
            return createDefaultData()
        } // guard
        
        do
        {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let categoriesData = try decoder.decode(CategoriesData.self, from: data)
            // print("Loaded categories from bundle")
            return categoriesData
        } // do
        catch
        {
            // print("Failed to decode categories.json: \(error)")
            return createDefaultData()
        } // catch
    } // loadFromBundle
    
    
    
    // -----------------------------------------
    private static func createDefaultData() -> CategoriesData
    {
        return CategoriesData(
            categories: ["Science", "History", "Geography"],
            negativeKeywords: ["murder", "death", "war", "crime"]
        )
    } // createDefaultData
    
    
    
    // -----------------------------------------
    func save() throws
    {
        guard let documentsURL = FileManager.default.urls(
            for        : .documentDirectory,
            in         : .userDomainMask
        ).first else
        {
            throw NSError(domain   : "CategoriesData",
                         code      : 1,
                         userInfo  : [NSLocalizedDescriptionKey: "Could not find documents directory"])
        } // guard
        
        let fileURL = documentsURL.appendingPathComponent("categories.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(self)
        try data.write(to: fileURL)

        // print("Saved categories to: \(fileURL.path)")
    } // save
    
    
    
    // -----------------------------------------
    static func resetToDefaults() throws
    {
        guard let documentsURL = FileManager.default.urls(
            for        : .documentDirectory,
            in         : .userDomainMask
        ).first else
        {
            return
        } // guard
        
        let fileURL = documentsURL.appendingPathComponent("categories.json")
        
        if FileManager.default.fileExists(atPath: fileURL.path)
        {
            try FileManager.default.removeItem(at: fileURL)
            // print("Removed custom categories file")
        } // if
    } // resetToDefaults
} // struct CategoriesData
