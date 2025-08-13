import ArgumentParser
import Hummingbird
import NIOSSL

@main
struct HummingbirdArguments: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = "192.168.1.62"

    @Option(name: .shortAndLong)
    var port: Int = 8081

    @Option(name: .shortAndLong, help: "PEM file containing certificate chain")
    var certificateChain: String = "resources/certs/server.crt"

    @Option(name: .long, help: "PEM file containing private key")
    var privateKey: String = "resources/certs/server.key"

    var tlsConfiguration: TLSConfiguration {
        get throws {
            let certificateChain = try NIOSSLCertificate.fromPEMFile(self.certificateChain)
            let privateKey = try NIOSSLPrivateKey(file: self.privateKey, format: .pem)
            return TLSConfiguration.makeServerConfiguration(
                certificateChain: certificateChain.map { .certificate($0) },
                privateKey: .privateKey(privateKey)
            )
        }
    }

    @Option(name: .shortAndLong)
    var location: String = ""

    @Option(name: .shortAndLong)
    var target: String = "http://localhost:8080"

    func run() async throws {
        let app = try buildApplication(self)
        try await app.runService()
    }
}
