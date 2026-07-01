import Foundation

/// Persists extensions the user added by hand — extensions that no installed app
/// declares in its `Info.plist`, so the `/Applications` scan can never surface them
/// on its own (e.g. `env`, which resolves only to a dynamic UTI). The set is merged
/// back into the scanned list on every launch so the rows reappear.
nonisolated final class ManualExtensionStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "manuallyAddedExtensions") {
        self.defaults = defaults
        self.key = key
    }

    func all() -> [String] {
        (defaults.array(forKey: key) as? [String] ?? []).sorted()
    }

    /// Adds a normalized extension. Returns the normalized value on success, or
    /// `nil` if the input isn't a valid bare extension.
    @discardableResult
    func add(_ raw: String) -> String? {
        guard let ext = AppScanner.normalizeExtension(raw) else { return nil }
        var set = Set(all())
        set.insert(ext)
        defaults.set(Array(set), forKey: key)
        return ext
    }

    func remove(_ raw: String) {
        guard let ext = AppScanner.normalizeExtension(raw) else { return }
        var set = Set(all())
        set.remove(ext)
        defaults.set(Array(set), forKey: key)
    }

    func contains(_ raw: String) -> Bool {
        guard let ext = AppScanner.normalizeExtension(raw) else { return false }
        return Set(all()).contains(ext)
    }
}
