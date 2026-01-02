//
//  HistoryView.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.history.isEmpty {
                    Section {
                        Text("No actions to undo")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    Section("Recent Actions") {
                        ForEach(Array(viewModel.history.enumerated().reversed()), id: \.offset) { index, entry in
                            HStack {
                                Image(systemName: entry.action == .addMarkedArea ? "plus.circle.fill" : "minus.circle.fill")
                                    .foregroundColor(entry.action == .addMarkedArea ? .green : .red)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.action == .addMarkedArea ? "Marked Area Added" : "Marked Area Removed")
                                        .font(.headline)
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Undo") {
                        viewModel.undo()
                    }
                    .disabled(!viewModel.canUndo)
                }
            }
        }
    }
}

