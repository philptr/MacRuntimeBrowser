//
//  SearchPhase.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import Foundation

enum SearchPhase: Equatable, Sendable {
    case idle
    case searchingNames
    case searchingDeep
    case complete
}
