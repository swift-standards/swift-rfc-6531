public import ASCII_Serializer
public import Binary_Serializable
import INCITS_4_1986
public import Parseable_ASCII
public import RFC_1123
public import RFC_5321
public import RFC_5322
import Standard_Library_Extensions

extension RFC_6531 {

    public struct EmailAddress: Sendable, Codable {

        public let displayName: String?

        public let localPart: LocalPart

        public let domain: RFC_1123.Domain

        private init(
            __unchecked: Void,
            displayName: String?,
            localPart: LocalPart,
            domain: RFC_1123.Domain
        ) {
            self.displayName = displayName
            self.localPart = localPart
            self.domain = domain
        }

        public init(
            displayName: String? = nil,
            localPart: LocalPart,
            domain: RFC_1123.Domain
        ) {
            let trimmedDisplayName: String?
            if let name = displayName {
                let trimmed = name.trimming(.ascii.whitespaces)
                trimmedDisplayName = trimmed.isEmpty ? nil : trimmed
            } else {
                trimmedDisplayName = nil
            }
            self.init(

                __unchecked: (),
                displayName: trimmedDisplayName,
                localPart: localPart,
                domain: domain
            )
        }
    }
}

extension RFC_6531.EmailAddress {

    public var address: String {
        "\(localPart)@\(domain.name)"
    }

    public var isASCII: Bool {

        localPart.rawValue.utf8.allSatisfy { $0 < 128 }
            && (displayName?.utf8.allSatisfy { $0 < 128 } ?? true)
    }

    public var rawValue: String { String(decoding: serialized, as: UTF8.self) }
}

extension RFC_6531.EmailAddress: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        let estimatedCapacity =
            (value.displayName?.utf8.count ?? 0)

            + value.localPart.rawValue.utf8.count
            + value.domain.name.utf8.count + 10
        buffer.reserveCapacity(buffer.count + estimatedCapacity)

        if let displayName = value.displayName {

            let needsQuoting = displayName.utf8.contains(where: { byte in

                guard let code = try? ASCII.Code(Byte(byte)) else { return true }
                return !(code.isLetter || code.isDigit || code.isWhitespace)
            })

            if needsQuoting {
                buffer.append(ASCII.Code.quotationMark)
                buffer.append(contentsOf: displayName.utf8.map { ASCII.Code(unchecked: Byte($0)) })
                buffer.append(ASCII.Code.quotationMark)
            } else {
                buffer.append(contentsOf: displayName.utf8.map { ASCII.Code(unchecked: Byte($0)) })
            }

            buffer.append(ASCII.Code.space)
            buffer.append(ASCII.Code.lessThanSign)
        }

        RFC_6531.EmailAddress.LocalPart.serialize(value.localPart, into: &buffer)
        buffer.append(ASCII.Code.commercialAt)
        RFC_1123.Domain.serialize(value.domain, into: &buffer)

        if value.displayName != nil {
            buffer.append(ASCII.Code.greaterThanSign)
        }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        serializeBytes(value, into: &buffer)
    }

    private static func serializeBytes<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        let estimatedCapacity =
            (value.displayName?.utf8.count ?? 0)

            + value.localPart.rawValue.utf8.count
            + value.domain.name.utf8.count + 10
        buffer.reserveCapacity(buffer.count + estimatedCapacity)

        if let displayName = value.displayName {

            let needsQuoting = displayName.utf8.contains(where: { byte in

                guard let code = try? ASCII.Code(Byte(byte)) else { return true }
                return !(code.isLetter || code.isDigit || code.isWhitespace)
            })

            if needsQuoting {
                buffer.append(ASCII.Code.quotationMark)
                buffer.append(contentsOf: displayName.utf8)
                buffer.append(ASCII.Code.quotationMark)
            } else {
                buffer.append(contentsOf: displayName.utf8)
            }

            buffer.append(ASCII.Code.space)
            buffer.append(ASCII.Code.lessThanSign)
        }

        RFC_6531.EmailAddress.LocalPart.serialize(value.localPart, into: &buffer)
        buffer.append(ASCII.Code.commercialAt)
        RFC_1123.Domain.serialize(value.domain, into: &buffer)

        if value.displayName != nil {
            buffer.append(ASCII.Code.greaterThanSign)
        }
    }
}

extension RFC_6531.EmailAddress: ASCII.Parseable {

    public init(_ string: some StringProtocol) throws(Error) {
        try self.init(ascii: [Byte](string.utf8))
    }

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.missingAtSign }

        var lessThanIndex: Bytes.Index?
        var greaterThanIndex: Bytes.Index?
        var lastAtIndex: Bytes.Index?

        for index in bytes.indices {
            switch bytes[index] {
            case ASCII.Code.lessThanSign.byte:
                lessThanIndex = index

            case ASCII.Code.greaterThanSign.byte:
                greaterThanIndex = index

            case ASCII.Code.commercialAt.byte:
                lastAtIndex = index

            default:
                break
            }
        }

        if let lt = lessThanIndex, let gt = greaterThanIndex, lt < gt {

            let whitespace = Set(INCITS_4_1986.whitespaces.map(\.byte))
            let nameBytes = Array(bytes[..<lt]).trimming(whitespace)

            let displayName: String?
            if nameBytes.isEmpty {
                displayName = nil
            } else if nameBytes.count >= 2,
                nameBytes.first == ASCII.Code.quotationMark.byte,
                nameBytes.last == ASCII.Code.quotationMark.byte
            {

                displayName = Self.unescapeQuotedString(nameBytes.dropFirst().dropLast())
            } else {
                displayName = String(decoding: nameBytes, as: UTF8.self)
            }

            let emailBytes = bytes[bytes.index(after: lt)..<gt]

            var emailAtIndex: Bytes.Index?
            for index in emailBytes.indices {
                if emailBytes[index] == ASCII.Code.commercialAt.byte {
                    emailAtIndex = index
                }
            }

            guard let atIdx = emailAtIndex else {
                throw Error.missingAtSign
            }

            let localBytes = emailBytes[..<atIdx]
            let domainBytes = emailBytes[emailBytes.index(after: atIdx)...]

            do {
                let localPart = try LocalPart(ascii: localBytes)
                let domain = try RFC_1123.Domain(ascii: domainBytes)
                self.init(

                    __unchecked: (),
                    displayName: displayName,
                    localPart: localPart,
                    domain: domain
                )
            } catch let error as LocalPart.Error {
                throw Error.invalidLocalPart(error)
            } catch {
                throw Error.invalidDomain(String(describing: error))
            }
        } else {

            guard let atIdx = lastAtIndex else {
                throw Error.missingAtSign
            }

            let localBytes = bytes[..<atIdx]
            let domainBytes = bytes[bytes.index(after: atIdx)...]

            do {
                let localPart = try LocalPart(ascii: localBytes)
                let domain = try RFC_1123.Domain(ascii: domainBytes)
                self.init(

                    __unchecked: (),
                    displayName: nil,
                    localPart: localPart,
                    domain: domain
                )
            } catch let error as LocalPart.Error {
                throw Error.invalidLocalPart(error)
            } catch {
                throw Error.invalidDomain(String(describing: error))
            }
        }
    }

    private static func unescapeQuotedString<Bytes: Swift.Collection>(
        _ bytes: Bytes
    ) -> String where Bytes.Element == Byte {

        var hasEscapes = false
        for byte in bytes where byte == ASCII.Code.reverseSolidus.byte {
            hasEscapes = true
            break
        }

        if !hasEscapes {

            return String(decoding: bytes, as: UTF8.self)
        }

        var result: [Byte] = []
        result.reserveCapacity(bytes.count)

        var iterator = bytes.makeIterator()
        while let byte = iterator.next() {
            if byte == ASCII.Code.reverseSolidus.byte {

                if let next = iterator.next() {
                    result.append(next)
                }
            } else {
                result.append(byte)
            }
        }
        return String(decoding: result, as: UTF8.self)
    }
}

extension RFC_6531.EmailAddress: CustomStringConvertible {
    public var description: String {
        String(decoding: serialized, as: UTF8.self)
    }
}

extension RFC_6531.EmailAddress: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
        hasher.combine(localPart)
        hasher.combine(domain)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.displayName == rhs.displayName
            && lhs.localPart == rhs.localPart
            && lhs.domain == rhs.domain
    }
}

extension RFC_6531.EmailAddress: RawRepresentable {
    public init?(rawValue: String) {
        do throws(Error) {
            try self.init(rawValue)
        } catch {
            return nil
        }
    }
}

extension RFC_5321.EmailAddress {

    public init(_ emailAddress: RFC_6531.EmailAddress) throws(RFC_6531.EmailAddress.ConversionError)
    {
        guard emailAddress.isASCII else {
            throw RFC_6531.EmailAddress.ConversionError.nonASCIICharacters
        }
        let localPart: RFC_5321.EmailAddress.LocalPart
        do throws(RFC_5321.EmailAddress.LocalPart.Error) {
            localPart = try RFC_5321.EmailAddress.LocalPart(emailAddress.localPart.rawValue)
        } catch {
            throw RFC_6531.EmailAddress.ConversionError.notRepresentableAsRFC5321(
                .invalidLocalPart(error)
            )
        }
        do throws(RFC_5321.EmailAddress.Error) {
            self = try RFC_5321.EmailAddress(
                displayName: emailAddress.displayName,
                localPart: localPart,
                domain: emailAddress.domain
            )
        } catch {
            throw RFC_6531.EmailAddress.ConversionError.notRepresentableAsRFC5321(error)
        }
    }
}

extension RFC_5322.EmailAddress {

    public init(_ emailAddress: RFC_6531.EmailAddress) throws(RFC_6531.EmailAddress.ConversionError)
    {
        guard emailAddress.isASCII else {
            throw RFC_6531.EmailAddress.ConversionError.nonASCIICharacters
        }
        let localPart: RFC_5322.EmailAddress.LocalPart
        do throws(RFC_5322.EmailAddress.LocalPart.Error) {
            localPart = try RFC_5322.EmailAddress.LocalPart(emailAddress.localPart.rawValue)
        } catch {
            throw RFC_6531.EmailAddress.ConversionError.notRepresentableAsRFC5322(
                .localPart(error)
            )
        }
        do throws(RFC_5322.EmailAddress.Error) {
            self = try RFC_5322.EmailAddress(
                displayName: emailAddress.displayName,
                localPart: localPart,
                domain: emailAddress.domain
            )
        } catch {
            throw RFC_6531.EmailAddress.ConversionError.notRepresentableAsRFC5322(error)
        }
    }
}
