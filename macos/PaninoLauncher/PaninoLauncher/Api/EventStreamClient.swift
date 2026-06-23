import Foundation

struct EventStreamClient: Equatable {
    let apiClient: LauncherApiClient

    func events() -> AsyncThrowingStream<CoreEvent, Error> {
        AsyncThrowingStream { continuation in
            let streamTask = Task {
                do {
                    let request = apiClient.authorizedRequest(path: "/api/v1/events")
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LauncherApiError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw LauncherApiError.unexpectedStatus(httpResponse.statusCode, "")
                    }

                    var dataLines: [String] = []
                    for try await rawLine in bytes.lines {
                        let line = rawLine.trimmingCharacters(in: .newlines)
                        if line.isEmpty {
                            emitEvent(from: dataLines, continuation: continuation)
                            dataLines.removeAll(keepingCapacity: true)
                        } else if line.hasPrefix("data:") {
                            let value = line.dropFirst("data:".count)
                            dataLines.append(value.trimmingCharacters(in: .whitespaces))
                        }
                    }

                    emitEvent(from: dataLines, continuation: continuation)
                    continuation.finish()
                } catch {
                    if Task.isCancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }

    private func emitEvent(
        from dataLines: [String],
        continuation: AsyncThrowingStream<CoreEvent, Error>.Continuation
    ) {
        guard !dataLines.isEmpty else { return }
        let payload = dataLines.joined(separator: "\n")
        guard let data = payload.data(using: .utf8) else { return }

        do {
            let event = try JSONDecoder().decode(CoreEvent.self, from: data)
            continuation.yield(event)
        } catch {
            continuation.finish(throwing: error)
        }
    }
}
