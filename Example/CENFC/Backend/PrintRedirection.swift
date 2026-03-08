import Foundation

/// Captures stdout output and forwards it to AppLogStore.
///
/// Uses `Pipe` + `dup2` to intercept file descriptor writes,
/// similar to Flowdown's approach. Call ``start()`` once at app launch.
enum PrintRedirection {
    private static var originalStdout: Int32 = -1
    private static var pipe: Pipe?

    static func start() {
        guard pipe == nil else { return }

        let newPipe = Pipe()
        pipe = newPipe

        // Save original stdout so we can still write to Xcode console
        originalStdout = dup(STDOUT_FILENO)

        // Redirect stdout to pipe
        dup2(newPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        newPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            // Forward to original stdout (Xcode console) so debug output isn't lost
            if originalStdout >= 0 {
                _ = data.withUnsafeBytes { bytes in
                    write(originalStdout, bytes.baseAddress!, data.count)
                }
            }

            guard let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            else { return }

            Task { @MainActor in
                AppLogStore.shared.debug(text, source: "Print")
            }
        }
    }
}
