// File: lib/net/client_protocol.dart
// What the game server and the phone clients agree on: the URL paths and
// the JSON messages the server sends over a player's WebSocket. Pure Dart,
// so the Flutter Web client can use it when it replaces the placeholder
// pages.
//
// Players are numbered from 0 in code (as in Skirmish.player) and from 1
// in URLs and on screen.

/// URL paths served by the game server.
abstract final class ClientPaths {
  /// The page a player opens on their phone.
  static String playerPage(int player) => '/player/${player + 1}';

  /// The WebSocket a player's page connects to.
  static String playerSocket(int player) => '/ws/player/${player + 1}';

  /// The player of a [playerPage] path, or null for any other path.
  static int? parsePlayerPage(String path) => _parse(path, '/player/');

  /// The player of a [playerSocket] path, or null for any other path.
  static int? parsePlayerSocket(String path) => _parse(path, '/ws/player/');

  static int? _parse(String path, String prefix) {
    if (!path.startsWith(prefix)) return null;
    final n = int.tryParse(path.substring(prefix.length));
    return n == null || n < 1 ? null : n - 1;
  }
}

/// Messages from the server to a player's page. Each is a JSON object with
/// a `type` field.
abstract final class ServerMessages {
  static const typeWelcome = 'welcome';
  static const typePhase = 'phase';

  /// Phases sent in a [phase] message. Placeholders until the game state
  /// machine defines the real ones.
  static const phaseLobby = 'lobby';
  static const phasePlaying = 'playing';

  /// Sent once when a page connects: who the page belongs to.
  static Map<String, Object?> welcome({
    required int player,
    required String skirmishName,
    String? lanceName,
  }) => {
    'type': typeWelcome,
    'player': player,
    'skirmishName': skirmishName,
    'lanceName': lanceName,
  };

  /// Sent when the game moves to another phase, and to pages that connect
  /// later.
  static Map<String, Object?> phase(String phase) => {
    'type': typePhase,
    'phase': phase,
  };
}
