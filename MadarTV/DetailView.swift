import SwiftUI

struct DetailView: View {
    let item: MediaItem
    @EnvironmentObject var player: PlayerCoordinator
    @EnvironmentObject var favorites: FavoritesStore
    @EnvironmentObject var downloads: DownloadManager
    @EnvironmentObject var catalog: CatalogStore

    var related: [MediaItem] {
        let pool: [MediaItem]
        switch item.kind {
        case .series: pool = catalog.series
        case .cartoon: pool = catalog.cartoons
        default: pool = catalog.movies + catalog.openMovies
        }
        let same = pool.filter { $0.id != item.id && $0.genre == item.genre }
        return Array((same.isEmpty ? pool.filter { $0.id != item.id } : same).prefix(12))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottom) {
                    PosterImage(url: item.thumbURL, title: item.title)
                        .frame(height: 260).frame(maxWidth: .infinity)
                        .blur(radius: 18).opacity(0.7)
                    LinearGradient(colors: [.clear, Theme.bg], startPoint: .center, endPoint: .bottom)
                    HStack(alignment: .bottom, spacing: 14) {
                        PosterImage(url: item.thumbURL, title: item.title)
                            .frame(width: 120, height: 174).cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.displayTitle).font(.system(size: 22, weight: .heavy)).foregroundColor(.white).lineLimit(3)
                            if item.subtitle != nil { Text(item.title).font(.caption).foregroundColor(Theme.text2) }
                            Text(item.metaLine).font(.footnote).foregroundColor(Theme.accent)
                            if let s = item.source { Text(s).font(.caption2).foregroundColor(Theme.text2) }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .frame(height: 260)

                HStack(spacing: 10) {
                    Button {
                        if let first = item.episodes?.first, let u = URL(string: first.stream) { player.play(u, title: "\(item.displayTitle) • \(first.title)") }
                        else { player.play(item: item) }
                    } label: {
                        Label(item.isSeries ? "شاهد الحلقة الأولى" : "تشغيل", systemImage: "play.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.accent).foregroundColor(.black).cornerRadius(12)
                    }
                    Button { favorites.toggle(item) } label: {
                        Image(systemName: favorites.isFavorite(item) ? "heart.fill" : "heart")
                            .font(.headline).frame(width: 48, height: 46)
                            .background(Theme.surface2).foregroundColor(favorites.isFavorite(item) ? Theme.accent2 : .white).cornerRadius(12)
                    }
                    if let u = item.streamURL, DownloadManager.canDownload(u) {
                        Button { downloads.start(title: item.displayTitle, url: u) } label: {
                            Image(systemName: downloads.isDownloaded(u.absoluteString) ? "checkmark.circle.fill" : "arrow.down.to.line")
                                .font(.headline).frame(width: 48, height: 46)
                                .background(Theme.surface2).foregroundColor(.white).cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)

                Text(item.about).font(.subheadline).foregroundColor(Theme.text2).padding(.horizontal)

                if let eps = item.episodes, !eps.isEmpty {
                    SectionHeader(title: "الحلقات", subtitle: "\(eps.count)")
                    VStack(spacing: 8) {
                        ForEach(Array(eps.enumerated()), id: \.offset) { idx, ep in
                            EpisodeRow(index: idx + 1, episode: ep, seriesTitle: item.displayTitle, thumb: item.thumbURL)
                        }
                    }
                    .padding(.horizontal)
                }

                if !related.isEmpty {
                    MediaRow(title: "قد يعجبك أيضاً", items: related)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EpisodeRow: View {
    let index: Int
    let episode: Episode
    let seriesTitle: String
    let thumb: URL?
    @EnvironmentObject var player: PlayerCoordinator
    @EnvironmentObject var downloads: DownloadManager

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if let u = URL(string: episode.stream) { player.play(u, title: "\(seriesTitle) • \(episode.title)") }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        PosterImage(url: thumb, title: episode.title).frame(width: 96, height: 56).cornerRadius(8).opacity(0.8)
                        Image(systemName: "play.fill").foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("الحلقة \(index)").font(.caption.bold()).foregroundColor(Theme.accent)
                        Text(episode.title).font(.footnote).foregroundColor(.white).lineLimit(2).multilineTextAlignment(.leading)
                        if let m = episode.minutes { Text("\(m) دقيقة").font(.caption2).foregroundColor(Theme.text2) }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            if let u = URL(string: episode.stream), DownloadManager.canDownload(u) {
                Button { downloads.start(title: "\(seriesTitle) • \(episode.title)", url: u) } label: {
                    Image(systemName: downloads.isDownloaded(episode.stream) ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.title3).foregroundColor(downloads.isDownloaded(episode.stream) ? Theme.accent : .white)
                }
            }
        }
        .padding(10)
        .background(Theme.surface)
        .cornerRadius(12)
    }
}
