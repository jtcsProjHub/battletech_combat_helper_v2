// File: lib/settings/hotspot_network.dart
// The hotspot's WiFi network name and password. They live in the
// NetworkManager profile itself, not in the app settings: the settings menu
// reads them from the profile and writes them back on Save. Server only.

class HotspotNetwork {
  const HotspotNetwork({required this.ssid, this.password});

  final String ssid;

  /// Null when the profile has none, or it can't be read (secrets kept in a
  /// keyring agent instead of the profile).
  final String? password;

  /// WiFi network names are at most 32 bytes.
  static bool isValidSsid(String ssid) =>
      ssid.isNotEmpty && ssid.codeUnits.length <= 32;

  /// WPA2 passphrases are 8 to 63 characters.
  static bool isValidPassword(String password) =>
      password.length >= 8 && password.length <= 63;

  @override
  bool operator ==(Object other) =>
      other is HotspotNetwork &&
      other.ssid == ssid &&
      other.password == password;

  @override
  int get hashCode => Object.hash(ssid, password);
}
