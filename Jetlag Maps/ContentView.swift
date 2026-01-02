//
//  ContentView.swift
//  Jetlag Maps
//
//  Created by Kevin Keen on 02/01/2026.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var showRegionPicker = false
    @State private var showRegionChangeWarning = false
    
    var body: some View {
        ZStack {
            // Map View
            MapView(viewModel: viewModel)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top region selector
                HStack {
                    Button(action: {
                        if viewModel.hasActiveSession {
                            showRegionChangeWarning = true
                        } else {
                            showRegionPicker = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.hasActiveSession {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            Image(systemName: "map")
                                .font(.subheadline)
                            Text(viewModel.regionName)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 8)
                
                Spacer()
                
                // Bottom toolbar
                VStack(spacing: 8) {
                    // Lasso tool doesn't need size selector
                    if false {
                        HStack(spacing: 12) {
                            Text("Size:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(PenSize.allCases, id: \.self) { size in
                                Button(action: {
                                    viewModel.penSize = size
                                }) {
                                    Circle()
                                        .fill(viewModel.penSize == size ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: size == .small ? 12 : size == .medium ? 16 : 20,
                                               height: size == .small ? 12 : size == .medium ? 16 : 20)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // History/Undo button
                            Button(action: {
                                viewModel.showHistory = true
                            }) {
                                VStack(spacing: 3) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.title3)
                                    Text("History")
                                        .font(.caption2)
                                }
                                .frame(width: 60, height: 60)
                                .background(viewModel.canUndo ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .foregroundColor(viewModel.canUndo ? .blue : .gray)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(viewModel.canUndo ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            .disabled(!viewModel.canUndo)
                            
                            // Tool buttons
                            ForEach(MapTool.allCases.filter { $0 != .none }, id: \.self) { tool in
                                ToolButton(
                                    tool: tool,
                                    isSelected: viewModel.selectedTool == tool
                                ) {
                                    if viewModel.selectedTool == tool {
                                        viewModel.selectedTool = .none
                                    } else {
                                        viewModel.selectedTool = tool
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 10)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showRegionPicker) {
            RegionPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showHistory) {
            HistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showRadarSizePicker) {
            RadarSizePickerView(viewModel: viewModel)
        }
        .alert("Radar Result", isPresented: $viewModel.showHitMissDialog) {
            Button("Hit") {
                if let pin = viewModel.selectedRadarPin {
                    viewModel.handleRadarHitMiss(pin: pin, isHit: true)
                }
            }
            Button("Miss") {
                if let pin = viewModel.selectedRadarPin {
                    viewModel.handleRadarHitMiss(pin: pin, isHit: false)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.selectedRadarPin = nil
            }
        } message: {
            if let pin = viewModel.selectedRadarPin {
                Text("Was the radar a hit or miss?")
            }
        }
        .alert("End Current Session?", isPresented: $showRegionChangeWarning) {
            Button("Cancel", role: .cancel) { }
            Button("End Session", role: .destructive) {
                viewModel.clearSession()
                showRegionPicker = true
            }
        } message: {
            Text("Changing the play region will end your current session and erase all saved game data (crossed off areas, etc.). This action cannot be undone.")
        }
    }
}

struct ToolButton: View {
    let tool: MapTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tool.icon)
                    .font(.title3)
                Text(tool.rawValue)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 60, height: 60)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct RegionPickerView: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var allCountries: [CountryData] = []
    @State private var showRegionChangeWarning = false
    @State private var pendingCountryName: String?
    var onRegionSelected: (() -> Void)?
    
    var filteredCountries: [CountryData] {
        if searchText.isEmpty {
            return allCountries
        } else {
            return allCountries.filter { country in
                country.name.localizedCaseInsensitiveContains(searchText) ||
                (country.iso3?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (country.iso3166_1_alpha_2_codes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search countries...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                List {
                    if !viewModel.commonRegions.isEmpty {
                        Section("Quick Select") {
                    ForEach(viewModel.commonRegions, id: \.name) { region in
                        Button(action: {
                            if viewModel.hasActiveSession && viewModel.regionName != region.name {
                                pendingCountryName = region.name
                                showRegionChangeWarning = true
                            } else {
                                viewModel.selectCountry(byName: region.name)
                                dismiss()
                            }
                        }) {
                                    HStack {
                                        Text(region.name)
                                        Spacer()
                                        if viewModel.regionName == region.name {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if searchText.isEmpty {
                        Section("All Countries") {
                            ForEach(allCountries.prefix(50), id: \.name) { country in
                                CountryRow(country: country, viewModel: viewModel, dismiss: dismiss, showWarning: $showRegionChangeWarning, pendingCountry: $pendingCountryName)
                            }
                            
                            if allCountries.count > 50 {
                                Text("\(allCountries.count - 50) more countries. Search to find them.")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    } else {
                        Section("Search Results") {
                            if filteredCountries.isEmpty {
                                Text("No countries found")
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(filteredCountries, id: \.name) { country in
                                    CountryRow(country: country, viewModel: viewModel, dismiss: dismiss, showWarning: $showRegionChangeWarning, pendingCountry: $pendingCountryName)
                                }
                            }
                        }
                    }
                    
                    Section("Custom Region") {
                        Button(action: {
                            // Placeholder for custom region selection
                            // This could open a map to let user draw a region
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Select Custom Region")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Play Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCountries()
            }
            .alert("End Current Session?", isPresented: $showRegionChangeWarning) {
                Button("Cancel", role: .cancel) {
                    pendingCountryName = nil
                }
                Button("End Session", role: .destructive) {
                    if let countryName = pendingCountryName {
                        viewModel.clearSession()
                        viewModel.selectCountry(byName: countryName)
                        pendingCountryName = nil
                        dismiss()
                    }
                }
            } message: {
                Text("Changing the play region will end your current session and erase all saved game data (crossed off areas, etc.). This action cannot be undone.")
            }
        }
    }
    
    private func loadCountries() {
        allCountries = CountryBoundaryLoader.loadCountries().sorted { $0.name < $1.name }
    }
}

struct CountryRow: View {
    let country: CountryData
    @ObservedObject var viewModel: MapViewModel
    let dismiss: DismissAction
    @Binding var showWarning: Bool
    @Binding var pendingCountry: String?
    
    var body: some View {
        Button(action: {
            if viewModel.hasActiveSession && viewModel.regionName != country.name {
                pendingCountry = country.name
                showWarning = true
            } else {
                viewModel.selectCountry(byName: country.name)
                dismiss()
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name)
                        .foregroundColor(.primary)
                    if let iso2 = country.iso3166_1_alpha_2_codes, let iso3 = country.iso3 {
                        Text("\(iso2) • \(iso3)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if let iso2 = country.iso3166_1_alpha_2_codes {
                        Text(iso2)
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if let iso3 = country.iso3 {
                        Text(iso3)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                if viewModel.regionName == country.name {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
