import Foundation
import SwiftUI

@MainActor
final class CatalogStore: ObservableObject {
    @Published var movies: [MediaItem] = []
    @Published var openMovies: [MediaItem] = []
    @Published var series: [MediaItem] = []
    @Published var cartoons: [MediaItem] = []
    @Published var testStreams: [MediaItem] = []
    @Published var archiveMore: [MediaItem] = []
    @Published var archiveLoading = false
    private var archivePage = 1

    init() { load() }

    func load() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(Catalog.self, from: data) else { return }
        movies = c.movies.map { var m = $0; m.kind = .movie; return m }
        openMovies = c.open_movies.map { var m = $0; m.kind = .openMovie; return m }
        series = c.series.map { var m = $0; m.kind = .series; return m }
        cartoons = c.cartoons.map { var m = $0; m.kind = .cartoon; return m }
        testStreams = c.test_streams
    }

    var featured: [MediaItem] {
        let pick = openMovies.prefix(4) + movies.filter { ["his_girl_friday", "lost_world", "gullivers_travels1939", "markofzorro-1920"].contains($0.id) }
        return Array(pick)
    }

    var all: [MediaItem] { movies + openMovies + series + cartoons + archiveMore }

    func genres(in items: [MediaItem]) -> [String] {
        var seen = Set<String>(); var out: [String] = []
        for i in items { if let g = i.genre, !seen.contains(g) { seen.insert(g); out.append(g) } }
        return out
    }

    func loadMoreFromArchive() async {
        guard !archiveLoading else { return }
        archiveLoading = true
        defer { archiveLoading = false }
        let items = await ArchiveService.search(page: archivePage)
        let known = Set(all.map { $0.id })
        archiveMore.append(contentsOf: items.filter { !known.contains($0.id) })
        archivePage += 1
    }
}

enum ArchiveService {
    static func search(page: Int) async -> [MediaItem] {
        var comps = URLComponents(string: "https://archive.org/advancedsearch.php")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: "collection:feature_films AND mediatype:movies AND year:[1920 TO 1970]"),
            URLQueryItem(name: "fl[]", value: "identifier"),
            URLQueryItem(name: "fl[]", value: "title"),
            URLQueryItem(name: "fl[]", value: "year"),
            URLQueryItem(name: "sort[]", value: "downloads desc"),
            URLQueryItem(name: "rows", value: "40"),
            URLQueryItem(name: "page", value: String(page + 1)),
            URLQueryItem(name: "output", value: "json"),
        ]
        guard let url = comps.url else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let resp = root["response"] as? [String: Any],
                  let docs = resp["docs"] as? [[String: Any]] else { return [] }
            return docs.compactMap { d in
                guard let id = d["identifier"] as? String else { return nil }
                let title = (d["title"] as? String) ?? id
                var year: Int? = nil
                if let y = d["year"] as? Int { year = y } else if let ys = d["year"] as? String { year = Int(ys.prefix(4)) }
                return MediaItem(id: id, title: title, year: year, genre: "كلاسيكي", thumb: "https://archive.org/services/img/\(id)", source: "أرشيف الإنترنت · ملكية عامة", kind: .archive)
            }
        } catch { return [] }
    }

    /// Finds a playable MP4 inside an archive.org item.
    static func resolveMP4(identifier: String) async -> URL? {
        guard let url = URL(string: "https://archive.org/metadata/\(identifier)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = root["files"] as? [[String: Any]] else { return nil }
            let mp4 = files.filter { (($0["name"] as? String) ?? "").lowercased().hasSuffix(".mp4") }
            func score(_ f: [String: Any]) -> Int {
                let fmt = ((f["format"] as? String) ?? "").lowercased()
                return (fmt.contains("h.264") ? 3 : 0) + (fmt.contains("512kb") ? 2 : 0)
            }
            guard let best = mp4.sorted(by: { score($0) > score($1) }).first,
                  let name = best["name"] as? String,
                  let enc = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
            return URL(string: "https://archive.org/download/\(identifier)/\(enc)")
        } catch { return nil }
    }
}
