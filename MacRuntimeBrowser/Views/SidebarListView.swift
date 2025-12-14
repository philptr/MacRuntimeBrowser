//
//  SidebarListView.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct SidebarListView: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    
    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            switch viewModel.viewMode {
            case .byFramework:
                List(selection: $viewModel.selectedItem) {
                    ForEach(viewModel.displayFrameworks) { framework in
                        FrameworkDisclosureGroup(framework: framework)
                    }
                }
            case .flatList:
                List(selection: $viewModel.selectedItem) {
                    ForEach(viewModel.displayItems) { item in
                        ItemRow(item: item)
                    }
                }
            }
            
            if viewModel.isSearching {
                SearchResultsFooterView()
            }
        }
        .listStyle(.inset)
        .listRowSeparator(.hidden)
        .scrollContentBackground(.hidden)
    }
}

