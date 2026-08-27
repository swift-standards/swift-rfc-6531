public import ASCII_Serializer
public import Binary_Serializable
import INCITS_4_1986
public import Parseable_ASCII

extension RFC_6531.EmailAddress {

    public struct LocalPart: Sendable, Codable {
        public let rawValue: String
        private let storage: Storage

        private init(__unchecked: Void, storage: Storage, rawValue: String) {
            self.storage = storage
            self.rawValue = rawValue
        }
    }
}

extension RFC_6531.EmailAddress.LocalPart: Swift.RawRepresentable, ASCII.Serializable, Binary
        .Serializable
{

    public init?(rawValue: String) {
        do throws(Error) {
            try self.init(rawValue)
        } catch {
            return nil
        }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {

        for byte in value.rawValue.utf8 { buffer.append(ASCII.Code(byte)) }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: value.serialized)
    }
}

extension RFC_6531.EmailAddress.LocalPart: ASCII.Parseable {

    public init(_ string: some StringProtocol) throws(Error) {
        try self.init(ascii: [Byte](string.utf8))
    }

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {

        guard let firstByte = bytes.first else { throw Error.empty }

        let byteCount = bytes.count
        guard byteCount <= Limits.maxUTF8Length else { throw Error.tooLong(byteCount) }

        var lastByte = firstByte
        for byte in bytes { lastByte = byte }

        if firstByte == ASCII.Code.quotationMark.byte {
            guard byteCount >= 2, lastByte == ASCII.Code.quotationMark.byte else {
                throw Error.invalidQuotedString(String(decoding: bytes, as: UTF8.self))
            }

            guard Self.isValidQuotedContent(bytes.dropFirst().dropLast()) else {
                throw Error.invalidQuotedString(String(decoding: bytes, as: UTF8.self))
            }

            self.init(

                __unchecked: (),
                storage: .quoted,
                rawValue: String(decoding: bytes, as: UTF8.self)
            )
        }

        else {

            if firstByte == ASCII.Code.period.byte {
                throw Error.leadingOrTrailingDot(String(decoding: bytes, as: UTF8.self))
            }

            if lastByte == ASCII.Code.period.byte {
                throw Error.leadingOrTrailingDot(String(decoding: bytes, as: UTF8.self))
            }

            var prevWasDot = false
            for byte in bytes {
                if byte == ASCII.Code.period.byte {
                    if prevWasDot {
                        throw Error.consecutiveDots(String(decoding: bytes, as: UTF8.self))
                    }
                    prevWasDot = true
                } else {
                    prevWasDot = false
                }
            }

            var atomStart = bytes.startIndex
            for index in bytes.indices {
                if bytes[index] == ASCII.Code.period.byte {

                    let atomBytes = bytes[atomStart..<index]
                    guard Self.isValidUTF8Atom(atomBytes) else {
                        throw Error.invalidUTF8Atom(String(decoding: atomBytes, as: UTF8.self))
                    }
                    atomStart = bytes.index(after: index)
                }
            }

            let finalAtomBytes = bytes[atomStart...]
            guard Self.isValidUTF8Atom(finalAtomBytes) else {
                throw Error.invalidUTF8Atom(String(decoding: finalAtomBytes, as: UTF8.self))
            }

            self.init(

                __unchecked: (),
                storage: .utf8DotAtom,
                rawValue: String(decoding: bytes, as: UTF8.self)
            )
        }
    }
}

extension RFC_6531.EmailAddress.LocalPart {

    private static func isValidUTF8Atom<Bytes: Swift.Collection>(
        _ bytes: Bytes
    ) -> Bool where Bytes.Element == Byte {
        guard !bytes.isEmpty else { return false }

        for byte in bytes {

            guard let code = try? ASCII.Code(byte) else { continue }

            guard RFC_5322.isAtext(code) else {
                return false
            }
        }
        return true
    }

    private static func isValidQuotedContent<Bytes: Swift.Collection>(
        _ bytes: Bytes
    ) -> Bool where Bytes.Element == Byte {
        guard !bytes.isEmpty else { return false }

        var iterator = bytes.makeIterator()
        while let byte = iterator.next() {
            if byte == ASCII.Code.reverseSolidus.byte {

                guard let next = iterator.next() else { return false }
                guard
                    next == ASCII.Code.quotationMark.byte || next == ASCII.Code.reverseSolidus.byte
                else {
                    return false
                }
            } else if byte == ASCII.Code.quotationMark.byte
                || byte == ASCII.Code.cr.byte
                || byte == ASCII.Code.lf.byte
            {

                return false
            }

        }
        return true
    }
}

extension RFC_6531.EmailAddress.LocalPart: CustomStringConvertible {

    public var description: String {
        String(decoding: serialized, as: UTF8.self)
    }
}

extension RFC_6531.EmailAddress.LocalPart: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {

        lhs.rawValue == rhs.rawValue
    }
}
