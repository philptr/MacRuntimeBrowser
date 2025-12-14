//
//  RuntimeProtocolDetail.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import Foundation
import ObjCDump

/// Immutable representation of a runtime protocol with all its details.
struct RuntimeProtocolDetail: Identifiable, Sendable {
    let id: TypeIdentifier
    let name: String
    let headerString: String
    
    init(objcProtocol: Protocol) {
        let protocolName = NSStringFromProtocol(objcProtocol)
        self.id = .protocolName(protocolName)
        self.name = protocolName
        let info = ObjCProtocolInfo(objcProtocol)
        self.headerString = info.headerString
    }
}

