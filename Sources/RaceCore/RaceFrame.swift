import Foundation

/// Each message on the wire: a 4-byte big-endian length, then that many bytes of JSON. 1 KB at most.
public enum RaceFrame {
    public static let maxBytes = 1024

    public static func encode(_ message: RaceMessage) -> Data {
        let body = message.json()
        return withUnsafeBytes(of: UInt32(body.count).bigEndian) { Data($0) } + body
    }
}

/// A frame announced more than 1 KB. The connection is closed.
public struct FrameTooLarge: Error, Equatable {}

/// Turns the bytes of a stream, however they're split, into whole frame bodies.
public struct FrameReader: Sendable {
    private var buffer = Data()
    public init() {}

    /// Adds bytes and returns every frame body now complete, in order. Throws as soon as a length over 1 KB is seen.
    public mutating func append(_ data: Data) throws(FrameTooLarge) -> [Data] {
        buffer.append(data)
        var frames: [Data] = []
        while buffer.count >= 4 {
            let length = buffer.prefix(4).reduce(0) { $0 << 8 | Int($1) }
            guard length <= RaceFrame.maxBytes else { throw FrameTooLarge() }
            guard buffer.count >= 4 + length else { break }
            frames.append(Data(buffer.dropFirst(4).prefix(length)))
            buffer = Data(buffer.dropFirst(4 + length))
        }
        return frames
    }
}
