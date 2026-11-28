import 'dart:convert';
import 'dart:io';

import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/server/client_bundle.dart';
import 'package:battletech_combat_helper_v2/server/game_server.dart';

void main() {
  late Directory parent;
  late String web;
  late GameServer server;
  late HttpClient client;

  setUp(() async {
    // A stand-in for client/build/web, beside a file it must not serve.
    parent = await Directory.systemTemp.createTemp('client_web');
    web = '${parent.path}/web';
    await Directory('$web/canvaskit').create(recursive: true);
    await File('$web/index.html').writeAsString('<p>client</p>');
    await File('$web/main.dart.js').writeAsString('main();');
    await File('$web/canvaskit/canvaskit.wasm').writeAsBytes([0, 97]);
    await File('${parent.path}/secret.txt').writeAsString('nope');

    server = GameServer(
      bundle: ClientBundle(web),
      welcome: (player) => WelcomeMessage(
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
    await parent.delete(recursive: true);
  });

  Future<(int, String, ContentType?)> get(String path) async {
    final request = await client.get('127.0.0.1', server.port, path);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (response.statusCode, body, response.headers.contentType);
  }

  Future<WebSocket> connect(int player) => WebSocket.connect(
    'ws://127.0.0.1:${server.port}${ClientPaths.playerSocket(player)}',
  );

  test('player pages and the bare address get the client index', () async {
    for (final path in ['/', '/player/1', '/player/2']) {
      final (status, body, type) = await get(path);
      expect(status, 200, reason: path);
      expect(body, '<p>client</p>');
      expect(type?.mimeType, 'text/html');
    }
    expect((await get('/player/3')).$1, 404);
  });

  test('serves the build files with their types', () async {
    final (status, body, type) = await get('/main.dart.js');
    expect(status, 200);
    expect(body, 'main();');
    expect(type?.mimeType, 'text/javascript');
    expect(
      (await get('/canvaskit/canvaskit.wasm')).$3?.mimeType,
      'application/wasm',
    );
    expect((await get('/nope.js')).$1, 404);
  });

  test('never serves files outside the build', () async {
    expect((await get('/../secret.txt')).$1, 404);
    expect((await get('/%2e%2e/secret.txt')).$1, 404);
    final bundle = ClientBundle(web);
    expect(bundle.fileFor('/../secret.txt'), isNull);
    expect(bundle.fileFor('/canvaskit/../../secret.txt'), isNull);
    expect(bundle.fileFor('/canvaskit/../main.dart.js'), isNotNull);
  });

  test('locate prefers the configured folder', () {
    expect(ClientBundle.locate(configured: web).root, web);
  });

  test(
    'a page socket gets its welcome and phase, and counts as joined',
    () async {
      final presence = <List<int>>[];
      final sub = server.presence.listen(presence.add);

      final socket = await connect(1);
      final messages = socket
          .map(
            (m) => ServerMessage.fromJson(
              jsonDecode(m as String) as Map<String, Object?>,
            ),
          )
          .asBroadcastStream();
      final first = await messages.take(2).toList();
      final welcome = first[0] as WelcomeMessage;
      expect(welcome.player, 1);
      expect(welcome.skirmishName, 'Test Skirmish');
      expect(welcome.lanceName, 'Bravo');
      expect((first[1] as PhaseMessage).phase, GamePhase.lobby);
      expect(server.connected, [0, 1]);

      server.setPhase(GamePhase.playing);
      expect(((await messages.first) as PhaseMessage).phase, GamePhase.playing);

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
