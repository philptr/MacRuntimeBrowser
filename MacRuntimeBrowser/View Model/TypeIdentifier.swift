//
//  TypeItem.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import Foundation

enum TypeIdentifier: Hashable, Sendable, Identifiable {
    case className(String)
    case protocolName(String)
    
    var id: Self { self }
    
    /// The display name for this item.
    var name: String {
        switch self {
        case .className(let name), .protocolName(let name):
            return name
        }
    }
    
    /// Whether this item represents a protocol.
    var isProtocol: Bool {
        if case .protocolName = self {
            return true
        }
        return false
    }
}
