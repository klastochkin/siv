import SwiftUI

/// Info bar displayed at the bottom of the image view
struct InfoBar: View {
    let info: String
    
    var body: some View {
        HStack {
            Text(info)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .background(Color.black.opacity(0.7))
        .cornerRadius(6)
        .padding(8)
    }
}
