import Foundation

/// Intercepts every request on its `URLSession` and replies with a canned
/// `(Data, HTTPURLResponse)` so providers can be exercised against saved
/// fixtures with no network. Set `responder` per test; it sees the outgoing
/// request and returns the bytes plus an HTTP status code.
final class MockURLProtocol: URLProtocol {
    /// Maps a request to its canned `(body, statusCode)`. Replaced per test.
    /// Defaults to a 200 with empty body so an unconfigured test fails loudly
    /// at the decode step rather than hanging.
    nonisolated(unsafe) static var responder: (@Sendable (URLRequest) -> (Data, Int))?

    /// Builds a `URLSession` whose only protocol is this mock.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (data, status) = MockURLProtocol.responder?(request) ?? (Data(), 200)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension MockURLProtocol {
    /// Convenience: respond with the same UTF-8 body for every request.
    static func respond(_ body: String, status: Int = 200) {
        let data = Data(body.utf8)
        responder = { _ in (data, status) }
    }

    /// Respond with raw bytes (e.g. UTF-16 fixtures) for every request.
    static func respond(_ data: Data, status: Int = 200) {
        responder = { _ in (data, status) }
    }
}
