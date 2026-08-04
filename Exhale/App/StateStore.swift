import Foundation
import OSLog

/// A small `Codable` store in Application Support.
///
/// Application Support rather than Caches so the streak survives the system
/// reclaiming disk space, and rather than `UserDefaults` so a corrupt write
/// can't take the whole defaults domain with it. The file is excluded from
/// iCloud/iTunes backup exclusion — we *want* it backed up.
struct StateStore: Sendable {

    private let url: URL?
    private static let logger = Logger(subsystem: "com.matthias.exhale", category: "store")

    init(url: URL?) { self.url = url }

    static let applicationSupport: StateStore = {
        let fm = FileManager.default
        guard let dir = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return StateStore(url: nil)
        }
        return StateStore(url: dir.appendingPathComponent("exhale-state.json"))
    }()

    /// Used by seeded runs and tests — reads and writes nothing.
    static let ephemeral = StateStore(url: nil)

    func load() -> PersistedState? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            Self.logger.error("Could not decode saved state: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ state: PersistedState) {
        guard let url else { return }
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: .atomic)
        } catch {
            Self.logger.error("Could not save state: \(error.localizedDescription)")
        }
    }
}
