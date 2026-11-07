import SwiftUI

struct ChannelCard: View {
    let channel: Channel
    var width: CGFloat = 105
    @EnvironmentObject var favorites: FavoritesStore
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.surface2)
                if let u = channel.logoURL {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit().padding(14)
                        default:
                            Image(systemName: "tv").font(.title2).foregroundColor(Theme.text2)
                        }
                    }
                } else {
                    Text(String(channel.name.prefix(2))).font(.title2.bold()).foregroundColor(Theme.accent)
                }
            }
            .frame(width: width, height: width * 0.68)
            .overlay(alignment: .topLeading) {
                Circle().fill(Theme.accent2).frame(width: 7, height: 7).padding(7)
            }
            .overlay(alignment: .topTrailing) {
                if favorites.isFavorite(channel) { Image(systemName: "heart.fill").font(.caption2).foregroundColor(Theme.accent2).padding(6) }
            }
            Text(channel.name).font(.system(size: 11, weight: .semibold)).foregroundColor(.white).lineLimit(1)
        }
        .frame(width: width)
        .contextMenu {
            Button { favorites.toggle(channel) } label: {
                Label(favorites.isFavorite(channel) ? "إزالة من المفضلة" : "أضف للمفضلة", systemImage: "heart")
            }
            Button { UIPasteboard.general.string = channel.url } label: { Label("نسخ الرابط", systemImage: "doc.on.doc") }
        }
    }
}

struct ChannelGrid: View {
    let channels: [Channel]
    @EnvironmentObject var player: PlayerCoordinator
    let columns = [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(channels) { c in
                Button { player.play(channel: c) } label: { ChannelCard(channel: c, width: 100) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

struct LiveChannelsView: View {
    enum Source: String, CaseIterable { case arabic = "القنوات العربية", custom = "قائمتي", test = "بث تجريبي" }
    @EnvironmentObject var playlists: PlaylistStore
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var player: PlayerCoordinator
    @State private var source: Source = .arabic
    @State private var filter = ""
    @State private var group: String? = nil

    var list: [Channel] {
        let base: [Channel]
        switch source {
        case .arabic: base = playlists.arabic
        case .custom: base = playlists.custom
        case .test: base = catalog.testStreams.compactMap { s in s.stream.map { Channel(name: s.title, url: $0, group: "تجريبي") } }
        }
        let f = filter.trimmingCharacters(in: .whitespaces).lowercased()
        return base.filter { (group == nil || $0.group == group) && (f.isEmpty || $0.name.lowercased().contains(f)) }
    }

    var groups: [String] {
        let base = source == .arabic ? playlists.arabic : (source == .custom ? playlists.custom : [])
        return playlists.groups(base).map { $0.0 }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("", selection: $source) {
                        ForEach(Source.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: source) { _ in group = nil }

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(Theme.text2)
                        TextField("ابحث عن قناة", text: $filter).foregroundColor(.white)
                    }
                    .padding(10).background(Theme.surface).cornerRadius(10).padding(.horizontal)

                    if groups.count > 1 { GenreFilter(genres: groups, selected: $group) }

                    if source == .arabic && playlists.arabic.isEmpty {
                        VStack(spacing: 14) {
                            EmptyStateView(icon: "antenna.radiowaves.left.and.right", title: "القنوات العربية المجانية", message: "قائمة عامة من مشروع iptv-org لقنوات البث المجاني (Free-to-Air).")
                            Button { Task { await playlists.loadArabic() } } label: {
                                HStack {
                                    if playlists.loading.contains(PlaylistStore.arabicPreset) { ProgressView().tint(.black) }
                                    Text("تحميل القنوات العربية المجانية")
                                }
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Theme.accent).foregroundColor(.black).cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    } else if source == .custom && playlists.custom.isEmpty {
                        VStack(spacing: 14) {
                            EmptyStateView(icon: "list.bullet.rectangle", title: "لا توجد قائمة تشغيل", message: "أضف رابط قائمة التشغيل الخاصة بك (M3U أو HLS) من الإعدادات.")
                            NavigationLink(destination: SettingsView()) {
                                Text("فتح الإعدادات").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Theme.accent).foregroundColor(.black).cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Text("\(list.count) قناة").font(.caption).foregroundColor(Theme.text2).padding(.horizontal)
                        ChannelGrid(channels: list)
                    }
                    if let e = playlists.lastError {
                        Text(e).font(.caption).foregroundColor(Theme.accent2).padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                switch source {
                case .arabic: await playlists.loadArabic()
                case .custom: await playlists.loadCustom()
                case .test: break
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("قنوات مباشرة")
            .navigationBarTitleDisplayMode(.inline)
            .mainToolbar()
        }
        .navigationViewStyle(.stack)
    }
}
