// File: lib/main.dart
// Phone client for Combat Helper. The desktop app serves this web build
// over its hotspot at /player/N; the page connects back to the server's
// WebSocket for that player. Build it with scripts/build_client.sh.

import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'client_target.dart';
import 'client_theme.dart';
import 'player_connection.dart';
import 'screens/player_screen.dart';
import 'screens/seat_picker_screen.dart';

void main() {
  runApp(ClientApp(target: ClientTarget.fromUri(Uri.base)));
}

class ClientApp extends StatefulWidget {
  const ClientApp({super.key, required this.target, this.connect});

  final ClientTarget target;

  /// Replaces the WebSocket in tests.
  final SocketConnector? connect;

  @override
  State<ClientApp> createState() => _ClientAppState();
}

class _ClientAppState extends State<ClientApp> {
  PlayerConnection? _connection;

  @override
  void initState() {
    super.initState();
    final player = widget.target.player;
    if (player != null) {
      _connection = PlayerConnection(
        widget.target.socketUrl(player),
        connect: widget.connect ?? connectWebSocket,
      )..start();
    }
  }

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }

  /// Loads the player's page. Keeps the query, so the development
  /// overrides (see ClientTarget) carry over.
  void _pick(int player) {
    final query = Uri.base.hasQuery ? '?${Uri.base.query}' : '';
    web.window.location.assign('${ClientPaths.playerPage(player)}$query');
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.target.player;
    return MaterialApp(
      title: 'Combat Helper',
      debugShowCheckedModeBanner: false,
      theme: buildClientTheme(),
      home: player == null
          ? SeatPickerScreen(playerCount: 2, onPick: _pick)
          : PlayerScreen(player: player, connection: _connection!),
    );
  }
}
