import SwiftUI

enum Theme {
    static let bg = Color(red: 0.035, green: 0.039, blue: 0.067)
    static let surface = Color(red: 0.086, green: 0.094, blue: 0.137)
    static let surface2 = Color(red: 0.13, green: 0.14, blue: 0.20)
    static let accent = Color(red: 0.98, green: 0.73, blue: 0.16)
    static let accent2 = Color(red: 0.93, green: 0.27, blue: 0.24)
    static let text2 = Color.white.opacity(0.65)

    static let gradients: [[Color]] = [
        [Color(red: 0.55, green: 0.12, blue: 0.20), Color(red: 0.12, green: 0.05, blue: 0.20)],
        [Color(red: 0.10, green: 0.35, blue: 0.55), Color(red: 0.04, green: 0.08, blue: 0.20)],
        [Color(red: 0.60, green: 0.38, blue: 0.08), Color(red: 0.18, green: 0.08, blue: 0.04)],
        [Color(red: 0.15, green: 0.45, blue: 0.30), Color(red: 0.03, green: 0.12, blue: 0.10)],
        [Color(red: 0.40, green: 0.20, blue: 0.60), Color(red: 0.08, green: 0.05, blue: 0.18)],
    ]
    static func gradient(for key: String) -> LinearGradient {
        let stable = key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff } % gradients.count
        return LinearGradient(colors: gradients[stable], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct PosterImage: View {
    let url: URL?
    let title: String
    var contentMode: ContentMode = .fill

    var body: some View {
        ZStack {
            Theme.gradient(for: title)
            Text(String(title.prefix(1)).uppercased())
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.25))
            if let url = url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    default:
                        Color.clear
                    }
                }
            }
        }
        .clipped()
    }
}

struct PosterCard: View {
    let item: MediaItem
    var width: CGFloat = 120
    @EnvironmentObject var favorites: FavoritesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterImage(url: item.thumbURL, title: item.title)
                .frame(width: width, height: width * 1.45)
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if let g = item.badge {
                        Text(g)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Theme.accent)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .padding(6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if favorites.isFavorite(item) {
                        Image(systemName: "heart.fill").font(.caption)
                            .foregroundColor(Theme.accent2)
                            .padding(6)
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            Text(item.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(item.metaLine)
                .font(.system(size: 11))
                .foregroundColor(Theme.text2)
                .lineLimit(1)
        }
        .frame(width: width)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 4, height: 18)
            Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            if let s = subtitle { Text(s).font(.caption).foregroundColor(Theme.text2) }
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 44)).foregroundColor(Theme.accent)
            Text(title).font(.headline).foregroundColor(.white)
            Text(message).font(.subheadline).foregroundColor(Theme.text2).multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}
