// File: lib/client_target.dart
// Which player this page is for and where the game server is, read from
// the page's URL. The server serves this app at /player/N, so the path
// names the player and the page's own host is the server.
//
// For development with `flutter run -d chrome` (served from another port,
// at /), the query can stand in: ?player=1&server=10.42.0.1:8080.

import 'package:battletech_logic/battletech_logic.dart';

class ClientTarget {
  const ClientTarget({required this.player, required this.serverAuthority});

  factory ClientTarget.fromUri(Uri page) {
    final query = page.queryParameters;
    final queryPlayer = int.tryParse(query['player'] ?? '');
    return ClientTarget(
      player:
          ClientPaths.parsePlayerPage(page.path) ??
          (queryPlayer != null && queryPlayer >= 1 ? queryPlayer - 1 : null),
      serverAuthority: query['server'] ?? page.authority,
    );
  }

  /// From 0. Null when the URL names no player.
  final int? player;

  /// host:port of the game server.
  final String serverAuthority;

  Uri socketUrl(int player) =>
      Uri.parse('ws://$serverAuthority${ClientPaths.playerSocket(player)}');
}
