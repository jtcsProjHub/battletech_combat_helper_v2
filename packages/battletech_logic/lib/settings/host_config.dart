// File: lib/settings/host_config.dart
// Server-only settings for hosting a game that are not tied to one
// skirmish. Edited on the Server Settings tab and saved with the app
// settings (see app_settings.dart). Never sent to the phones.
//
// The network name and password are not here: they are kept in the
// NetworkManager profile (see hotspot_network.dart).

class HostConfig {
  const HostConfig({
    this.hotspotConnection = defaultConnection,
    this.port = defaultPort,
    this.clientWebRoot,
  });

  static const defaultConnection = 'BattleTech-Hotspot';
  static const defaultPort = 8080;

  /// The NetworkManager connection profile that runs the hotspot (Linux).
  final String hotspotConnection;

  /// Port the player pages are served on. Ports below 1024 need root on
  /// Linux, so the URL carries the port.
  final int port;

  /// Folder of the phone client's web build. When null it is searched for
  /// (see ClientBundle.locate).
  final String? clientWebRoot;

  HostConfig copyWith({String? hotspotConnection, int? port}) => HostConfig(
    hotspotConnection: hotspotConnection ?? this.hotspotConnection,
    port: port ?? this.port,
    clientWebRoot: clientWebRoot,
  );

  Map<String, Object?> toJson() => {
    'hotspotConnection': hotspotConnection,
    'port': port,
    if (clientWebRoot != null) 'clientWebRoot': clientWebRoot,
  };

  /// Keys from older files (ssid, password) are ignored.
  factory HostConfig.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    final connection = _blankToNull(m['hotspotConnection'] as String?);
    final port = (m['port'] as num?)?.toInt();
    return HostConfig(
      hotspotConnection: connection ?? defaultConnection,
      port: port != null && isValidPort(port) ? port : defaultPort,
      clientWebRoot: _blankToNull(m['clientWebRoot'] as String?),
    );
  }

  /// Ports a normal user can listen on.
  static bool isValidPort(int port) => port >= 1024 && port <= 65535;

  static String? _blankToNull(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  @override
  bool operator ==(Object other) =>
      other is HostConfig &&
      other.hotspotConnection == hotspotConnection &&
      other.port == port &&
      other.clientWebRoot == clientWebRoot;

  @override
  int get hashCode => Object.hash(hotspotConnection, port, clientWebRoot);
}
