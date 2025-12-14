//
//  SearchUpdate.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import Foundation

struct SearchUpdate: Sendable {
    let results: [TypeIdentifier]
    let phase: SearchPhase
}
