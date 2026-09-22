import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef LocalApiHandler = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> request,
);

/// Transport only. It cannot dispatch arbitrary libXray methods or save assets.
final class LocalApiServer {
  static const apiVersion = 1;
  static const maximumBodyBytes = 16 * 1024 * 1024;

  final String Function() token;
  final bool Function() available;
  final Future<Map<String, dynamic>> Function() info;
  final LocalApiHandler validate;
  final LocalApiHandler compile;
  final Duration bodyTimeout;
  HttpServer? _server;
  Completer<void>? _operation;

  LocalApiServer({
    required this.token,
    required this.available,
    required this.info,
    required this.validate,
    required this.compile,
    this.bodyTimeout = const Duration(seconds: 15),
  });

  bool get listening => _server != null;
  int? get port => _server?.port;
  Future<void> get drained => _operation?.future ?? Future.value();

  /// Binding is separate so a failed preferences write can discard the socket
  /// without replacing the currently configured listener.
  static Future<HttpServer> bind(int port) =>
      HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: false);

  void attach(HttpServer server) {
    final previous = _server;
    _server = server;
    server.idleTimeout = const Duration(seconds: 10);
    server.serverHeader = null;
    server.listen(
      (request) => unawaited(_handle(request, server)),
      onError: (Object _) {
        if (identical(_server, server)) _server = null;
        unawaited(server.close(force: true));
      },
      onDone: () {
        if (identical(_server, server)) _server = null;
      },
    );
    if (previous != null) unawaited(previous.close(force: true));
  }

  Future<void> close() async {
    final previous = _server;
    _server = null;
    await previous?.close(force: true);
    // Closing HTTP does not cancel a native check already admitted.
  }

  Future<void> _handle(HttpRequest request, HttpServer owner) async {
    Completer<void>? operation;
    try {
      if (!identical(owner, _server)) {
        throw const _HttpFailure(
          503,
          'unavailable',
          'Local API is unavailable',
        );
      }
      if (request.headers.value(HttpHeaders.hostHeader) !=
              '127.0.0.1:${owner.port}' ||
          request.uri.hasScheme ||
          request.uri.hasAuthority ||
          request.uri.hasQuery) {
        throw const _HttpFailure(400, 'request', 'Invalid local API address');
      }
      // This interface is for native clients, not websites, including sites
      // which try to address loopback through DNS rebinding or a null origin.
      if (request.headers['origin'] != null) {
        throw const _HttpFailure(
          403,
          'origin',
          'Browser requests are not allowed',
        );
      }
      final supplied = request.headers[HttpHeaders.authorizationHeader];
      if (supplied == null ||
          supplied.length != 1 ||
          !_matches('Bearer ${token()}', supplied.single) ||
          token().isEmpty) {
        throw const _HttpFailure(
          401,
          'authentication',
          'Local API token is invalid',
        );
      }
      if (!available()) {
        throw const _HttpFailure(
          503,
          'unavailable',
          'App services are not ready',
        );
      }
      final path = request.uri.path;
      if (path == '/api/v1/info') {
        if (request.method != 'GET') {
          throw const _HttpFailure(405, 'method', 'Use GET for this endpoint');
        }
        await _respond(request, 200, {
          'apiVersion': apiVersion,
          ...await info(),
        });
        return;
      }
      if (path != '/api/v1/config/validate' &&
          path != '/api/v1/config/compile') {
        throw const _HttpFailure(404, 'endpoint', 'Unknown local API endpoint');
      }
      if (request.method != 'POST') {
        throw const _HttpFailure(405, 'method', 'Use POST for this endpoint');
      }
      if (request.headers.contentType?.mimeType != 'application/json') {
        throw const _HttpFailure(415, 'contentType', 'Use application/json');
      }
      if (_operation != null) {
        throw const _HttpFailure(
          409,
          'busy',
          'Another configuration request is running',
        );
      }
      operation = Completer<void>();
      _operation = operation;
      if (request.contentLength > maximumBodyBytes) {
        throw const _HttpFailure(
          413,
          'size',
          'Configuration request is too large',
        );
      }
      var oversized = false;
      final bytes = await request
          .fold<BytesBuilder>(BytesBuilder(copy: false), (bytes, chunk) {
            oversized =
                oversized || bytes.length + chunk.length > maximumBodyBytes;
            // Do not throw inside the stream consumer: cancellation can close
            // HttpRequest's socket before the client receives the 413 response.
            if (!oversized) bytes.add(chunk);
            return bytes;
          })
          .timeout(bodyTimeout);
      if (oversized) {
        throw const _HttpFailure(
          413,
          'size',
          'Configuration request is too large',
        );
      }
      // Recheck credentials and lifecycle after reading the body: the user may
      // have reset the token or disabled the listener while it was arriving.
      if (!identical(owner, _server) || !available()) {
        throw const _HttpFailure(
          503,
          'unavailable',
          'Local API is unavailable',
        );
      }
      if (!_matches('Bearer ${token()}', supplied.single)) {
        throw const _HttpFailure(
          401,
          'authentication',
          'Local API token is invalid',
        );
      }
      final dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      } on FormatException {
        throw const _HttpFailure(
          400,
          'request',
          'Request body must be a JSON object',
        );
      }
      if (decoded is! Map<String, dynamic> ||
          !const [
            'outbound',
            'routing',
            'advanced-routing',
            'raw',
          ].contains(decoded['kind']) ||
          decoded['text'] is! String ||
          (decoded.containsKey('name') && decoded['name'] is! String)) {
        throw const _HttpFailure(
          400,
          'request',
          'Provide a supported kind and original text',
        );
      }
      final response = await (path.endsWith('/validate') ? validate : compile)(
        decoded,
      );
      await _respond(request, 200, response);
    } on _HttpFailure catch (failure) {
      await _respondFailure(
        request,
        failure.status,
        failure.code,
        failure.message,
      );
    } on TimeoutException {
      await _respondFailure(request, 408, 'timeout', 'Request body timed out');
    } catch (_) {
      // Do not log request bodies, headers or arbitrary exception strings.
      // Configuration diagnostics are explicitly returned by the handler.
      await _respondFailure(
        request,
        500,
        'internal',
        'Local API request failed',
      );
    } finally {
      if (operation != null) {
        _operation = null;
        operation.complete();
      }
    }
  }

  static bool _matches(String expected, String actual) {
    if (expected.length != actual.length) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
    }
    return difference == 0;
  }

  Future<void> _respondFailure(
    HttpRequest request,
    int status,
    String code,
    String message,
  ) => _respond(request, status, {
    'apiVersion': apiVersion,
    'status': 'notRun',
    'stage': 'input',
    'diagnostics': [
      {'code': code, 'message': message},
    ],
  });

  Future<void> _respond(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = request.response;
      response.statusCode = status;
      response.persistentConnection = false;
      response.headers.contentType = ContentType.json;
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      if (status == 401) {
        response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
      }
      final encoded = utf8.encode(jsonEncode(body));
      response.contentLength = encoded.length;
      response.add(encoded);
      await response.close().timeout(const Duration(seconds: 5));
    } catch (_) {
      // A disconnected client does not turn an already completed check into an
      // unhandled zone error, and never cancels another client's native call.
    }
  }
}

final class _HttpFailure implements Exception {
  final int status;
  final String code;
  final String message;
  const _HttpFailure(this.status, this.code, this.message);
}
