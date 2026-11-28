// File: lib/server/host_config.dart
// Server-only settings for hosting a game that are not tied to one
// skirmish. Fixed defaults for now; the server settings menu will edit and
// save them later.

class HostConfig {
  const HostConfig({
    this.hotspotConnection = 'BattleTech-Hotspot',
    this.port = 8080,
    this.ssid,
    this.password,
    this.clientWebRoot,
  });

  /// The NetworkManager connection profile that runs the hotspot (Linux).
  final String hotspotConnection;

  /// Port the player pages are served on. Ports below 1024 need root on
  /// Linux, so the URL carries the port.
  final int port;

  /// Network name and password shown to the players. When null they are
  /// read from the hotspot profile.
  final String? ssid;
  final String? password;

  /// Folder of the phone client's web build. When null it is searched for
  /// (see ClientBundle.locate).
  final String? clientWebRoot;
}
