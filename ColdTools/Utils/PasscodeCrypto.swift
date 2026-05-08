import Foundation
import CryptoKit

enum PasscodeCrypto {
    static func randomSaltHex(byteCount: Int = 16) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hash(passcode: String, saltHex: String) -> String {
        let input = (saltHex + ":" + passcode).data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func verify(passcode: String, saltHex: String, expectedHashHex: String) -> Bool {
        hash(passcode: passcode, saltHex: saltHex) == expectedHashHex
    }
}
