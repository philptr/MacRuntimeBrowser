//
//  NavigationPath.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import Foundation

/// A stack-based navigation path representing the navigation history.
struct NavigationPath: Sendable {
    private(set) var items: [TypeIdentifier] = []
    private(set) var currentIndex: Int = -1
    
    /// Whether we can navigate back.
    var canNavigateBack: Bool {
        currentIndex > 0
    }
    
    /// Whether we can navigate forward.
    var canNavigateForward: Bool {
        currentIndex < items.count - 1
    }
    
    /// The current item in the path.
    var currentItem: TypeIdentifier? {
        guard currentIndex >= 0 && currentIndex < items.count else {
            return nil
        }
        return items[currentIndex]
    }
    
    /// Navigates to a new item by pushing it onto the path.
    mutating func navigate(to item: TypeIdentifier, isNavigatingHistory: Bool = false) {
        // Don't push if we're navigating through history.
        guard !isNavigatingHistory else { return }
        
        // If we're not at the end, truncate forward history.
        if currentIndex < items.count - 1 {
            items = Array(items.prefix(currentIndex + 1))
        }
        
        // Don't add duplicate consecutive entries.
        if items.last != item {
            items.append(item)
            currentIndex = items.count - 1
            
            // Limit history size.
            let maxHistorySize = 50
            if items.count > maxHistorySize {
                items.removeFirst(items.count - maxHistorySize)
                currentIndex = items.count - 1
            }
        }
    }
    
    /// Navigates back in the path.
    mutating func navigateBack() -> TypeIdentifier? {
        guard canNavigateBack else { return nil }
        currentIndex -= 1
        return currentItem
    }
    
    /// Navigates forward in the path.
    mutating func navigateForward() -> TypeIdentifier? {
        guard canNavigateForward else { return nil }
        currentIndex += 1
        return currentItem
    }
    
    /// Clears the entire path.
    mutating func clear() {
        items = []
        currentIndex = -1
    }
}
