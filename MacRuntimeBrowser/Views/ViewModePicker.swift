//
//  ViewModePicker.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct ViewModePicker: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    
    var body: some View {
        @Bindable var viewModel = viewModel
        Picker("View Mode", selection: $viewModel.viewMode) {
            Label("By Framework", systemImage: "folder")
                .tag(ViewMode.byFramework)
            Label("Flat List", systemImage: "list.bullet")
                .tag(ViewMode.flatList)
        }
        .pickerStyle(.segmented)
        .help("Choose how to display items")
    }
}

