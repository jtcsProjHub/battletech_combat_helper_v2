// File: lib/player_connection.dart
// The page's WebSocket to the game server. Keeps the latest welcome and
// phase, and reconnects after a drop (phones sleep and wander off the
// hotspot).

import 'dart:async';
import 'dart:convert';

import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { connecting, connected, reconnecting }

/// Opens a channel to [url]; completes once it is open.
typedef SocketConnector = Future<StreamChannel<dynamic>> Function(Uri url);

Future<StreamChannel<dynamic>> connectWebSocket(Uri url) async {
  final channel = WebSocketChannel.connect(url);
  await channel.ready;
  return channel;
}

class PlayerConnection extends ChangeNotifier {
  PlayerConnection(
    this.url, {
    SocketConnector connect = connectWebSocket,
    this.retryDelay = const Duration(seconds: 2),
  }) : _connect = connect;

  final Uri url;
  final Duration retryDelay;
  final SocketConnector _connect;

  ConnectionStatus _status = ConnectionStatus.connecting;
  ConnectionStatus get status => _status;

  /// The last welcome, kept across reconnects.
  WelcomeMessage? _welcome;
  WelcomeMessage? get welcome => _welcome;

  GamePhase? _phase;
  GamePhase? get phase => _phase;

  StreamChannel<dynamic>? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  bool _disposed = false;

  void start() => _open();

  Future<void> _open() async {
    final StreamChannel<dynamic> channel;
    try {
      channel = await _connect(url);
    } on Object {
      _dropped();
      return;
    }
    if (_disposed) {
      await channel.sink.close();
      return;
    }
    _channel = channel;
    _set(ConnectionStatus.connected);
    _subscription = channel.stream.listen(
      _receive,
      onDone: _dropped,
      onError: (Object _) => _dropped(),
      cancelOnError: true,
    );
  }

  void _receive(dynamic data) {
    if (data is! String) return;
    final Object? json;
    try {
      json = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (json is! Map<String, Object?>) return;
    switch (ServerMessage.fromJson(json)) {
      case WelcomeMessage m:
        _welcome = m;
      case PhaseMessage m:
        _phase = m.phase;
      case null:
        return;
    }
    notifyListeners();
  }

  void _dropped() {
    if (_disposed) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _set(ConnectionStatus.reconnecting);
    _retry?.cancel();
    _retry = Timer(retryDelay, _open);
  }

  void _set(ConnectionStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
