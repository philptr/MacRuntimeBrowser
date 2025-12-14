//
//  RuntimeRepository.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import Foundation
import ObjCDump

/// Actor responsible for managing ObjC runtime access and caching.
actor RuntimeRepository {
    
    // MARK: - Stored Data
    
    private var classDetailCache: [String: RuntimeClassDetail] = [:]
    private var protocolDetailCache: [String: RuntimeProtocolDetail] = [:]
    
    private var objcClassesByName: [String: AnyClass] = [:]
    private var objcProtocolsByName: [String: Protocol] = [:]
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Loading Runtime
    
    /// Loads the ObjC runtime and returns grouped frameworks with lightweight items.
    func loadRuntime() -> RuntimeData {
        let classes = Self.loadObjCClassList()
        var classesByImage: [String: [String]] = [:]
        var loadedObjcClasses: [String: AnyClass] = [:]
        var allClassNames: [String] = []
        
        for cls in classes {
            let name = NSStringFromClass(cls)
            allClassNames.append(name)
            loadedObjcClasses[name] = cls
            
            if let imageName = class_getImageName(cls) {
                let imagePath = String(cString: imageName)
                classesByImage[imagePath, default: []].append(name)
            }
        }
        
        let protocols = Self.loadObjCProtocolList()
        var loadedObjcProtocols: [String: Protocol] = [:]
        var allProtocolNames: [String] = []
        
        for proto in protocols {
            let name = NSStringFromProtocol(proto)
            allProtocolNames.append(name)
            loadedObjcProtocols[name] = proto
        }
        
        self.objcClassesByName = loadedObjcClasses
        self.objcProtocolsByName = loadedObjcProtocols
        
        var frameworkGroups: [String: FrameworkGroup] = [:]
        
        for (imagePath, classNames) in classesByImage {
            let sortedClassItems = classNames
                .sorted { $0.lowercased() < $1.lowercased() }
                .map { TypeIdentifier.className($0) }
            
            let displayName = (imagePath as NSString).lastPathComponent
            frameworkGroups[imagePath] = FrameworkGroup(
                id: imagePath,
                path: imagePath,
                displayName: displayName,
                classes: sortedClassItems,
                protocols: []
            )
        }
        
        // Add protocols to a virtual "Protocols" group.
        if !allProtocolNames.isEmpty {
            let protocolItems = allProtocolNames
                .sorted { $0.lowercased() < $1.lowercased() }
                .map { TypeIdentifier.protocolName($0) }
            
            frameworkGroups["__protocols__"] = FrameworkGroup(
                id: "__protocols__",
                path: "__protocols__",
                displayName: "All Protocols",
                classes: [],
                protocols: protocolItems
            )
        }
        
        let sortedFrameworks = frameworkGroups.values.sorted { f1, f2 in
            if f1.id == "__protocols__" { return false }
            if f2.id == "__protocols__" { return true }
            return f1.displayName.lowercased() < f2.displayName.lowercased()
        }
        
        return RuntimeData(
            frameworks: sortedFrameworks,
            classNames: allClassNames,
            protocolNames: allProtocolNames
        )
    }
    
    /// Clears all caches, called during runtime reload.
    func clearCaches() {
        classDetailCache.removeAll()
        protocolDetailCache.removeAll()
        objcClassesByName.removeAll()
        objcProtocolsByName.removeAll()
    }
    
    // MARK: - Detail Object Access
    
    /// Gets or creates a RuntimeClassDetail for the given class name.
    func classDetail(named name: String) -> RuntimeClassDetail? {
        if let cached = classDetailCache[name] {
            return cached
        }
        
        guard let objcClass = objcClassesByName[name] else {
            return nil
        }
        
        let detail = RuntimeClassDetail(objcClass: objcClass)
        classDetailCache[name] = detail
        return detail
    }
    
    /// Gets or creates a RuntimeProtocolDetail for the given protocol name.
    func protocolDetail(named name: String) -> RuntimeProtocolDetail? {
        if let cached = protocolDetailCache[name] {
            return cached
        }
        
        guard let objcProtocol = objcProtocolsByName[name] else {
            return nil
        }
        
        let detail = RuntimeProtocolDetail(objcProtocol: objcProtocol)
        protocolDetailCache[name] = detail
        return detail
    }
    
    /// Returns the header string for a given runtime item.
    func headerString(for item: TypeIdentifier) -> String? {
        if item.isProtocol {
            return protocolDetail(named: item.name)?.headerString
        } else {
            return classDetail(named: item.name)?.headerString
        }
    }
    
    /// Checks if a class exists in the runtime.
    func classExists(named name: String) -> Bool {
        objcClassesByName[name] != nil
    }
    
    /// Gets all class names for search.
    func allClassNames() -> [String] {
        Array(objcClassesByName.keys)
    }
    
    /// Gets all protocol names for search.
    func allProtocolNames() -> [String] {
        Array(objcProtocolsByName.keys)
    }
    
    /// Gets the underlying ObjC class for deep search.
    func objcClass(named name: String) -> AnyClass? {
        objcClassesByName[name]
    }
    
    // MARK: - Export
    
    /// Exports all headers to the given directory.
    func exportAllHeaders(to directory: URL) async -> ExportResult {
        var saved = 0
        var failed = 0
        
        for objcClass in objcClassesByName {
            let name = objcClass.key
            let detail = RuntimeClassDetail(objcClass: objcClass.value)
            let content = detail.headerString
            
            let fileURL = directory.appendingPathComponent("\(name).h")
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                saved += 1
            } catch {
                failed += 1
            }
        }
        
        return ExportResult(saved: saved, failed: failed)
    }
    
    // MARK: - Private Helpers
    
    private static func loadObjCClassList() -> [AnyClass] {
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else {
            return []
        }
        defer { free(UnsafeMutableRawPointer(mutating: classList)) }
        
        let classListPtr = UnsafePointer<AnyClass>(classList)
        return (0..<Int(count)).map { classListPtr[$0] }
    }
    
    private static func loadObjCProtocolList() -> [Protocol] {
        var count: UInt32 = 0
        guard let protocolList = objc_copyProtocolList(&count) else {
            return []
        }
        defer { free(UnsafeMutableRawPointer(mutating: protocolList)) }
        
        let protocolListPtr = UnsafePointer<Protocol>(protocolList)
        return (0..<Int(count)).map { protocolListPtr[$0] }
    }
}

// MARK: - Supporting Types

struct RuntimeData: Sendable {
    let frameworks: [FrameworkGroup]
    let classNames: [String]
    let protocolNames: [String]
}

struct ExportResult: Sendable {
    let saved: Int
    let failed: Int
}

