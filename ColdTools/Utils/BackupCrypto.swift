import Foundation
import CryptoKit
import CommonCrypto

// Encrypted backup payload structure.
struct EncryptedBackupPayload: Codable {
    let kind: String
    let version: Int
    let salt: String   // base64 of 16 bytes
    let iv: String     // base64 of 12 bytes
    let data: String   // base64 of ciphertext+tag
    let createdAt: String
}

enum BackupCrypto {
    static let iterations = 120_000
    static let kind = "cold-tools-encrypted-backup"

    static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    static func deriveKey(password: String, saltBytes: Data) -> SymmetricKey {
        let keyLength = 32
        var derived = [UInt8](repeating: 0, count: keyLength)
        let passwordBytes = Array(password.utf8)
        let saltArray = [UInt8](saltBytes)

        _ = saltArray.withUnsafeBufferPointer { saltPtr -> Int32 in
            passwordBytes.withUnsafeBufferPointer { pwPtr -> Int32 in
                derived.withUnsafeMutableBufferPointer { outPtr -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwPtr.baseAddress, pwPtr.count,
                        saltPtr.baseAddress, saltPtr.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        outPtr.baseAddress, keyLength
                    )
                }
            }
        }
        return SymmetricKey(data: Data(derived))
    }

    static func encrypt(plaintext: Data, password: String) throws -> EncryptedBackupPayload {
        let saltBytes = randomBytes(16)
        let ivBytes = randomBytes(12)
        let key = deriveKey(password: password, saltBytes: saltBytes)

        let nonce = try AES.GCM.Nonce(data: ivBytes)
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        let combined = sealed.ciphertext + sealed.tag

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return EncryptedBackupPayload(
            kind: kind,
            version: 1,
            salt: saltBytes.base64EncodedString(),
            iv: ivBytes.base64EncodedString(),
            data: combined.base64EncodedString(),
            createdAt: df.string(from: .now)
        )
    }

    static func decrypt(payload: EncryptedBackupPayload, password: String) throws -> Data {
        guard let saltData = Data(base64Encoded: payload.salt),
              let ivData = Data(base64Encoded: payload.iv),
              let combined = Data(base64Encoded: payload.data),
              combined.count >= 16 else {
            throw NSError(domain: "Backup", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "备份数据格式错误"])
        }
        let ciphertext = combined.prefix(combined.count - 16)
        let tag = combined.suffix(16)
        let key = deriveKey(password: password, saltBytes: saltData)
        let nonce = try AES.GCM.Nonce(data: ivData)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealed, using: key)
    }
}
