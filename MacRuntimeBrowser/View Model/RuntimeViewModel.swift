//
//  RuntimeViewModel.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Root view model managing runtime data, search, navigation, and selection state.
@MainActor
@Observable
final class RuntimeViewModel {
    
    // MARK: - Dependencies
    
    private let repository = RuntimeRepository()
    private let searchService: SearchService
    
    // MARK: - Runtime Data
    
    private(set) var frameworks: [FrameworkGroup] = [] {
        didSet {
            itemToFrameworkLookup = buildItemToFrameworkLookup()
            invalidateSearchCache()
        }
    }
    
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
            invalidateSearchCache()
        }
    }
    
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
    
    private(set) var selectedItemDetails: SelectedItemDetails?
    
    // MARK: - Navigation State
    
    private var navigationPath = NavigationPath()
    private var isNavigatingHistory = false
    
    var canNavigateBack: Bool {
        navigationPath.canNavigateBack
    }
    
    var canNavigateForward: Bool {
        navigationPath.canNavigateForward
    }
    
    // MARK: - Cached Computations
    
    private var itemToFrameworkLookup: [TypeIdentifier: String] = [:]
    private var cachedSearchResultsByFramework: [FrameworkGroup]?
    
    // MARK: - Task Management
    
    private var currentSearchTask: Task<Void, Never>?
    private var currentDetailTask: Task<Void, Never>?
    
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
    
    var displayFrameworks: [FrameworkGroup] {
        isSearching ? searchResultsByFramework : filteredFrameworks
    }
    
    var displayItems: [TypeIdentifier] {
        isSearching ? searchResults : allItemsFlat
    }
    
    // MARK: - Selection & Navigation
    
    func selectItem(_ item: TypeIdentifier?) {
        selectedItem = item
    }
    
    func navigateToClass(named className: String) async {
        let exists = await repository.classExists(named: className)
        if exists {
            selectedItem = .className(className)
        }
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
    
    // MARK: - Runtime Loading
    
    func reloadRuntime() {
        cancelAllTasks()
        clearState()
        
        Task {
            await repository.clearCaches()
            await searchService.clearCaches()
            await loadRuntime()
        }
    }
    
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
        guard let details = selectedItemDetails else { return }
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(details.name).h"
        panel.allowedContentTypes = [.cHeader]
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try details.headerContent.write(to: url, atomically: true, encoding: .utf8)
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
    
    // MARK: - Private Helpers
    
    private func loadRuntime() async {
        let data = await repository.loadRuntime()
        
        frameworks = data.frameworks
        
        await searchService.updateSearchData(
            classNames: data.classNames,
            protocolNames: data.protocolNames
        )
        
        if isSearching {
            performSearchIfNeeded()
        }
    }
    
    private func handleSelectionChange() {
        guard let item = selectedItem else {
            clearSelection()
            return
        }
        
        if !isNavigatingHistory {
            navigationPath.navigate(to: item, isNavigatingHistory: false)
        }
        
        loadItemDetails(for: item)
    }
    
    private func clearSelection() {
        currentDetailTask?.cancel()
        currentDetailTask = nil
        selectedItemDetails = nil
    }
    
    private func loadItemDetails(for item: TypeIdentifier) {
        currentDetailTask?.cancel()
        
        currentDetailTask = Task {
            let details: SelectedItemDetails?
            
            switch item {
            case .className(let name):
                guard let classDetail = await repository.classDetail(named: name) else {
                    return
                }
                details = SelectedItemDetails(
                    name: classDetail.name,
                    headerContent: classDetail.headerString,
                    inheritanceChain: classDetail.inheritanceChain.map { .className($0) }
                )
                
            case .protocolName(let name):
                guard let protocolDetail = await repository.protocolDetail(named: name) else {
                    return
                }
                details = SelectedItemDetails(
                    name: protocolDetail.name,
                    headerContent: protocolDetail.headerString,
                    inheritanceChain: nil
                )
            }
            
            guard !Task.isCancelled, selectedItem == item else { return }
            
            selectedItemDetails = details
        }
    }
    
    private func performSearchIfNeeded() {
        currentSearchTask?.cancel()
        
        let query = searchText.trimmingCharacters(in: .whitespaces)
        
        guard !query.isEmpty else {
            searchResults = []
            searchPhase = .idle
            return
        }
        
        searchPhase = .searchingNames
        
        currentSearchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            let searchQuery = query
            let showClasses = typeFilter.showsClasses
            let showProtocols = typeFilter.showsProtocols
            
            await searchService.search(
                query: searchQuery,
                showClasses: showClasses,
                showProtocols: showProtocols
            ) { @MainActor update in
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
    
    private func invalidateSearchCache() {
        cachedSearchResultsByFramework = nil
    }
    
    private func cancelAllTasks() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
        currentDetailTask?.cancel()
        currentDetailTask = nil
    }
    
    private func clearState() {
        frameworks = []
        isNavigatingHistory = true
        selectedItem = nil
        isNavigatingHistory = false
        navigationPath.clear()
        searchResults = []
        searchPhase = .idle
        searchText = ""
        clearSelection()
    }
}

// MARK: - Supporting Types

/// Consolidated details for a selected runtime item.
struct SelectedItemDetails: Sendable {
    let name: String
    let headerContent: String
    let inheritanceChain: [TypeIdentifier]?
}
