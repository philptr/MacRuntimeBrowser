//
//  FrameworkGroup.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import AppKit
import UniformTypeIdentifiers

struct FrameworkGroup: Identifiable, Sendable {
    let id: String
    let path: String
    let displayName: String
    let classes: [TypeIdentifier]
    let protocols: [TypeIdentifier]
    
    var icon: NSImage {
        let extensions = [".app", ".framework", ".bundle", ".dylib"]
        for ext in extensions {
            if let range = path.range(of: ext) {
                let bundlePath = String(path[..<range.upperBound])
                return NSWorkspace.shared.icon(forFile: bundlePath)
            }
        }
        return NSWorkspace.shared.icon(for: .unixExecutable)
    }
    
    func filteredItems(showClasses: Bool, showProtocols: Bool) -> [TypeIdentifier] {
        var items: [TypeIdentifier] = []
        if showClasses { items.append(contentsOf: classes) }
        if showProtocols { items.append(contentsOf: protocols) }
        return items.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    func countDescription(showClasses: Bool, showProtocols: Bool) -> String {
        var parts: [String] = []
        if showClasses && !classes.isEmpty {
            parts.append("\(classes.count) classes")
        }
        if showProtocols && !protocols.isEmpty {
            parts.append("\(protocols.count) protocols")
        }
        return parts.joined(separator: ", ")
    }
    
    var totalCount: Int {
        classes.count + protocols.count
    }
}
