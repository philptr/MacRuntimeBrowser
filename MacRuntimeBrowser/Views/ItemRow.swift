//
//  ItemRow.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct ItemRow: View {
    let item: TypeIdentifier
    
    var body: some View {
        Label(item.name, systemImage: item.isProtocol ? "p.square" : "c.square")
            .accentColor(item.isProtocol ? .orange : .blue)
    }
}
