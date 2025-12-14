//
//  FrameworkDisclosureGroup.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct FrameworkDisclosureGroup: View {
    let framework: FrameworkGroup
    
    @State private var isExpanded: Bool = false
    @Environment(RuntimeViewModel.self) private var viewModel
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(framework.filteredItems(showClasses: viewModel.typeFilter.showsClasses, showProtocols: viewModel.typeFilter.showsProtocols)) { item in
                ItemRow(item: item)
            }
        } label: {
            HStack {
                Image(nsImage: framework.icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(framework.displayName)
                    
                    Text(framework.countDescription(showClasses: viewModel.typeFilter.showsClasses, showProtocols: viewModel.typeFilter.showsProtocols))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture {
                withAnimation(.snappy) {
                    isExpanded.toggle()
                }
            }
        }
    }
}
