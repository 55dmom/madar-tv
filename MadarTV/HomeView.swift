import SwiftUI

struct HeroBanner: View {
    let items: [MediaItem]
    @State private var index = 0
    @EnvironmentObject var player: PlayerCoordinator
    @EnvironmentObject var favorites: FavoritesStore
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                ZStack(alignment: .bottomLeading) {
                    PosterImage(url: item.thumbURL, title: item.title)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .blur(radius: 0.5)
                    LinearGradient(colors: [.clear, Theme.bg.opacity(0.6), Theme.bg], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.genre ?? "").font(.caption.bold()).foregroundColor(Theme.accent)
                        Text(item.displayTitle).font(.system(size: 28, weight: .heavy)).foregroundColor(.white).lineLimit(2)
                        Text(item.metaLine).font(.footnote).foregroundColor(Theme.text2)
                        HStack(spacing: 10) {
                            Button { player.play(item: item) } label: {
                                Label("شاهد الآن", systemImage: "play.fill")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(Theme.accent).foregroundColor(.black).cornerRadius(10)
                            }
                            NavigationLink(destination: DetailView(item: item)) {
                                Label("التفاصيل", systemImage: "info.circle")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(Color.white.opacity(0.14)).foregroundColor(.white).cornerRadius(10)
                            }
                            Button { favorites.toggle(item) } label: {
                                Image(systemName: favorites.isFavorite(item) ? "heart.fill" : "heart")
                                    .font(.headline).foregroundColor(favorites.isFavorite(item) ? Theme.accent2 : .white)
                                    .frame(width: 40, height: 40).background(Color.white.opacity(0.14)).cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 18)
                }
                .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 300)
        .onReceive(timer) { _ in
            guard !items.isEmpty else { return }
            withAnimation { index = (index + 1) % items.count }
        }
    }
}

struct MediaRow: View {
    let title: String
    let items: [MediaItem]
    var subtitle: String? = nil
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: title, subtitle: subtitle)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(items) { item in
                            NavigationLink(destination: DetailView(item: item)) { PosterCard(item: item) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ChannelRow: View {
    let title: String
    let channels: [Channel]
    @EnvironmentObject var player: PlayerCoordinator
    var body: some View {
        if !channels.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: title, subtitle: "\(channels.count) قناة")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(channels.prefix(30)) { c in
                            Button { player.play(channel: c) } label: { ChannelCard(channel: c, width: 110) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct HomeView: View {
    var selectTab: (AppTab) -> Void
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var playlists: PlaylistStore
    @EnvironmentObject var favorites: FavoritesStore

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HeroBanner(items: catalog.featured)
                    CategoryChips(selectTab: selectTab)
                    if !favorites.items.isEmpty { MediaRow(title: "قائمتي", items: favorites.items) }
                    MediaRow(title: "أفلام Blender المفتوحة", items: catalog.openMovies, subtitle: "HD")
                    MediaRow(title: "كلاسيكيات السينما", items: Array(catalog.movies.prefix(15)))
                    MediaRow(title: "مسلسلات", items: catalog.series)
                    MediaRow(title: "كرتون كلاسيكي", items: catalog.cartoons)
                    ChannelRow(title: "قنوات عربية مباشرة", channels: playlists.arabic)
                    MediaRow(title: "رعب وغموض", items: catalog.movies.filter { ["رعب", "غموض", "تشويق"].contains($0.genre ?? "") })
                    MediaRow(title: "كوميديا", items: catalog.movies.filter { $0.genre == "كوميدي" })
                    MediaRow(title: "مغامرة وخيال علمي", items: catalog.movies.filter { ["مغامرة", "خيال علمي"].contains($0.genre ?? "") })
                    Text("المحتوى: أرشيف الإنترنت (ملكية عامة) • Blender Foundation (CC) • iptv-org")
                        .font(.caption2).foregroundColor(Theme.text2).padding(.horizontal).padding(.bottom, 20)
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .mainToolbar()
        }
        .navigationViewStyle(.stack)
    }
}

struct CategoryChips: View {
    var selectTab: (AppTab) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip("أفلام", "film", .movies)
                chip("مسلسلات", "tv", .series)
                chip("أنمي وكرتون", "sparkles", .anime)
                chip("قنوات مباشرة", "dot.radiowaves.left.and.right", .live)
                chip("المفضلة", "heart", .favorites)
            }
            .padding(.horizontal)
        }
    }
    func chip(_ t: String, _ icon: String, _ tab: AppTab) -> some View {
        Button { selectTab(tab) } label: {
            Label(t, systemImage: icon)
                .font(.footnote.bold())
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Theme.surface2)
                .foregroundColor(.white)
                .cornerRadius(20)
        }
    }
}
