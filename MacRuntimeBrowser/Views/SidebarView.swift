//
//  SidebarView.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct SidebarView: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    
    var body: some View {
        if viewModel.frameworks.isEmpty {
            ProgressView("Loading runtime…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            SidebarListView()
        }
    }
}
