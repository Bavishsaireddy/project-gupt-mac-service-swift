//
//  MessageCodec.swift
//  RemoteDesktop
//
//  Message serialization and deserialization
//

import Foundation

/// Encodes and decodes NetworkMessage to/from Data
actor MessageCodec {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        // Configure for efficiency
        encoder.outputFormatting = []  // No pretty printing
    }

    // MARK: - Encoding

    /// Encode a message to wire format
    /// Format: [Type:1][Sequence:4][Timestamp:8][PayloadSize:4][Payload:N]
    func encode(_ message: NetworkMessage) throws -> Data {
        var data = Data()
        data.reserveCapacity(MessageConstants.headerSize + message.payload.count)

        // Write header
        data.append(message.type.rawValue)
        data.append(contentsOf: withUnsafeBytes(of: message.sequenceNumber.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: message.timestamp.bigEndian) { Data($0) })

        let payloadSize = UInt32(message.payload.count)
        guard payloadSize <= MessageConstants.maxPayloadSize else {
            throw CodecError.payloadTooLarge
        }

        data.append(contentsOf: withUnsafeBytes(of: payloadSize.bigEndian) { Data($0) })

        // Write payload
        data.append(message.payload)

        return data
    }

    /// Encode a typed message (handshake, auth, etc.) into a NetworkMessage
    func encodePayload<T: Codable>(_ payload: T, type: MessageType, sequence: UInt32) throws -> NetworkMessage {
        let payloadData = try encoder.encode(payload)
        return NetworkMessage(
            type: type,
            sequenceNumber: sequence,
            timestamp: NetworkMessage.currentTimestamp(),
            payload: payloadData
        )
    }

    // MARK: - Decoding

    /// Decode a NetworkMessage from wire format
    /// Returns the message and the number of bytes consumed
    func decode(from data: Data) throws -> (message: NetworkMessage, bytesConsumed: Int) {
        guard data.count >= MessageConstants.headerSize else {
            throw CodecError.insufficientData
        }

        var offset = data.startIndex

        // Read header
        guard let type = MessageType(rawValue: data[offset]) else {
            throw CodecError.invalidMessageType
        }
        offset += 1

        let sequenceNumber = data[offset..<offset+4].withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).bigEndian
        }
        offset += 4

        let timestamp = data[offset..<offset+8].withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self).bigEndian
        }
        offset += 8

        let payloadSize = data[offset..<offset+4].withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).bigEndian
        }
        offset += 4

        guard payloadSize <= MessageConstants.maxPayloadSize else {
            throw CodecError.payloadTooLarge
        }

        let totalSize = MessageConstants.headerSize + Int(payloadSize)
        guard data.count >= totalSize else {
            throw CodecError.insufficientData
        }

        // Read payload
        let payload = data[offset..<offset+Int(payloadSize)]

        let message = NetworkMessage(
            type: type,
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            payload: Data(payload)
        )

        return (message, totalSize)
    }

    /// Decode the payload of a NetworkMessage into a typed object
    func decodePayload<T: Codable>(_ message: NetworkMessage, as type: T.Type) throws -> T {
        return try decoder.decode(type, from: message.payload)
    }

    // MARK: - Batch Operations

    /// Decode multiple messages from a data buffer
    /// Returns array of messages and total bytes consumed
    func decodeMultiple(from data: Data) throws -> (messages: [NetworkMessage], bytesConsumed: Int) {
        var messages: [NetworkMessage] = []
        var offset = data.startIndex

        while offset < data.endIndex {
            let remainingData = data[offset...]
            guard remainingData.count >= MessageConstants.headerSize else {
                break  // Not enough data for another message
            }

            do {
                let (message, consumed) = try decode(from: Data(remainingData))
                messages.append(message)
                offset += consumed
            } catch CodecError.insufficientData {
                break  // Partial message, wait for more data
            } catch {
                throw error
            }
        }

        return (messages, offset - data.startIndex)
    }
}

// CodecError is defined in CodecConfiguration.swift

// MARK: - Convenience Extensions

extension MessageCodec {
    /// Quick encode for video frames
    func encodeVideoFrame(_ frame: VideoFrameMessage, sequence: UInt32) throws -> Data {
        let message = try encodePayload(frame, type: .videoFrame, sequence: sequence)
        return try encode(message)
    }

    /// Quick encode for input events
    func encodeInputEvent(_ event: InputEventMessage, sequence: UInt32) throws -> Data {
        let message = try encodePayload(event, type: .inputEvent, sequence: sequence)
        return try encode(message)
    }

    /// Quick encode for handshake
    func encodeHandshake(_ handshake: HandshakeMessage, sequence: UInt32) throws -> Data {
        let message = try encodePayload(handshake, type: .handshake, sequence: sequence)
        return try encode(message)
    }

    /// Quick encode for authentication
    func encodeAuth(_ auth: AuthMessage, sequence: UInt32) throws -> Data {
        let message = try encodePayload(auth, type: .auth, sequence: sequence)
        return try encode(message)
    }
}
