import SwiftUI

struct MediaGrid: View {
    let items: [MediaItem]
    let columns = [GridItem(.adaptive(minimum: 105, maximum: 140), spacing: 12)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                NavigationLink(destination: DetailView(item: item)) { PosterCard(item: item, width: 105) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

struct GenreFilter: View {
    let genres: [String]
    @Binding var selected: String?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill("الكل", selected == nil) { selected = nil }
                ForEach(genres, id: \.self) { g in pill(g, selected == g) { selected = g } }
            }
            .padding(.horizontal)
        }
    }
    func pill(_ t: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.footnote.bold())
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(on ? Theme.accent : Theme.surface2)
                .foregroundColor(on ? .black : .white)
                .cornerRadius(18)
        }
    }
}

struct MoviesView: View {
    @EnvironmentObject var catalog: CatalogStore
    @State private var genre: String? = nil

    var filtered: [MediaItem] {
        let all = catalog.openMovies + catalog.movies
        guard let g = genre else { return all }
        return all.filter { $0.genre == g }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GenreFilter(genres: catalog.genres(in: catalog.openMovies + catalog.movies), selected: $genre)
                        .padding(.top, 8)
                    MediaGrid(items: filtered)
                    if genre == nil {
                        SectionHeader(title: "المزيد من أرشيف الإنترنت", subtitle: catalog.archiveMore.isEmpty ? nil : "\(catalog.archiveMore.count)")
                        MediaGrid(items: catalog.archiveMore)
                        Button {
                            Task { await catalog.loadMoreFromArchive() }
                        } label: {
                            HStack {
                                if catalog.archiveLoading { ProgressView().tint(.black) }
                                Text(catalog.archiveMore.isEmpty ? "استكشف أفلاماً أكثر" : "تحميل المزيد")
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.accent).foregroundColor(.black).cornerRadius(12)
                        }
                        .padding(.horizontal).padding(.bottom, 20)
                    }
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("أفلام")
            .navigationBarTitleDisplayMode(.inline)
            .mainToolbar()
        }
        .navigationViewStyle(.stack)
    }
}

struct SeriesView: View {
    @EnvironmentObject var catalog: CatalogStore
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(catalog.series) { s in
                        NavigationLink(destination: DetailView(item: s)) { WideSeriesCard(item: s) }
                            .buttonStyle(.plain)
                    }
                    SectionHeader(title: "كل المسلسلات")
                    MediaGrid(items: catalog.series + catalog.cartoons)
                }
                .padding(.vertical)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("مسلسلات")
            .navigationBarTitleDisplayMode(.inline)
            .mainToolbar()
        }
        .navigationViewStyle(.stack)
    }
}

struct WideSeriesCard: View {
    let item: MediaItem
    var body: some View {
        HStack(spacing: 14) {
            PosterImage(url: item.thumbURL, title: item.title)
                .frame(width: 90, height: 130).cornerRadius(10)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle).font(.headline).foregroundColor(.white)
                Text(item.title).font(.caption).foregroundColor(Theme.text2).lineLimit(1)
                Text(item.metaLine).font(.caption).foregroundColor(Theme.accent)
                Text("\((item.episodes ?? []).count) حلقة • ملكية عامة").font(.caption2).foregroundColor(Theme.text2)
                Spacer(minLength: 0)
                HStack {
                    Image(systemName: "play.circle.fill").foregroundColor(Theme.accent)
                    Text("ابدأ المشاهدة").font(.caption.bold()).foregroundColor(.white)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.surface)
        .cornerRadius(14)
        .padding(.horizontal)
    }
}

struct AnimeView: View {
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var playlists: PlaylistStore
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MediaRow(title: "أفلام أنمي وأنيميشن قصيرة", items: catalog.openMovies, subtitle: "Blender")
                    MediaRow(title: "كرتون كلاسيكي", items: catalog.cartoons)
                    ChannelRow(title: "قنوات أنيميشن مباشرة", channels: playlists.animation)
                    ChannelRow(title: "قنوات أطفال مباشرة", channels: playlists.kids)
                    if playlists.animation.isEmpty && playlists.kids.isEmpty {
                        if playlists.loading.isEmpty {
                            EmptyStateView(icon: "sparkles.tv", title: "قنوات الأنيميشن", message: "اسحب للتحديث لتحميل قنوات الأنيميشن والأطفال المجانية")
                        } else {
                            ProgressView("جاري تحميل القنوات…").frame(maxWidth: .infinity).padding()
                        }
                    }
                    SectionHeader(title: "كل الحلقات والأفلام")
                    MediaGrid(items: catalog.cartoons + catalog.openMovies)
                }
                .padding(.vertical)
            }
            .refreshable { await playlists.loadAnime() }
            .task { if playlists.animation.isEmpty { await playlists.loadAnime() } }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("أنمي")
            .navigationBarTitleDisplayMode(.inline)
            .mainToolbar()
        }
        .navigationViewStyle(.stack)
    }
}

struct FavoritesView: View {
    @EnvironmentObject var favorites: FavoritesStore
    @EnvironmentObject var player: PlayerCoordinator
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if favorites.items.isEmpty && favorites.channels.isEmpty {
                        EmptyStateView(icon: "heart", title: "لا توجد مفضلات بعد", message: "اضغط على ♥ في أي فيلم أو مسلسل أو قناة لإضافته هنا")
                            .padding(.top, 60)
                    }
                    if !favorites.items.isEmpty {
                        SectionHeader(title: "أفلام ومسلسلات")
                        MediaGrid(items: favorites.items)
                    }
                    if !favorites.channels.isEmpty {
                        SectionHeader(title: "قنوات")
                        ChannelGrid(channels: favorites.channels)
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("المفضلة")
            .navigationBarTitleDisplayMode(.inline)
            .mainToolbar()
        }
        .navigationViewStyle(.stack)
    }
}

struct SearchView: View {
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var playlists: PlaylistStore
    @State private var query = ""

    var mediaResults: [MediaItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return catalog.all.filter { item in
            if item.title.lowercased().contains(q) { return true }
            if let s = item.subtitle, s.lowercased().contains(q) { return true }
            if let g = item.genre, g.contains(q) { return true }
            return false
        }
    }
    var channelResults: [Channel] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let all = playlists.arabic + playlists.animation + playlists.kids + playlists.custom
        var seen = Set<String>()
        var out: [Channel] = []
        for c in all {
            let hit: Bool = c.name.lowercased().contains(q) || c.group.lowercased().contains(q)
            if hit && !seen.contains(c.id) {
                seen.insert(c.id)
                out.append(c)
            }
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if query.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: "ابحث في مَدار", message: "أفلام، مسلسلات، كرتون، وقنوات مباشرة")
                        .padding(.top, 40)
                } else if mediaResults.isEmpty && channelResults.isEmpty {
                    EmptyStateView(icon: "questionmark.circle", title: "لا توجد نتائج", message: "جرّب كلمة أخرى")
                        .padding(.top, 40)
                }
                if !mediaResults.isEmpty {
                    SectionHeader(title: "أفلام ومسلسلات", subtitle: "\(mediaResults.count)")
                    MediaGrid(items: mediaResults)
                }
                if !channelResults.isEmpty {
                    SectionHeader(title: "قنوات", subtitle: "\(channelResults.count)")
                    ChannelGrid(channels: Array(channelResults.prefix(60)))
                }
            }
            .padding(.vertical)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("بحث")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث عن فيلم أو قناة")
    }
}
