import Foundation
import OSLog

/// Keeps the quit plan alive across a reinstall or a new phone.
///
/// The app's entire mechanic is loss aversion: the spiral is worth protecting
/// because it took two hundred days to grow. Losing it to a phone upgrade does
/// to the user exactly what a relapse does, for no reason at all — and it is
/// the one failure they would never forgive.
///
/// `NSUbiquitousKeyValueStore` rather than CloudKit on purpose. There is no
/// account, no schema, no sync engine and no network code; it rides the user's
/// existing iCloud login, works offline, and the payload is well under the 1 MB
/// limit — four stored facts plus a handful of attempts. That keeps the
/// privacy claim honest: nothing goes to a server of ours, because we have none.
struct CloudMirror {

    private let store = NSUbiquitousKeyValueStore.default
    private let key = "exhale.state"
    private let logger = Logger(subsystem: "com.matthias1412.exhale", category: "cloud")

    func save(_ state: PersistedState) {
        do {
            store.set(try JSONEncoder().encode(state), forKey: key)
            store.synchronize()
        } catch {
            logger.error("Could not mirror state to iCloud: \(error.localizedDescription)")
        }
    }

    func load() -> PersistedState? {
        guard let data = store.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            logger.error("Could not read iCloud state: \(error.localizedDescription)")
            return nil
        }
    }

    func clear() {
        store.removeObject(forKey: key)
        store.synchronize()
    }

    /// Newest wins.
    ///
    /// The only conflict that realistically happens is a fresh install finding
    /// an older cloud copy, or a second device that has been running longer.
    /// Comparing `updatedAt` handles both without a merge strategy nobody would
    /// be able to reason about.
    static func newer(_ a: PersistedState?, _ b: PersistedState?) -> PersistedState? {
        switch (a, b) {
        case let (a?, b?): return a.updatedAt >= b.updatedAt ? a : b
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }
}
