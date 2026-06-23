import Darwin
import Foundation

extension CoreProcessManager {
    func makeSessionToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    func allocateLoopbackPort() throws -> Int {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw CoreProcessManagerError.socketFailed(String(cString: strerror(errno)))
        }
        defer { close(socketDescriptor) }

        var reuse: Int32 = 1
        setsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(socketDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw CoreProcessManagerError.socketFailed(String(cString: strerror(errno)))
        }

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(socketDescriptor, sockaddrPointer, &length)
            }
        }
        guard nameResult == 0 else {
            throw CoreProcessManagerError.socketFailed(String(cString: strerror(errno)))
        }

        return Int(UInt16(bigEndian: address.sin_port))
    }

    nonisolated static func coreServeArguments(port: Int, sessionTokenFileURL: URL) -> [String] {
        [
            "serve",
            "--host", "127.0.0.1",
            "--port", "\(port)",
            "--session-token-file", sessionTokenFileURL.path,
            "+RTS", "-N", "-A24m", "-qn1", "-Iw3", "-RTS"
        ]
    }
}
