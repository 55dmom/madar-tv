import Foundation
import SwiftUI

struct DownloadItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let remoteURL: String
    var fileName: String?
    var progress: Double = 0
    var state: State = .queued
    var bytes: Int64 = 0
    var taskID: Int? = nil

    enum State: String, Codable { case queued, downloading, done, failed }
}

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()
    @Published var items: [DownloadItem] = []
    var backgroundCompletionHandler: (() -> Void)?

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.background(withIdentifier: "com.madar.tv.downloads")
        cfg.isDiscretionary = false
        cfg.sessionSendsLaunchEvents = true
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static var indexURL: URL { folder.appendingPathComponent(".index.json") }

    override init() {
        super.init()
        if let d = try? Data(contentsOf: Self.indexURL), let v = try? JSONDecoder().decode([DownloadItem].self, from: d) {
            items = v.map { var i = $0; if i.state == .downloading || i.state == .queued { i.state = .failed }; return i }
        }
        _ = session
        session.getAllTasks { tasks in
            DispatchQueue.main.async {
                for t in tasks {
                    if let idx = self.items.firstIndex(where: { $0.taskID == t.taskIdentifier }) { self.items[idx].state = .downloading }
                }
            }
        }
    }

    static func canDownload(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return !["m3u8", "m3u", "mpd", "ts"].contains(ext) && (url.scheme == "http" || url.scheme == "https")
    }

    func isDownloaded(_ remote: String) -> Bool { items.contains { $0.remoteURL == remote && $0.state == .done } }
    func localURL(for remote: String) -> URL? {
        guard let i = items.first(where: { $0.remoteURL == remote && $0.state == .done }), let f = i.fileName else { return nil }
        return Self.folder.appendingPathComponent(f)
    }
    func localURL(_ item: DownloadItem) -> URL? { item.fileName.map { Self.folder.appendingPathComponent($0) } }

    func start(title: String, url: URL) {
        DispatchQueue.main.async {
            if let idx = self.items.firstIndex(where: { $0.remoteURL == url.absoluteString }) {
                if self.items[idx].state == .done || self.items[idx].state == .downloading { return }
                self.items.remove(at: idx)
            }
            let task = self.session.downloadTask(with: url)
            var item = DownloadItem(id: UUID().uuidString, title: title, remoteURL: url.absoluteString)
            item.taskID = task.taskIdentifier
            item.state = .downloading
            self.items.insert(item, at: 0)
            self.persist()
            task.resume()
        }
    }

    func delete(_ item: DownloadItem) {
        if let tid = item.taskID {
            session.getAllTasks { tasks in tasks.filter { $0.taskIdentifier == tid }.forEach { $0.cancel() } }
        }
        if let u = localURL(item) { try? FileManager.default.removeItem(at: u) }
        items.removeAll { $0.id == item.id }
        persist()
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(items) { try? d.write(to: Self.indexURL) }
    }

    // MARK: URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let p = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        DispatchQueue.main.async {
            if let idx = self.items.firstIndex(where: { $0.taskID == downloadTask.taskIdentifier }) {
                if p - self.items[idx].progress > 0.004 || p >= 1 {
                    self.items[idx].progress = p
                    self.items[idx].bytes = totalBytesWritten
                }
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let remote = downloadTask.originalRequest?.url
        var ext = remote?.pathExtension ?? "mp4"
        if ext.isEmpty { ext = "mp4" }
        let name = UUID().uuidString + "." + ext
        let dest = Self.folder.appendingPathComponent(name)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
        } catch {
            DispatchQueue.main.async { self.mark(downloadTask.taskIdentifier, state: .failed) }
            return
        }
        DispatchQueue.main.async {
            if let idx = self.items.firstIndex(where: { $0.taskID == downloadTask.taskIdentifier }) {
                self.items[idx].fileName = name
                self.items[idx].state = .done
                self.items[idx].progress = 1
                self.persist()
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            DispatchQueue.main.async { self.mark(task.taskIdentifier, state: .failed) }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

    private func mark(_ tid: Int, state: DownloadItem.State) {
        if let idx = items.firstIndex(where: { $0.taskID == tid }), items[idx].state != .done {
            items[idx].state = state
            persist()
        }
    }
}
