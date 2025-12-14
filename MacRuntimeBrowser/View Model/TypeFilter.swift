//
//  TypeFilter.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import Foundation

enum TypeFilter: Equatable, Sendable {
    case all
    case classesOnly
    case protocolsOnly
    
    var showsClasses: Bool {
        switch self {
        case .protocolsOnly: false
        default: true
        }
    }
    
    var showsProtocols: Bool {
        switch self {
        case .classesOnly: false
        default: true
        }
    }
}
