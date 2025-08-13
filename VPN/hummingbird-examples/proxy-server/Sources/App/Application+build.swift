import AsyncHTTPClient
import Hummingbird
import HummingbirdHTTP2
import Logging
import NIOCore
import NIOPosix
import ServiceLifecycle

public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var location: String { get }
    var target: String { get }
    var tlsConfiguration: TLSConfiguration { get throws }
}

/// Request context for proxy
///
/// Stores remote address
struct ProxyRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    let channel: Channel
    let remoteAddress: SocketAddress?

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.channel = source.channel
        self.remoteAddress = channel.remoteAddress
    }

    var isHTTP2: Bool {
        // Using the fact that HTTP2 stream channels have a parent HTTP2 connection channel
        // as a way to recognise an HTTP/2 channel vs an HTTP/1.1 channel
        self.channel.parent?.parent != nil
    }
}

func buildApplication(_ args: some AppArguments) throws -> some ApplicationProtocol {
    let eventLoopGroup = MultiThreadedEventLoopGroup.singleton
    let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
    let router = Router(context: ProxyRequestContext.self)
    router.add(middleware:
        ProxyServerMiddleware(
            httpClient: httpClient,
            proxy: .init(location: args.location, target: args.target)
        )
    )
//    router.get("/") { _, _ in
//        return "Hello"
//    }
//    router.get("/http") { request, context in
//        return "Using http v\(context.isHTTP2 ? "2.0" : "1.1")"
//    }

    var logger = Logger(label: "ProxyServer")
    logger.logLevel = .debug

    var app = try Application(
        router: router,
        server: .http2Upgrade(
            tlsConfiguration: args.tlsConfiguration,
            configuration: .init(
                idleTimeout: .seconds(30),
                gracefulCloseTimeout: .seconds(30),
                maxAgeTimeout: .seconds(2 * 60 * 60)
            )
        ),
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: "ProxyServer"
        ),
        eventLoopGroupProvider: .shared(eventLoopGroup),
        logger: logger
    )
    app.addServices(HTTPClientService(client: httpClient))
    return app
}

struct HTTPClientService: Service {
    let client: HTTPClient

    func run() async throws {
        try? await gracefulShutdown()
        try await self.client.shutdown()
    }
}
