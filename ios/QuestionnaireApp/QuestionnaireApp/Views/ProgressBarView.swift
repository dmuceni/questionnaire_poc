import SwiftUI

struct ProgressBarView: View {
    let percentage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(min(max(Double(percentage), 0), 100) / 100.0), height: 12)
                        .animation(.easeInOut, value: percentage)
                }
            }
            .frame(height: 12)

            Text("\(percentage)% completato")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct ProgressBarView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressBarView(percentage: 65)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
