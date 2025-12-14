//
//  RuntimeStore.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main observable store managing runtime data, search, and navigation state.
@MainActor
@Observable
final class RuntimeStore {
    
    // MARK: - Services
    
    private let repository = RuntimeRepository()
    private let searchService: SearchService
    
    // MARK: - Search State
    
    var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            performSearchIfNeeded()
        }
    }
    
    var typeFilter: TypeFilter = .all {
        didSet {
            guard typeFilter != oldValue && isSearching else { return }
            performSearchIfNeeded()
        }
    }
    
    var viewMode: ViewMode = .byFramework
    
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private(set) var searchPhase: SearchPhase = .idle
    private(set) var searchResults: [TypeIdentifier] = [] {
        didSet {
            // Invalidate cached grouped results when search results change
            cachedSearchResultsByFramework = nil
        }
    }
    private var currentSearchTask: Task<Void, Never>?
    
    var searchStatusText: String {
        switch searchPhase {
        case .idle, .complete:
            ""
        case .searchingNames:
            "Searching names…"
        case .searchingDeep:
            "Searching methods & ivars…"
        }
    }
    
    // MARK: - Selection State
    
    var selectedItem: TypeIdentifier? {
        didSet {
            guard selectedItem != oldValue else { return }
            handleSelectionChange()
        }
    }
    
    private(set) var selectedHeaderContent: String?
    private(set) var selectedItemName: String?
    private(set) var selectedInheritanceChain: [TypeIdentifier]?
    
    private var currentDetailTask: Task<Void, Never>?
    
    // MARK: - Navigation Path
    
    private var navigationPath = NavigationPath()
    private var isNavigatingHistory = false
    
    // MARK: - Runtime Data
    
    private(set) var frameworks: [FrameworkGroup] = [] {
        didSet {
            // Rebuild lookup when frameworks change
            itemToFrameworkLookup = buildItemToFrameworkLookup()
            // Invalidate cached grouped results
            cachedSearchResultsByFramework = nil
        }
    }
    
    // MARK: - Cached Computations
    
    /// Cached lookup from TypeIdentifier to framework ID
    private var itemToFrameworkLookup: [TypeIdentifier: String] = [:]
    
    /// Cached grouped search results, invalidated when searchResults changes
    private var cachedSearchResultsByFramework: [FrameworkGroup]?
    
    // MARK: - Initialization
    
    init() {
        self.searchService = SearchService(repository: repository)
        Task {
            await loadRuntime()
        }
    }
    
    // MARK: - Computed Properties
    
    var filteredFrameworks: [FrameworkGroup] {
        frameworks.filter { framework in
            let hasClasses = typeFilter.showsClasses && !framework.classes.isEmpty
            let hasProtocols = typeFilter.showsProtocols && !framework.protocols.isEmpty
            return hasClasses || hasProtocols
        }
    }
    
    /// Returns frameworks to display based on current state (searching or not)
    var displayFrameworks: [FrameworkGroup] {
        if isSearching {
            return searchResultsByFramework
        } else {
            return filteredFrameworks
        }
    }
    
    /// Returns items to display in flat list mode based on current state (searching or not)
    var displayItems: [TypeIdentifier] {
        if isSearching {
            return searchResults
        } else {
            return allItemsFlat
        }
    }
    
    /// Groups search results by their framework (cached)
    private var searchResultsByFramework: [FrameworkGroup] {
        if let cached = cachedSearchResultsByFramework {
            return cached
        }
        
        guard !searchResults.isEmpty else {
            cachedSearchResultsByFramework = []
            return []
        }
        
        var frameworkMap: [String: [TypeIdentifier]] = [:]
        
        for result in searchResults {
            let frameworkId = itemToFrameworkLookup[result] ?? "__unknown__"
            frameworkMap[frameworkId, default: []].append(result)
        }
        
        let grouped = frameworkMap.compactMap { (frameworkId, items) -> FrameworkGroup? in
            guard let framework = frameworks.first(where: { $0.id == frameworkId }) else {
                // For unknown frameworks, create a minimal framework group
                if frameworkId == "__unknown__" {
                    return FrameworkGroup(
                        id: "__unknown__",
                        path: "__unknown__",
                        displayName: "Unknown",
                        classes: items.filter { !$0.isProtocol },
                        protocols: items.filter { $0.isProtocol }
                    )
                }
                return nil
            }
            
            // Filter items to only those in search results
            let classes = items.filter { !$0.isProtocol }
            let protocols = items.filter { $0.isProtocol }
            
            return FrameworkGroup(
                id: framework.id,
                path: framework.path,
                displayName: framework.displayName,
                classes: classes,
                protocols: protocols
            )
        }.sorted { f1, f2 in
            if f1.id == "__protocols__" { return false }
            if f2.id == "__protocols__" { return true }
            if f1.id == "__unknown__" { return false }
            if f2.id == "__unknown__" { return true }
            return f1.displayName.lowercased() < f2.displayName.lowercased()
        }
        
        cachedSearchResultsByFramework = grouped
        return grouped
    }
    
    /// Builds the lookup dictionary from TypeIdentifier to framework ID
    private func buildItemToFrameworkLookup() -> [TypeIdentifier: String] {
        var lookup: [TypeIdentifier: String] = [:]
        for framework in frameworks {
            for item in framework.classes {
                lookup[item] = framework.id
            }
            for item in framework.protocols {
                lookup[item] = framework.id
            }
        }
        return lookup
    }
    
    /// Returns all items (classes and protocols) as a flat list, filtered by typeFilter
    private var allItemsFlat: [TypeIdentifier] {
        var items: [TypeIdentifier] = []
        for framework in filteredFrameworks {
            items.append(contentsOf: framework.filteredItems(
                showClasses: typeFilter.showsClasses,
                showProtocols: typeFilter.showsProtocols
            ))
        }
        return items.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    // MARK: - Selection Handling
    
    private func handleSelectionChange() {
        guard let item = selectedItem else {
            clearSelection()
            return
        }
        
        // Update navigation path (unless navigating through history)
        if !isNavigatingHistory {
            navigationPath.navigate(to: item, isNavigatingHistory: false)
        }
        
        // Load details for the selected item
        loadSelectedItemDetails(item)
    }
    
    private func clearSelection() {
        currentDetailTask?.cancel()
        currentDetailTask = nil
        
        selectedHeaderContent = nil
        selectedItemName = nil
        selectedInheritanceChain = nil
    }
    
    private func loadSelectedItemDetails(_ item: TypeIdentifier) {
        // Cancel any existing detail loading task
        currentDetailTask?.cancel()
        
        currentDetailTask = Task {
            let detail: (headerString: String, name: String, inheritanceChain: [TypeIdentifier]?)
            
            switch item {
            case .className(let name):
                guard let classDetail = await repository.classDetail(named: name) else {
                    return
                }
                detail = (
                    headerString: classDetail.headerString,
                    name: classDetail.name,
                    inheritanceChain: classDetail.inheritanceChain.map { .className($0) }
                )
                
            case .protocolName(let name):
                guard let protocolDetail = await repository.protocolDetail(named: name) else {
                    return
                }
                detail = (
                    headerString: protocolDetail.headerString,
                    name: protocolDetail.name,
                    inheritanceChain: nil
                )
            }
            
            // Only update if task hasn't been cancelled and item is still selected
            guard !Task.isCancelled, selectedItem == item else { return }
            
            selectedHeaderContent = detail.headerString
            selectedItemName = detail.name
            selectedInheritanceChain = detail.inheritanceChain
        }
    }
    
    // MARK: - Selection & Navigation
    
    func selectItem(_ item: TypeIdentifier?) {
        selectedItem = item
    }
    
    func navigate(to item: TypeIdentifier) {
        selectedItem = item
    }
    
    func navigateToClass(named className: String) async {
        let exists = await repository.classExists(named: className)
        if exists {
            selectedItem = .className(className)
        }
    }
    
    // MARK: - History Navigation
    
    var canNavigateBack: Bool {
        navigationPath.canNavigateBack
    }
    
    var canNavigateForward: Bool {
        navigationPath.canNavigateForward
    }
    
    func navigateBack() {
        guard !isNavigatingHistory else { return }
        
        isNavigatingHistory = true
        defer { isNavigatingHistory = false }
        
        if let item = navigationPath.navigateBack() {
            selectedItem = item
        }
    }
    
    func navigateForward() {
        guard !isNavigatingHistory else { return }
        
        isNavigatingHistory = true
        defer { isNavigatingHistory = false }
        
        if let item = navigationPath.navigateForward() {
            selectedItem = item
        }
    }
    
    // MARK: - Search
    
    private func performSearchIfNeeded() {
        // Cancel any existing search
        currentSearchTask?.cancel()
        currentSearchTask = nil
        
        let query = searchText.trimmingCharacters(in: .whitespaces)
        
        // Clear results if empty query
        guard !query.isEmpty else {
            searchResults = []
            searchPhase = .idle
            return
        }
        
        let showClasses = typeFilter.showsClasses
        let showProtocols = typeFilter.showsProtocols
        
        // Update phase to searching immediately
        searchPhase = .searchingNames
        
        // Start new search task
        currentSearchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Capture the query at task start to validate updates
            let searchQuery = query
            
            // Perform search with incremental updates
            await searchService.search(
                query: searchQuery,
                showClasses: showClasses,
                showProtocols: showProtocols
            ) { @MainActor update in
                // Only update if this is still the current search query
                guard !Task.isCancelled,
                      self.currentSearchTask?.isCancelled != true,
                      self.searchText.trimmingCharacters(in: .whitespaces) == searchQuery else {
                    return
                }
                
                self.searchResults = update.results
                self.searchPhase = update.phase
            }
        }
    }
    
    // MARK: - Runtime Loading
    
    private func loadRuntime() async {
        let data = await repository.loadRuntime()
        
        // Setting frameworks will automatically rebuild the lookup via didSet
        frameworks = data.frameworks
        
        // Update search service with runtime data
        await searchService.updateSearchData(
            classNames: data.classNames,
            protocolNames: data.protocolNames
        )
        
        // If there's an active search, re-trigger it
        if isSearching {
            performSearchIfNeeded()
        }
    }
    
    func reloadRuntime() {
        // Cancel any in-flight operations
        currentSearchTask?.cancel()
        currentSearchTask = nil
        currentDetailTask?.cancel()
        currentDetailTask = nil
        
        // Clear all UI state immediately
        // Setting frameworks to [] will clear the lookup via didSet
        frameworks = []
        isNavigatingHistory = true // Prevent adding nil to history
        selectedItem = nil
        isNavigatingHistory = false
        navigationPath.clear()
        searchResults = [] // This will clear cachedSearchResultsByFramework via didSet
        searchPhase = .idle
        searchText = "" // Clear search text to prevent stale search
        clearSelection()
        
        // Clear all caches in services and reload runtime
        Task {
            await repository.clearCaches()
            await searchService.clearCaches()
            await loadRuntime()
        }
    }
    
    // MARK: - Bundle Loading
    
    func loadBundles(_ urls: [URL]) {
        var loadedAny = false
        
        for url in urls {
            guard let bundle = Bundle(url: url) else { continue }
            
            do {
                try bundle.loadAndReturnError()
                loadedAny = true
            } catch {
                print("Failed to load bundle at \(url): \(error)")
            }
        }
        
        if loadedAny {
            reloadRuntime()
        }
    }
    
    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .init(filenameExtension: "framework")!,
            .init(filenameExtension: "bundle")!,
            .init(filenameExtension: "dylib")!,
            .init(filenameExtension: "app")!
        ]
        
        if panel.runModal() == .OK {
            loadBundles(panel.urls)
        }
    }
    
    // MARK: - Save/Export
    
    func saveCurrentHeader() {
        guard let content = selectedHeaderContent,
              let name = selectedItemName else { return }
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(name).h"
        panel.allowedContentTypes = [.cHeader]
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save header: \(error)")
            }
        }
    }
    
    func exportAllHeaders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose a folder to export all headers"
        panel.prompt = "Export"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                let result = await repository.exportAllHeaders(to: url)
                
                let alert = NSAlert()
                alert.messageText = "Export Complete"
                alert.informativeText = "Saved \(result.saved) headers. \(result.failed > 0 ? "\(result.failed) failed." : "")"
                alert.runModal()
            }
        }
    }
}
