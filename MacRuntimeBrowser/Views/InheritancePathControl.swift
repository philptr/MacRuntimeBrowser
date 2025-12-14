//
//  InheritancePathControl.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct InheritancePathControl: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    let inheritanceChain: [TypeIdentifier]
    let currentItem: TypeIdentifier
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                Button {
                    viewModel.navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canNavigateBack)
                .foregroundStyle(viewModel.canNavigateBack ? .secondary : .quaternary)
                .help("Go Back")
                
                Button {
                    viewModel.navigateForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canNavigateForward)
                .foregroundStyle(viewModel.canNavigateForward ? .secondary : .quaternary)
                .help("Go Forward")
            }
            .padding(.leading, 8)
            
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(inheritanceChain.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Button {
                            viewModel.selectItem(item)
                        } label: {
                            Text(item.name)
                                .font(.system(.caption, design: .monospaced))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(item == currentItem ? .primary : .secondary)
                    }
                }
                .padding(.trailing)
                .padding(.vertical, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
