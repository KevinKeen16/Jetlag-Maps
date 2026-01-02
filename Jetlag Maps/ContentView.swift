import SwiftUI
import MapKit

struct ContentView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region)
                .ignoresSafeArea()

            // Bottom placeholder toolbar
            HStack(spacing: 16) {
                Button {
                    // Placeholder action
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                }
                .buttonStyle(.bordered)

                Button {
                    // Placeholder action
                } label: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title3)
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                Button {
                    // Recenter placeholder
                    region = region
                } label: {
                    Image(systemName: "location.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 16)
            .padding(.horizontal)
        }
    }
}

#Preview {
    ContentView()
}
