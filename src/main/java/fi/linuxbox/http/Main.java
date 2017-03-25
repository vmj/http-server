package fi.linuxbox.http;

import com.sun.net.httpserver.*;

import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.util.logging.Logger;

import static java.nio.charset.Charset.forName;

public class Main {
    public static void main(String... args) {
        forEach(exchange -> {
            switch (exchange.getRequestURI().toString()) {
                case ROOT_CONTEXT_PATH:
                    switch (exchange.getRequestMethod()) {
                        case GET:
                            respond(exchange, OK, ROOT_RESOURCE);
                            break;
                        case HEAD:
                            respond(exchange, OK, EMPTY_RESPONSE_BODY);
                            break;
                        case OPTIONS:
                            exchange.getResponseHeaders().add(ALLOW, ALLOWED_METHODS);
                            respond(exchange, OK, EMPTY_RESPONSE_BODY);
                            break;
                        default:
                            exchange.getResponseHeaders().add(ALLOW, ALLOWED_METHODS);
                            respond(exchange, METHOD_NOT_ALLOWED, EMPTY_RESPONSE_BODY);
                            break;
                    }
                    break;
                default:
                    respond(exchange, NOT_FOUND, EMPTY_RESPONSE_BODY);
                    break;
            }
        });
    }

    private static void forEach(final HttpHandler handler) {
        final HttpServer httpServer;
        try {
            httpServer = HttpServer.create(ADDRESS, BACKLOG);
        } catch (final IOException e) {
            log.warning("Failed to create HTTP server: " + e.getMessage());
            return;
        }
        final HttpContext context = httpServer.createContext(ROOT_CONTEXT_PATH);

        context.setHandler(handler);

        httpServer.start();

        Runtime.getRuntime().addShutdownHook(new Thread(() -> httpServer.stop(NOW)));
    }

    private static void respond(final HttpExchange exchange, final int httpStatus, final byte[] message) {
        // Closing an exchange without consuming all of the request body is not an error but may make the underlying
        // TCP connection unusable for following exchanges (think HTTP 1.1 pipelining).
        consumeInputStream(exchange.getRequestBody());
        exchange.getResponseHeaders().add(CONTENT_TYPE, TEXT_PLAIN);
        try {
            if (message.length > 0) {
                exchange.sendResponseHeaders(httpStatus, message.length);
                exchange.getResponseBody().write(message);
            } else {
                exchange.sendResponseHeaders(httpStatus, -1);
            }
        } catch (final IOException e) {
            log.warning("Failed to write response: " + e.getMessage());
        } finally {
            exchange.close();
        }
    }

    private static void consumeInputStream(final InputStream is) {
        if (is == null)
            return;
        try {
            while (is.read() != -1) { /* null loop */ }
        } catch (final IOException e) {
            log.warning("Failed to read request body: " + e.getMessage());
        }
    }

    private static final Logger log = Logger.getGlobal();
    private static final byte[] ROOT_RESOURCE = "Hello World\n".getBytes(forName("UTF-8"));
    private static final byte[] EMPTY_RESPONSE_BODY = new byte[0];
    private static final InetSocketAddress ADDRESS = new InetSocketAddress("0.0.0.0", 9000);
    private static final int BACKLOG = 10;
    private static final String ROOT_CONTEXT_PATH = "/";
    private static final String GET = "GET";
    private static final String HEAD = "HEAD";
    private static final String OPTIONS = "OPTIONS";
    private static final String ALLOW = "Allow";
    private static final String ALLOWED_METHODS = "GET, OPTIONS";
    private static final String CONTENT_TYPE = "Content-Type";
    private static final String TEXT_PLAIN = "text/plain; charset=utf-8";
    private static final int OK = 200;
    private static final int NOT_FOUND = 404;
    private static final int METHOD_NOT_ALLOWED = 405;
    private static final int NOW = 0;
}
