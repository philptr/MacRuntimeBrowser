//
//  UnifiedListView.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct UnifiedListView: View {
    @Environment(RuntimeStore.self) private var store
    
    var body: some View {
        @Bindable var store = store
        VStack {
            if store.viewMode == .byFramework {
                List(selection: $store.selectedItem) {
                    ForEach(store.displayFrameworks) { framework in
                        FrameworkDisclosureGroup(framework: framework)
                    }
                }
                .listStyle(.inset)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
            } else {
                List(selection: $store.selectedItem) {
                    ForEach(store.displayItems) { item in
                        ItemRow(item: item)
                            .tag(item.id)
                    }
                }
                .listStyle(.inset)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            SearchResultsFooterView()
        }
    }
}

