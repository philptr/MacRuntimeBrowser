//
//  SearchResultsFooterView.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct SearchResultsFooterView: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            SearchStatusView()
            SearchResultCount()
        }
        .controlSize(.mini)
        .font(.caption)
        .foregroundStyle(.tertiary)
        .transition(.blurReplace)
        .contentTransition(.interpolate)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .overlay(alignment: .top) {
            Divider()
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SearchStatusView: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            ProgressView()
            
            Text(viewModel.searchStatusText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SearchResultCount: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    
    var body: some View {
        Text("result".pluralized(viewModel.searchResults.count))
            .monospacedDigit()
    }
}

private extension String {
    func pluralized(_ count: Int) -> String {
        let localizationValue: String.LocalizationValue = "^[\(count) \(self)](inflect: true)"
        return String(AttributedString(localized: localizationValue).characters)
    }
}
