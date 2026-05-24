import Foundation

public enum OrbState: Equatable {
    case idle
    case pairing
    case syncing(current: Int, total: Int)
    case complete

    public var progress: Double {
        switch self {
        case .idle, .pairing:
            return 0
        case .syncing(let current, let total):
            guard total > 0 else { return 0 }
            return min(1, max(0, Double(current) / Double(total)))
        case .complete:
            return 1
        }
    }

    public var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}
