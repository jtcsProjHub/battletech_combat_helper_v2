// File: lib/server/game_server.dart
// HTTP and WebSocket server for the players' phones. Serves the phone
// client (the Flutter Web build in client/) and keeps a WebSocket open to
// each player's page, so the server can push messages and see who is
// connected. Plain dart:io with no Flutter, so it can be tested with real
// sockets.
//
// Every page path (/ and /player/N) gets the client's index.html. The
// client reads its player from the URL. Other paths are the build's files.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:battletech_logic/battletech_logic.dart';

import 'client_bundle.dart';

class GameServer {
  GameServer({
    required this.bundle,
    required this.welcome,
    this.playerCount = 2,
  });

  /// The phone client's web build.
  final ClientBundle bundle;

  /// The welcome message for a player, built when their page connects.
  final WelcomeMessage Function(int player) welcome;
  final int playerCount;

  HttpServer? _http;
  late final List<Set<WebSocket>> _sockets = [
    for (var i = 0; i < playerCount; i++) <WebSocket>{},
  ];
  final _presence = StreamController<List<int>>.broadcast();
  GamePhase _phase = GamePhase.lobby;

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
    // Gzip for browsers that accept it; CanvasKit's wasm shrinks a lot.
    http.autoCompress = true;
    _http = http;
    http.listen(_handle, onError: (Object e) => log('Game server error: $e'));
  }

  /// Sets the phase and sends it to every page. Pages that connect later
  /// get it after their welcome.
  void setPhase(GamePhase phase) {
    _phase = phase;
    _broadcast(PhaseMessage(phase));
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
    final response = request.response;
    try {
      final socketPlayer = ClientPaths.parsePlayerSocket(path);
      if (_isPlayer(socketPlayer) &&
          WebSocketTransformer.isUpgradeRequest(request)) {
        _accept(socketPlayer!, await WebSocketTransformer.upgrade(request));
        return;
      }
      if (request.method == 'GET' || request.method == 'HEAD') {
        final pagePlayer = ClientPaths.parsePlayerPage(path);
        final file = path == '/' || _isPlayer(pagePlayer)
            ? bundle.indexFile
            : bundle.fileFor(path);
        if (file != null && file.existsSync()) {
          return ClientBundle.serve(file, response);
        }
      }
      response.statusCode = HttpStatus.notFound;
      await response.close();
    } on Object catch (e) {
      log('Game server could not answer $path: $e');
    }
  }

  bool _isPlayer(int? player) =>
      player != null && player >= 0 && player < playerCount;

  void _accept(int player, WebSocket socket) {
    if (_http == null) {
      socket.close(WebSocketStatus.goingAway);
      return;
    }
    // Notices phones that drop off the network without closing.
    socket.pingInterval = const Duration(seconds: 5);
    _sockets[player].add(socket);
    _emit();
    socket.add(jsonEncode(welcome(player).toJson()));
    socket.add(jsonEncode(PhaseMessage(_phase).toJson()));
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

  void _broadcast(ServerMessage message) {
    final text = jsonEncode(message.toJson());
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
