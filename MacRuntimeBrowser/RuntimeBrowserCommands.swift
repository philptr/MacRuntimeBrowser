//
//  RuntimeBrowserCommands.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct RuntimeBrowserCommands: Commands {
    @FocusedValue(RuntimeViewModel.self) private var viewModel: RuntimeViewModel?
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Bundle…", systemImage: "folder.badge.plus") {
                viewModel?.showOpenPanel()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(viewModel == nil)
        }
        
        CommandGroup(after: .saveItem) {
            Divider()
            
            Button("Save Header…", systemImage: "square.and.arrow.down") {
                viewModel?.saveCurrentHeader()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(viewModel?.selectedItemDetails == nil)
            
            Button("Export All Headers…", systemImage: "square.and.arrow.down.on.square") {
                viewModel?.exportAllHeaders()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(viewModel == nil)
        }
        
        CommandGroup(after: .undoRedo) {
            Divider()
            
            Button("Go Back", systemImage: "chevron.left") {
                viewModel?.navigateBack()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(viewModel?.canNavigateBack != true)
            
            Button("Go Forward", systemImage: "chevron.right") {
                viewModel?.navigateForward()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(viewModel?.canNavigateForward != true)
        }
        
        CommandGroup(after: .toolbar) {
            Button("Reload Runtime", systemImage: "arrow.clockwise") {
                viewModel?.reloadRuntime()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(viewModel == nil)
            
            Divider()
            
            Button("By Framework", systemImage: "folder") {
                viewModel?.viewMode = .byFramework
            }
            .keyboardShortcut("1", modifiers: [.command, .control])
            .disabled(viewModel == nil)
            
            Button("Flat List", systemImage: "list.bullet") {
                viewModel?.viewMode = .flatList
            }
            .keyboardShortcut("2", modifiers: [.command, .control])
            .disabled(viewModel == nil)
            
            Divider()
            
            Menu("Filter") {
                Button("All", systemImage: "square.grid.2x2") {
                    viewModel?.typeFilter = .all
                }
                .keyboardShortcut("a", modifiers: [.command, .control])
                .disabled(viewModel == nil)
                
                Button("Classes Only", systemImage: "cube") {
                    viewModel?.typeFilter = .classesOnly
                }
                .keyboardShortcut("c", modifiers: [.command, .control])
                .disabled(viewModel == nil)
                
                Button("Protocols Only", systemImage: "doc.text") {
                    viewModel?.typeFilter = .protocolsOnly
                }
                .keyboardShortcut("p", modifiers: [.command, .control])
                .disabled(viewModel == nil)
            }
        }
        
        TextEditingCommands()
    }
}
