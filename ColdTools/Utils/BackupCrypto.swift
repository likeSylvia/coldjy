import Foundation
import CryptoKit
import CommonCrypto

// Matches the web app's encrypted backup format:
// { kind: "tx-life-encrypted-backup", version, salt, iv, data, createdAt }
struct EncryptedBackupPayload: Codable {
    let kind: String
    let version: Int
    let salt: String   // base64 of 16 bytes
    let iv: String     // base64 of 12 bytes
    let data: String   // base64 of ciphertext
    let createdAt: String
}

enum BackupCrypto {
    static let iterations = 120_000
    static let kind = "cold-tools-encrypted-backup"

    static func deriveKey(password: String, saltBytes: Data) -> SymmetricKey {
        // PBKDF2-HMAC-SHA256, 32 bytes
        var derived = Data(count: 32)
        let passwordBytes = Array(password.utf8)
        derived.withUnsafeMutableBytes { (derivedPtr: UnsafeMutableRawBufferPointer) in
            _ = saltBytes.withUnsafeBytes { (saltPtr: UnsafeRawBufferPointer) in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes, passwordBytes.count,
                    saltPtr.baseAddress, saltBytes.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    derivedPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    derived.count
                )
            }
        }
        return SymmetricKey(data: derived)
    }

    static func encrypt(plaintext: Data, password: String) throws -> EncryptedBackupPayload {
        var saltBytes = Data(count: 16)
        _ = saltBytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let key = deriveKey(password: password, saltBytes: saltBytes)

        var ivBytes = Data(count: 12)
        _ = ivBytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 12, $0.baseAddress!) }
        let nonce = try AES.GCM.Nonce(data: ivBytes)

        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        // Combine ciphertext+tag as in web crypto subtle AES-GCM (append tag)
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
            throw NSError(domain: "Backup", code: -1, userInfo: [NSLocalizedDescriptionKey: "备份数据格式错误"])
        }
        let ciphertext = combined.prefix(combined.count - 16)
        let tag = combined.suffix(16)
        let key = deriveKey(password: password, saltBytes: saltData)
        let nonce = try AES.GCM.Nonce(data: ivData)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealed, using: key)
    }
}
