//
//  RadarSizePickerView.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import SwiftUI

struct RadarSizePickerView: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    @State private var customRadius: String = ""
    @State private var showCustomInput = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(RadarSize.allCases.filter { $0 != .custom }) { size in
                    Button(action: {
                        viewModel.createRadarPin(size: size)
                        dismiss()
                    }) {
                        HStack {
                            Text(size.displayName)
                            Spacer()
                        }
                    }
                }
                
                Button(action: {
                    showCustomInput = true
                }) {
                    HStack {
                        Text("Custom")
                        Spacer()
                        if showCustomInput {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if showCustomInput {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter radius in miles:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., 2.5", text: $customRadius)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Create Radar") {
                            if let radius = Double(customRadius) {
                                let radiusInMeters = radius * 1609.34 // Convert miles to meters
                                viewModel.createRadarPin(size: .custom, customRadius: radiusInMeters)
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(customRadius.isEmpty || Double(customRadius) == nil)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Select Radar Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        viewModel.pendingRadarLocation = nil
                        dismiss()
                    }
                }
            }
        }
    }
}

