//
//  SearchService.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import Foundation
import ObjCDump

/// Actor responsible for performing searches with caching and incremental updates.
actor SearchService {
    
    // MARK: - Dependencies
    
    private let repository: RuntimeRepository
    
    // MARK: - Search Data
    
    private var classNames: [String] = []
    private var protocolNames: [String] = []
    
    // MARK: - Caches
    
    /// Cache of searchable content for classes (loaded on-demand during deep search).
    private var searchableContentCache: [String: SearchableContent] = [:]
    
    /// Cache of deep search results by normalized query.
    private var deepSearchResultsCache: [String: Set<String>] = [:]
    
    // MARK: - Initialization
    
    init(repository: RuntimeRepository) {
        self.repository = repository
    }
    
    // MARK: - Setup
    
    /// Updates the search data with the current runtime state.
    func updateSearchData(classNames: [String], protocolNames: [String]) {
        self.classNames = classNames
        self.protocolNames = protocolNames
    }
    
    /// Clears all caches.
    func clearCaches() {
        searchableContentCache.removeAll()
        deepSearchResultsCache.removeAll()
    }
    
    // MARK: - Search
    
    /// Performs a search and sends updates via the provided closure.
    /// - Parameters:
    ///   - query: The search query string.
    ///   - showClasses: Whether to include classes in results.
    ///   - showProtocols: Whether to include protocols in results.
    ///   - onUpdate: Closure called with search updates.
    func search(
        query: String,
        showClasses: Bool,
        showProtocols: Bool,
        onUpdate: @MainActor @Sendable (SearchUpdate) -> Void
    ) async {
        guard !query.isEmpty else { return }
        
        let normalizedQuery = query.lowercased()
        
        let nameMatches = await performNameSearch(
            query: normalizedQuery,
            showClasses: showClasses,
            showProtocols: showProtocols
        )
        
        guard !Task.isCancelled else { return }
        
        await onUpdate(SearchUpdate(
            results: nameMatches,
            phase: showClasses ? .searchingDeep : .complete
        ))
        
        guard showClasses else { return }
        
        let allResults = await performDeepSearch(
            query: normalizedQuery,
            existingMatches: nameMatches
        )
        
        guard !Task.isCancelled else { return }
        
        await onUpdate(SearchUpdate(results: allResults, phase: .complete))
    }
    
    // MARK: - Private Search Helpers
    
    /// Performs name-based search with prioritization (exact > prefix > contains).
    private func performNameSearch(
        query: String,
        showClasses: Bool,
        showProtocols: Bool
    ) async -> [TypeIdentifier] {
        var exactMatches: [TypeIdentifier] = []
        var prefixMatches: [TypeIdentifier] = []
        var containsMatches: [TypeIdentifier] = []
        
        if showClasses {
            for name in classNames {
                guard !Task.isCancelled else { return [] }
                let nameLowercased = name.lowercased()
                let identifier = TypeIdentifier.className(name)
                
                if nameLowercased == query {
                    exactMatches.append(identifier)
                } else if nameLowercased.hasPrefix(query) {
                    prefixMatches.append(identifier)
                } else if nameLowercased.contains(query) {
                    containsMatches.append(identifier)
                }
            }
        }
        
        if showProtocols {
            for name in protocolNames {
                guard !Task.isCancelled else { return [] }
                let nameLowercased = name.lowercased()
                let identifier = TypeIdentifier.protocolName(name)
                
                if nameLowercased == query {
                    exactMatches.append(identifier)
                } else if nameLowercased.hasPrefix(query) {
                    prefixMatches.append(identifier)
                } else if nameLowercased.contains(query) {
                    containsMatches.append(identifier)
                }
            }
        }
        
        prefixMatches.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        containsMatches.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        return exactMatches + prefixMatches + containsMatches
    }
    
    /// Performs deep search through class methods, ivars, and protocols.
    private func performDeepSearch(
        query: String,
        existingMatches: [TypeIdentifier]
    ) async -> [TypeIdentifier] {
        let existingIds = Set(existingMatches.map(\.id))
        var allResults = existingMatches
        
        if let cachedMatches = deepSearchResultsCache[query] {
            let deepMatches = cachedMatches
                .map { TypeIdentifier.className($0) }
                .filter { !existingIds.contains($0.id) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            allResults.append(contentsOf: deepMatches)
            return allResults
        }
        
        var deepMatchSet: Set<String> = []
        var deepMatches: [TypeIdentifier] = []
        
        for className in classNames {
            guard !Task.isCancelled else { return allResults }
            
            let id = TypeIdentifier.className(className)
            
            guard !existingIds.contains(id) else { continue }
            
            let content = await searchableContent(for: className)
            
            if matchesDeepSearch(content: content, query: query) {
                deepMatchSet.insert(className)
                deepMatches.append(id)
            }
        }
        
        deepSearchResultsCache[query] = deepMatchSet
        
        deepMatches.sort { 
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending 
        }
        allResults.append(contentsOf: deepMatches)
        
        return allResults
    }
    
    // MARK: - Content Loading
    
    /// Gets or creates searchable content for a class.
    private func searchableContent(for className: String) async -> SearchableContent {
        if let cached = searchableContentCache[className] {
            return cached
        }
        
        guard let objcClass = await repository.objcClass(named: className) else {
            let empty = SearchableContent(
                ivarNames: [],
                methodParts: [],
                protocolNames: []
            )
            searchableContentCache[className] = empty
            return empty
        }
        
        let info = ObjCClassInfo(objcClass)
        
        let ivarNames = info.ivars.map { $0.name.lowercased() }
        
        let protocolNames = info.protocols.map { $0.name.lowercased() }
        
        // Extract method name parts (split on colons for selector components).
        var methodParts: Set<String> = []
        for method in info.classMethods + info.methods {
            let parts = method.name
                .components(separatedBy: ":")
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
            methodParts.formUnion(parts)
        }
        
        let content = SearchableContent(
            ivarNames: ivarNames,
            methodParts: Array(methodParts),
            protocolNames: protocolNames
        )
        
        searchableContentCache[className] = content
        return content
    }
    
    // MARK: - Matching Logic
    
    /// Checks if searchable content matches the query for deep search.
    private func matchesDeepSearch(content: SearchableContent, query: String) -> Bool {
        if content.ivarNames.contains(where: { $0.contains(query) }) {
            return true
        }
        
        if content.methodParts.contains(where: { $0.contains(query) }) {
            return true
        }
        
        if content.protocolNames.contains(where: { $0.contains(query) }) {
            return true
        }
        
        return false
    }
}

// MARK: - Supporting Types

/// Represents searchable content extracted from a class for deep searching.
private struct SearchableContent: Sendable {
    let ivarNames: [String]
    let methodParts: [String]
    let protocolNames: [String]
}

