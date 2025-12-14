//
//  ContentView.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI
import UniformTypeIdentifiers
import HighlightSwift

struct ContentView: View {
    @State private var viewModel = RuntimeViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            HeaderDetailView()
                .id(viewModel.selectedItem)
        }
        .searchable(text: $viewModel.searchText, placement: .sidebar, prompt: "Search…")
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ViewModePicker()
            }
            
            ToolbarItemGroup(placement: .automatic) {
                FilterPopoverButton()
                
                Button {
                    viewModel.reloadRuntime()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.frameworks.isEmpty)
                .help("Reload all runtime classes")
            }
            
            ToolbarItem {
                Spacer()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .environment(viewModel)
        .focusedSceneValue(viewModel)
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let validExtensions = ["framework", "bundle", "dylib", "app"]
            let validURLs = urls.filter { url in
                validExtensions.contains(url.pathExtension.lowercased())
            }
            if !validURLs.isEmpty {
                viewModel.loadBundles(validURLs)
            }
        }
        
        return true
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
}
