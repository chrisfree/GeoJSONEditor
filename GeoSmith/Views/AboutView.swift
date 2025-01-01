import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 64))
            
            Text("GeoSmith")
                .font(.title)
            
            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("A modern GeoJSON editor for macOS")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.5)
                .frame(minWidth: 200)
            
        }
        .padding(40)
        .frame(width: 300, height: 250)
    }
}

#Preview {
    AboutView()
}
