import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/net/client_protocol.dart';
import 'package:battletech_combat_helper_v2/server/game_server.dart';

void main() {
  late GameServer server;
  late HttpClient client;

  setUp(() async {
    server = GameServer(
      welcome: (player) => ServerMessages.welcome(
        player: player,
        skirmishName: 'Test Skirmish',
        lanceName: player == 0 ? 'Alpha' : 'Bravo',
      ),
    );
    await server.start(InternetAddress.loopbackIPv4, 0);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  Future<(int, String)> get(String path) async {
    final request = await client.get('127.0.0.1', server.port, path);
    final response = await request.close();
    return (response.statusCode, await response.transform(utf8.decoder).join());
  }

  Future<WebSocket> connect(int player) => WebSocket.connect(
    'ws://127.0.0.1:${server.port}${ClientPaths.playerSocket(player)}',
  );

  test('paths round-trip from 0-based players to 1-based URLs', () {
    expect(ClientPaths.playerPage(0), '/player/1');
    expect(ClientPaths.parsePlayerPage('/player/2'), 1);
    expect(ClientPaths.parsePlayerSocket('/ws/player/1'), 0);
    expect(ClientPaths.parsePlayerPage('/player/0'), isNull);
    expect(ClientPaths.parsePlayerPage('/player/x'), isNull);
  });

  test('serves each player page and 404s the rest', () async {
    final (status, body) = await get('/player/2');
    expect(status, 200);
    expect(body, contains('Player 2'));
    expect(body, contains('/ws/player/2'));
    expect((await get('/')).$2, contains('/player/1'));
    expect((await get('/player/3')).$1, 404);
    expect((await get('/nope')).$1, 404);
  });

  test(
    'a page socket gets its welcome and phase, and counts as joined',
    () async {
      final presence = <List<int>>[];
      final sub = server.presence.listen(presence.add);

      final socket = await connect(1);
      final messages = socket
          .map((m) => jsonDecode(m as String))
          .asBroadcastStream();
      final first = await messages.take(2).toList();
      expect(first[0], {
        'type': 'welcome',
        'player': 1,
        'skirmishName': 'Test Skirmish',
        'lanceName': 'Bravo',
      });
      expect(first[1], {'type': 'phase', 'phase': 'lobby'});
      expect(server.connected, [0, 1]);

      server.setPhase(ServerMessages.phasePlaying);
      expect(await messages.first, {'type': 'phase', 'phase': 'playing'});

      await socket.close();
      await Future.doWhile(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return server.connected[1] != 0;
      }).timeout(const Duration(seconds: 2));
      expect(presence.first, [0, 1]);
      expect(presence.last, [0, 0]);
      await sub.cancel();
    },
  );

  test('stop closes the player sockets', () async {
    final socket = await connect(0);
    final done = socket.drain<void>();
    await server.stop();
    await done.timeout(const Duration(seconds: 2));
    expect(server.connected, [0, 0]);
    expect(server.isRunning, isFalse);
  });
}
