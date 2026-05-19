import Foundation
import CryptoKit

public final class GroqCertificatePinner: NSObject, URLSessionTaskDelegate, Sendable {
    public let pinnedHashes: Set<String>
    private let expectedHost: String

    public static let shared = GroqCertificatePinner()

    private convenience override init() {
        self.init(host: "api.groq.com", pinnedHashes: [])
    }

    public init(host: String = "api.groq.com", pinnedHashes: Set<String>) {
        self.expectedHost = host
        self.pinnedHashes = pinnedHashes
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == expectedHost,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard !pinnedHashes.isEmpty else {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        for certificate in chain {
            guard let publicKey = SecCertificateCopyKey(certificate) else { continue }
            let hash = spkiHash(for: publicKey)
            if pinnedHashes.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    private func spkiHash(for key: SecKey) -> String {
        guard let data = SecKeyCopyExternalRepresentation(key, nil) else { return "" }
        let hash = SHA256.hash(data: data as Data)
        return Data(hash).base64EncodedString()
    }
}
