//
//  FilterPopoverButton.swift
//  MacRuntimeBrowser
//
//  Created by Phil Zakharchenko on 12/13/25.
//

import SwiftUI

struct FilterPopoverButton: View {
    @Environment(RuntimeViewModel.self) private var viewModel
    @State private var showPopover = false
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        Button {
            showPopover.toggle()
        } label: {
            Label("Filter", systemImage: viewModel.typeFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .help("Filter types")
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Show Types")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Picker("Filter", selection: $viewModel.typeFilter) {
                    Text("All").tag(TypeFilter.all)
                    Text("Classes Only").tag(TypeFilter.classesOnly)
                    Text("Protocols Only").tag(TypeFilter.protocolsOnly)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .padding()
            .frame(width: 180)
        }
    }
}
