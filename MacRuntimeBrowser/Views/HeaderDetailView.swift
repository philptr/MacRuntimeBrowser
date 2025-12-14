//
//  HeaderDetailView.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI
import HighlightSwift

struct HeaderDetailView: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    
    var body: some View {
        if let details = viewModel.selectedItemDetails {
            VStack(spacing: 0) {
                if let inheritanceChain = details.inheritanceChain,
                   let currentItem = viewModel.selectedItem {
                    InheritancePathControl(
                        inheritanceChain: inheritanceChain,
                        currentItem: currentItem
                    )
                }
                
                SourceCodeText(code: details.headerContent, language: .objectiveC)
            }
            .navigationTitle("\(details.name).h")
            .toolbar {
                ToolbarItem {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(details.headerContent, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .help("Copy header to clipboard")
                }
                
                ToolbarItem {
                    Button {
                        viewModel.saveCurrentHeader()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .help("Save header file")
                }
            }
        } else {
            ContentUnavailableView {
                Label("No Selection", systemImage: "doc.text")
            } description: {
                Text("Select a class or protocol to view its generated header")
            }
        }
    }
}
