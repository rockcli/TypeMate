import Foundation

/// Debounce manager using Swift concurrency (Task.sleep + cancellation)
actor DebounceManager {
    private var currentTask: Task<Void, Never>?

    /// Schedule a debounced action. If called again before delay, previous is cancelled.
    func schedule(delayNanoseconds: UInt64 = AppConstants.debounceMilliseconds,
                  action: @escaping @Sendable () async -> Void) {
        currentTask?.cancel()
        currentTask = Task {
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
                guard !Task.isCancelled else { return }
                await action()
            } catch {
                // Task cancelled — expected
            }
        }
    }

    /// Cancel any pending debounce
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}
