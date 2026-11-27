// File: lib/server/skirmish_host.dart
// Hosts one skirmish for the players' phones: turns the hotspot on, serves
// the player pages on it, and turns both off again. The play screen owns
// one while it is open. When the game state machine arrives, its
// initialization state takes over start() and stop().

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/client_protocol.dart';
import '../skirmish/skirmish.dart';
import 'game_server.dart';
import 'host_config.dart';
import 'hotspot.dart';

/// Where the players connect, once hosting is up.
class HostSession {
  const HostSession({required this.network, required this.port});

  final HotspotInfo network;
  final int port;

  /// The page player [player] (from 0) opens on their phone.
  Uri playerUrl(int player) => Uri(
    scheme: 'http',
    host: network.address.address,
    port: port,
    path: ClientPaths.playerPage(player),
  );
}

abstract class SkirmishHost {
  /// Turns hosting on. Throws a [HotspotException] (or a [SocketException]
  /// when the port is taken) when it can't; start can then be retried.
  Future<HostSession> start();

  /// Open connections per player.
  List<int> get connected;

  /// Emits [connected] whenever it changes.
  Stream<List<int>> get presence;

  /// Tells the player pages the game has started.
  void announcePlaying();

  /// Turns hosting off. Safe to call more than once; never throws.
  Future<void> stop();
}

/// Builds the host for a skirmish. Tests override it with a fake so no
/// hotspot or socket is touched.
final skirmishHostFactoryProvider =
    Provider<SkirmishHost Function(Skirmish skirmish)>(
      (ref) =>
          (skirmish) => NetworkSkirmishHost(
            skirmish: skirmish,
            hotspot: Hotspot.forPlatform(const HostConfig()),
          ),
    );

class NetworkSkirmishHost implements SkirmishHost {
  NetworkSkirmishHost({
    required this.skirmish,
    required this.hotspot,
    this.config = const HostConfig(),
  }) {
    _server = GameServer(
      welcome: (player) => ServerMessages.welcome(
        player: player,
        skirmishName: skirmish.name,
        lanceName: skirmish.player(player).lance?.name,
      ),
    );
  }

  final Skirmish skirmish;
  final Hotspot hotspot;
  final HostConfig config;
  late final GameServer _server;
  final _signals = <StreamSubscription<ProcessSignal>>[];
  bool _hotspotRequested = false;

  @override
  List<int> get connected => _server.connected;

  @override
  Stream<List<int>> get presence => _server.presence;

  @override
  Future<HostSession> start() async {
    _watchSignals();
    _hotspotRequested = true;
    final network = await hotspot.start();
    await _server.start(network.address, config.port);
    return HostSession(network: network, port: _server.port);
  }

  @override
  void announcePlaying() => _server.setPhase(ServerMessages.phasePlaying);

  @override
  Future<void> stop() async {
    for (final s in _signals) {
      await s.cancel();
    }
    _signals.clear();
    await _server.stop();
    if (_hotspotRequested) {
      _hotspotRequested = false;
      await hotspot.stop();
    }
  }

  /// Ctrl+C or a kill from the terminal would otherwise leave the hotspot
  /// on. A hard kill (SIGKILL, or stopping the debugger) still can; then
  /// run `nmcli connection down <profile>` by hand.
  void _watchSignals() {
    if (_signals.isNotEmpty || !(Platform.isLinux || Platform.isMacOS)) return;
    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
      _signals.add(
        signal.watch().listen((_) async {
          await stop();
          exit(0);
        }),
      );
    }
  }
}
