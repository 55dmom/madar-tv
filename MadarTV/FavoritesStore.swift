import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var channels: [Channel] = []

    init() {
        if let d = UserDefaults.standard.data(forKey: "fav_items"), let v = try? JSONDecoder().decode([MediaItem].self, from: d) { items = v }
        if let d = UserDefaults.standard.data(forKey: "fav_channels"), let v = try? JSONDecoder().decode([Channel].self, from: d) { channels = v }
    }
    func isFavorite(_ i: MediaItem) -> Bool { items.contains { $0.id == i.id } }
    func isFavorite(_ c: Channel) -> Bool { channels.contains { $0.id == c.id } }
    func toggle(_ i: MediaItem) {
        if isFavorite(i) { items.removeAll { $0.id == i.id } } else { items.insert(i, at: 0) }
        save()
    }
    func toggle(_ c: Channel) {
        if isFavorite(c) { channels.removeAll { $0.id == c.id } } else { channels.insert(c, at: 0) }
        save()
    }
    private func save() {
        if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: "fav_items") }
        if let d = try? JSONEncoder().encode(channels) { UserDefaults.standard.set(d, forKey: "fav_channels") }
    }
}
