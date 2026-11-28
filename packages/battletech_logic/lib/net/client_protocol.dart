// File: lib/net/client_protocol.dart
// What the game server and the phone clients agree on: the URL paths and
// the JSON messages the server sends over a player's WebSocket.
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

/// Placeholder game phases, until the game state machine defines the real
/// ones. Unknown names from a newer server decode as null.
enum GamePhase {
  /// Players are joining. The host has not started the game.
  lobby,

  /// The host started the game.
  playing;

  static GamePhase? fromName(String? name) =>
      values.where((p) => p.name == name).firstOrNull;
}

/// A message from the server to a player's page: a JSON object with a
/// `type` field.
sealed class ServerMessage {
  const ServerMessage();

  Map<String, Object?> toJson();

  /// Null for a message type this client does not know.
  static ServerMessage? fromJson(Map<String, Object?> json) =>
      switch (json['type']) {
        WelcomeMessage.type => WelcomeMessage.fromJson(json),
        PhaseMessage.type => PhaseMessage.fromJson(json),
        _ => null,
      };
}

/// Sent once when a page connects: who the page belongs to.
class WelcomeMessage extends ServerMessage {
  const WelcomeMessage({
    required this.player,
    required this.skirmishName,
    this.lanceName,
  });

  static const type = 'welcome';

  final int player;
  final String skirmishName;
  final String? lanceName;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'player': player,
    'skirmishName': skirmishName,
    'lanceName': lanceName,
  };

  factory WelcomeMessage.fromJson(Map<String, Object?> json) => WelcomeMessage(
    player: (json['player'] as num?)?.toInt() ?? 0,
    skirmishName: json['skirmishName'] as String? ?? '',
    lanceName: json['lanceName'] as String?,
  );
}

/// Sent after the welcome, and again whenever the phase changes.
class PhaseMessage extends ServerMessage {
  const PhaseMessage(this.phase);

  static const type = 'phase';

  /// Null when the server sent a phase this client does not know.
  final GamePhase? phase;

  @override
  Map<String, Object?> toJson() => {'type': type, 'phase': phase?.name};

  factory PhaseMessage.fromJson(Map<String, Object?> json) =>
      PhaseMessage(GamePhase.fromName(json['phase'] as String?));
}
