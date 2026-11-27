// File: lib/server/hotspot.dart
// Turns the laptop's WiFi hotspot on and off. On Linux this brings a
// NetworkManager connection profile up and down with nmcli. When the
// hotspot goes down, NetworkManager reconnects to the usual network.
// Windows comes later behind the same interface.

import 'dart:async';
import 'dart:io';

import 'host_config.dart';

/// The hotspot's network, once it is up.
class HotspotInfo {
  const HotspotInfo({
    required this.ssid,
    required this.password,
    required this.address,
  });

  final String ssid;

  /// Null when it could not be read from the profile.
  final String? password;

  /// The laptop's address on the hotspot network.
  final InternetAddress address;

  /// Text for a QR code that joins the network when scanned.
  String get qrPayload => wifiQrPayload(ssid, password);
}

/// The standard "WIFI:" QR text. An open network when [password] is null.
String wifiQrPayload(String ssid, String? password) {
  String esc(String s) =>
      s.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');
  return password == null || password.isEmpty
      ? 'WIFI:T:nopass;S:${esc(ssid)};;'
      : 'WIFI:T:WPA;S:${esc(ssid)};P:${esc(password)};;';
}

class HotspotException implements Exception {
  const HotspotException(this.message, [this.details]);

  final String message;

  /// Tool output, for the user to troubleshoot with.
  final String? details;

  @override
  String toString() => details == null ? message : '$message\n$details';
}

abstract class Hotspot {
  /// Turns the hotspot on. Throws a [HotspotException] when it can't.
  Future<HotspotInfo> start();

  /// Turns the hotspot off. Never throws.
  Future<void> stop();

  factory Hotspot.forPlatform(HostConfig config) =>
      Platform.isLinux ? NmcliHotspot(config) : const UnsupportedHotspot();
}

class UnsupportedHotspot implements Hotspot {
  const UnsupportedHotspot();

  @override
  Future<HotspotInfo> start() async => throw HotspotException(
    'Hosting is not supported on ${Platform.operatingSystem} yet.',
  );

  @override
  Future<void> stop() async {}
}

typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> args);

/// Linux: the hotspot is a NetworkManager profile, set up once by hand
/// (see [HostConfig.hotspotConnection]).
class NmcliHotspot implements Hotspot {
  NmcliHotspot(this.config, {ProcessRunner? run}) : _run = run ?? Process.run;

  final HostConfig config;
  final ProcessRunner _run;

  String get _name => config.hotspotConnection;

  @override
  Future<HotspotInfo> start() async {
    final up = await _nmcli([
      'connection',
      'up',
      _name,
    ], timeout: const Duration(seconds: 45));
    if (up.exitCode != 0) {
      throw HotspotException(
        'Could not turn on the hotspot "$_name".',
        _output(up),
      );
    }

    final address = await _address();
    if (address == null) {
      throw HotspotException(
        'The hotspot "$_name" is on, but it has no IPv4 address.',
      );
    }

    var ssid = config.ssid;
    var password = config.password;
    if (ssid == null || password == null) {
      // -s shows the stored password. Fails when it is kept in a keyring
      // agent instead of the profile; the players then ask the host.
      final r = await _nmcli([
        '-s',
        '-g',
        '802-11-wireless.ssid,802-11-wireless-security.psk',
        'connection',
        'show',
        _name,
      ]);
      final lines = r.exitCode == 0
          ? (r.stdout as String).split('\n').map(_unescape).toList()
          : const <String>[];
      ssid ??= lines.isNotEmpty && lines[0].isNotEmpty ? lines[0] : _name;
      password ??= lines.length > 1 && lines[1].isNotEmpty ? lines[1] : null;
    }
    return HotspotInfo(ssid: ssid, password: password, address: address);
  }

  @override
  Future<void> stop() async {
    try {
      await _nmcli(['connection', 'down', _name]);
    } on Object {
      // Already down, or nmcli is gone. Nothing more to do.
    }
  }

  /// The profile's IPv4 address. Retries briefly in case it is assigned
  /// just after activation.
  Future<InternetAddress?> _address() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final r = await _nmcli([
        '-g',
        'IP4.ADDRESS',
        'connection',
        'show',
        _name,
      ]);
      final address = r.exitCode == 0
          ? parseNmcliAddress(r.stdout as String)
          : null;
      if (address != null) return address;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<ProcessResult> _nmcli(
    List<String> args, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await _run('nmcli', args).timeout(timeout);
    } on ProcessException catch (e) {
      throw HotspotException('nmcli could not be run.', e.message);
    } on TimeoutException {
      throw HotspotException('nmcli ${args.join(' ')} timed out.');
    }
  }

  static String _output(ProcessResult r) => [
    r.stderr,
    r.stdout,
  ].map((o) => '$o'.trim()).where((o) => o.isNotEmpty).join('\n');

  /// nmcli -g escapes ':' and '\' in values.
  static String _unescape(String s) =>
      s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
}

/// The first address in nmcli's IP4.ADDRESS output, e.g.
/// "10.42.0.1/24" or "10.42.0.1/24 | 192.168.5.1/24".
InternetAddress? parseNmcliAddress(String output) {
  final first = output.trim().split('|').first.trim().split('/').first;
  return first.isEmpty ? null : InternetAddress.tryParse(first);
}
