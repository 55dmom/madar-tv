import SwiftUI

enum AppTab: Int, CaseIterable {
    case home, movies, series, anime, live, favorites
    var title: String {
        switch self {
        case .home: return "الرئيسية"
        case .movies: return "أفلام"
        case .series: return "مسلسلات"
        case .anime: return "أنمي"
        case .live: return "مباشر"
        case .favorites: return "المفضلة"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .movies: return "film.fill"
        case .series: return "tv.fill"
        case .anime: return "sparkles.tv.fill"
        case .live: return "antenna.radiowaves.left.and.right"
        case .favorites: return "heart.fill"
        }
    }
}

struct RootView: View {
    @State private var tab: AppTab = {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startTab"), i + 1 < args.count, let n = Int(args[i + 1]), let t = AppTab(rawValue: n) { return t }
        return .home
    }()
    @EnvironmentObject var player: PlayerCoordinator
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var playlists: PlaylistStore
    @EnvironmentObject var favorites: FavoritesStore
    @EnvironmentObject var downloads: DownloadManager

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()
            Group {
                switch tab {
                case .home: HomeView(selectTab: { tab = $0 })
                case .movies: MoviesView()
                case .series: SeriesView()
                case .anime: AnimeView()
                case .live: LiveChannelsView()
                case .favorites: FavoritesView()
                }
            }
            .padding(.bottom, 58)
            TabBar(selected: $tab)
            if player.resolving {
                ProgressView("جاري التحضير…").padding().background(.ultraThinMaterial).cornerRadius(12)
                    .frame(maxHeight: .infinity)
            }
        }
        .fullScreenCover(item: $player.current) { req in
            PlayerScreen(request: req)
                .environmentObject(downloads)
        }
    }
}

struct TabBar: View {
    @Binding var selected: AppTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon).font(.system(size: 18, weight: .semibold))
                        Text(t.title).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(selected == t ? Theme.accent : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            Theme.surface
                .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}


/// Shared toolbar: search, browser, downloads, settings
struct MainToolbarModifier: ViewModifier {
    @State private var goSearch = false
    @State private var goBrowser = false
    @State private var goDownloads = false
    @State private var goSettings = false

    func body(content: Content) -> some View {
        content
            .background(
                VStack {
                    NavigationLink(destination: SearchView(), isActive: $goSearch) { EmptyView() }
                    NavigationLink(destination: BrowserView(), isActive: $goBrowser) { EmptyView() }
                    NavigationLink(destination: DownloadsView(), isActive: $goDownloads) { EmptyView() }
                    NavigationLink(destination: SettingsView(), isActive: $goSettings) { EmptyView() }
                }
                .hidden()
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { BrandTitle() }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { goSearch = true } label: { Image(systemName: "magnifyingglass") }
                    Menu {
                        Button { goBrowser = true } label: { Label("المتصفح", systemImage: "safari") }
                        Button { goDownloads = true } label: { Label("التحميلات", systemImage: "arrow.down.circle") }
                        Button { goSettings = true } label: { Label("الإعدادات", systemImage: "gearshape") }
                    } label: { Image(systemName: "line.3.horizontal") }
                }
            }
    }
}

extension View {
    func mainToolbar() -> some View { modifier(MainToolbarModifier()) }
}

struct BrandTitle: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.circle").foregroundColor(Theme.accent).font(.system(size: 16, weight: .bold))
            Text("مَدار").font(.system(size: 20, weight: .heavy)).foregroundColor(.white)
            Text("TV").font(.system(size: 12, weight: .black)).foregroundColor(.black)
                .padding(.horizontal, 5).padding(.vertical, 1).background(Theme.accent).cornerRadius(4)
        }
    }
}
