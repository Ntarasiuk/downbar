import Foundation

/// Watches one file for external modification and fires a debounced handler on
/// the main queue. Survives atomic replace-by-rename (how editors, `mv`, and
/// the app's own `.atomic` writes land): a delete/rename event re-attaches to
/// the new inode, and a parent-directory watch picks the file back up if it
/// was missing or briefly gone.
/// All mutable state is confined to `queue`, hence `@unchecked Sendable`.
final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private let handler: @Sendable () -> Void
    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?
    private var debounce: DispatchWorkItem?
    private let queue = DispatchQueue(label: "downbar.file-watcher")

    init(url: URL, handler: @escaping @Sendable () -> Void) {
        self.url = url
        self.handler = handler
        queue.async { [weak self] in
            self?.armFile()
            self?.armDirectory()
        }
    }

    deinit {
        fileSource?.cancel()
        dirSource?.cancel()
        debounce?.cancel()
    }

    private func armFile() {
        fileSource?.cancel()
        fileSource = nil
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if source.data.contains(.delete) || source.data.contains(.rename) {
                self.armFile()
            }
            self.fireDebounced()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileSource = source
    }

    private func armDirectory() {
        let fd = open(url.deletingLastPathComponent().path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if self.fileSource == nil { self.armFile() }
            self.fireDebounced()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        dirSource = source
    }

    /// Editors emit bursts of events per save; collapse them into one callback.
    private func fireDebounced() {
        debounce?.cancel()
        let work = DispatchWorkItem { [handler] in
            DispatchQueue.main.async(execute: handler)
        }
        debounce = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
