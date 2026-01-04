import SwiftUI

/// Bottom info bar displaying image metadata
struct InfoBar: View {
    let text: String
    
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Spacer()
        }
        .frame(height: 32)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.95)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .top
        )
    }
}

#Preview {
    InfoBar(text: "image.jpg  •  1920×1080  •  2.4 MB  •  100%")
}

