// File: lib/server/hotspot.dart
// Turns the laptop's WiFi hotspot on and off. On Linux this brings a
// NetworkManager connection profile up and down with nmcli. When the
// hotspot goes down, NetworkManager reconnects to the usual network.
// Windows comes later behind the same interface.

import 'dart:async';
import 'dart:io';

import 'package:battletech_logic/battletech_logic.dart';

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

/// Runs nmcli, turning failures to start it and timeouts into
/// [HotspotException]s.
class Nmcli {
  Nmcli({ProcessRunner? run}) : _run = run ?? Process.run;

  final ProcessRunner _run;

  Future<ProcessResult> call(
    List<String> args, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await _run('nmcli', args).timeout(timeout);
    } on ProcessException catch (e) {
      throw HotspotException('nmcli could not be run.', e.message);
    } on TimeoutException {
      // Not the arguments: they can hold the password.
      throw const HotspotException('nmcli timed out.');
    }
  }

  /// stderr and stdout, for a [HotspotException]'s details.
  static String output(ProcessResult r) => [
    r.stderr,
    r.stdout,
  ].map((o) => '$o'.trim()).where((o) => o.isNotEmpty).join('\n');

  /// nmcli -g escapes ':' and '\' in values.
  static String unescape(String s) =>
      s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
}

/// Reads and writes the network name and password stored in a hotspot
/// profile.
abstract class HotspotProfiles {
  /// Throws a [HotspotException] when the profile is missing or unreadable.
  Future<HotspotNetwork> read(String connection);

  /// Writes [network] into the profile. A null password leaves the
  /// profile's password as it is. Takes effect the next time the hotspot
  /// starts. Throws a [HotspotException] when it fails.
  Future<void> write(String connection, HotspotNetwork network);

  factory HotspotProfiles.forPlatform() => Platform.isLinux
      ? NmcliHotspotProfiles(Nmcli())
      : const UnsupportedHotspotProfiles();
}

class UnsupportedHotspotProfiles implements HotspotProfiles {
  const UnsupportedHotspotProfiles();

  static final _error = HotspotException(
    'Hotspot profiles are not supported on ${Platform.operatingSystem} yet.',
  );

  @override
  Future<HotspotNetwork> read(String connection) async => throw _error;

  @override
  Future<void> write(String connection, HotspotNetwork network) async =>
      throw _error;
}

class NmcliHotspotProfiles implements HotspotProfiles {
  NmcliHotspotProfiles(this._nmcli);

  final Nmcli _nmcli;

  @override
  Future<HotspotNetwork> read(String connection) async {
    // -s shows the stored password. It comes back empty when the password
    // is kept in a keyring agent instead of the profile.
    final r = await _nmcli([
      '-s',
      '-g',
      '802-11-wireless.ssid,802-11-wireless-security.psk',
      'connection',
      'show',
      connection,
    ]);
    if (r.exitCode != 0) {
      throw HotspotException(
        'Could not read the hotspot profile "$connection".',
        Nmcli.output(r),
      );
    }
    final lines = (r.stdout as String).split('\n').map(Nmcli.unescape).toList();
    final ssid = lines.isNotEmpty ? lines[0] : '';
    final password = lines.length > 1 ? lines[1] : '';
    return HotspotNetwork(
      ssid: ssid.isEmpty ? connection : ssid,
      password: password.isEmpty ? null : password,
    );
  }

  @override
  Future<void> write(String connection, HotspotNetwork network) async {
    final password = network.password;
    final r = await _nmcli([
      'connection',
      'modify',
      connection,
      '802-11-wireless.ssid',
      network.ssid,
      if (password != null) ...[
        '802-11-wireless-security.key-mgmt',
        'wpa-psk',
        '802-11-wireless-security.psk',
        password,
      ],
    ]);
    if (r.exitCode != 0) {
      throw HotspotException(
        'Could not save the network to the hotspot profile "$connection".',
        Nmcli.output(r),
      );
    }
  }
}

/// Linux: the hotspot is a NetworkManager profile, set up once by hand
/// (see [HostConfig.hotspotConnection]). Its network name and password are
/// edited in the settings menu (see [HotspotProfiles]).
class NmcliHotspot implements Hotspot {
  NmcliHotspot(this.config, {ProcessRunner? run}) : _nmcli = Nmcli(run: run);

  final HostConfig config;
  final Nmcli _nmcli;

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
        Nmcli.output(up),
      );
    }

    final address = await _address();
    if (address == null) {
      throw HotspotException(
        'The hotspot "$_name" is on, but it has no IPv4 address.',
      );
    }

    // Shown to the players. If it can't be read, they ask the host.
    HotspotNetwork network;
    try {
      network = await NmcliHotspotProfiles(_nmcli).read(_name);
    } on HotspotException {
      network = HotspotNetwork(ssid: _name);
    }
    return HotspotInfo(
      ssid: network.ssid,
      password: network.password,
      address: address,
    );
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
}

/// The first address in nmcli's IP4.ADDRESS output, e.g.
/// "10.42.0.1/24" or "10.42.0.1/24 | 192.168.5.1/24".
InternetAddress? parseNmcliAddress(String output) {
  final first = output.trim().split('|').first.trim().split('/').first;
  return first.isEmpty ? null : InternetAddress.tryParse(first);
}
