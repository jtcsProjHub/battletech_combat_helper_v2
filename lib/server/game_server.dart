// File: lib/server/game_server.dart
// HTTP and WebSocket server for the players' phones. Serves each player's
// page and keeps a WebSocket open to it, so the server can push messages
// and see who is connected. Plain dart:io with no Flutter, so it can be
// tested with real sockets.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import '../net/client_protocol.dart';
import 'client_pages.dart';

class GameServer {
  GameServer({required this.welcome, this.playerCount = 2});

  /// The welcome message for a player, built when their page connects.
  final Map<String, Object?> Function(int player) welcome;
  final int playerCount;

  HttpServer? _http;
  late final List<Set<WebSocket>> _sockets = [
    for (var i = 0; i < playerCount; i++) <WebSocket>{},
  ];
  final _presence = StreamController<List<int>>.broadcast();
  Map<String, Object?> _phase = ServerMessages.phase(ServerMessages.phaseLobby);

  bool get isRunning => _http != null;

  /// The port actually bound (useful when started on port 0).
  int get port => _http!.port;

  /// Open connections per player. A player can have more than one device.
  List<int> get connected => [for (final s in _sockets) s.length];

  /// Emits [connected] whenever it changes.
  Stream<List<int>> get presence => _presence.stream;

  Future<void> start(InternetAddress address, int port) async {
    if (_http != null) return;
    final http = await HttpServer.bind(address, port);
    _http = http;
    http.listen(_handle, onError: (Object e) => log('Game server error: $e'));
  }

  /// Sets the phase and sends it to every page. Pages that connect later
  /// get it after their welcome.
  void setPhase(String phase) {
    _phase = ServerMessages.phase(phase);
    _broadcast(_phase);
  }

  Future<void> stop() async {
    final http = _http;
    _http = null;
    for (final sockets in _sockets) {
      for (final s in sockets.toList()) {
        await s.close(WebSocketStatus.goingAway);
      }
      sockets.clear();
    }
    _emit();
    await http?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    try {
      final socketPlayer = ClientPaths.parsePlayerSocket(path);
      if (_isPlayer(socketPlayer) &&
          WebSocketTransformer.isUpgradeRequest(request)) {
        _accept(socketPlayer!, await WebSocketTransformer.upgrade(request));
        return;
      }
      if (request.method == 'GET') {
        final pagePlayer = ClientPaths.parsePlayerPage(path);
        if (_isPlayer(pagePlayer)) {
          return _html(request.response, playerPage(pagePlayer!));
        }
        if (path == '/') return _html(request.response, indexPage(playerCount));
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } on Object catch (e) {
      log('Game server could not answer $path: $e');
    }
  }

  bool _isPlayer(int? player) =>
      player != null && player >= 0 && player < playerCount;

  Future<void> _html(HttpResponse response, String body) async {
    response.headers.contentType = ContentType.html;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(body);
    await response.close();
  }

  void _accept(int player, WebSocket socket) {
    if (_http == null) {
      socket.close(WebSocketStatus.goingAway);
      return;
    }
    // Notices phones that drop off the network without closing.
    socket.pingInterval = const Duration(seconds: 5);
    _sockets[player].add(socket);
    _emit();
    socket.add(jsonEncode(welcome(player)));
    socket.add(jsonEncode(_phase));
    void drop() {
      if (_sockets[player].remove(socket)) _emit();
    }

    // Nothing comes from the pages yet; listening detects the close.
    socket.listen(
      (_) {},
      onDone: drop,
      onError: (_) => drop(),
      cancelOnError: true,
    );
  }

  void _broadcast(Map<String, Object?> message) {
    final text = jsonEncode(message);
    for (final sockets in _sockets) {
      for (final s in sockets) {
        s.add(text);
      }
    }
  }

  void _emit() {
    if (!_presence.isClosed) _presence.add(connected);
  }
}
