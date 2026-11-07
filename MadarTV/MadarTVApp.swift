import SwiftUI
import AVFoundation

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        return true
    }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }
}

@main
struct MadarTVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var catalog = CatalogStore()
    @StateObject private var playlists = PlaylistStore()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var player = PlayerCoordinator()
    @ObservedObject private var downloads = DownloadManager.shared

    init() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Theme.bg)
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(Theme.accent)
        UITableView.appearance().backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(catalog)
                .environmentObject(playlists)
                .environmentObject(favorites)
                .environmentObject(player)
                .environmentObject(downloads)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
        }
    }
}
