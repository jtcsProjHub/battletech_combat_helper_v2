import 'dart:convert';

import 'package:battletech_client/client_target.dart';
import 'package:battletech_client/client_theme.dart';
import 'package:battletech_client/player_connection.dart';
import 'package:battletech_client/screens/player_screen.dart';
import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';

void main() {
  group('ClientTarget', () {
    test('reads the player and server from the served URL', () {
      final t = ClientTarget.fromUri(
        Uri.parse('http://10.42.0.1:8080/player/2#/'),
      );
      expect(t.player, 1);
      expect(t.socketUrl(1).toString(), 'ws://10.42.0.1:8080/ws/player/2');
    });

    test('the query stands in during development', () {
      final t = ClientTarget.fromUri(
        Uri.parse('http://localhost:5000/?player=1&server=10.42.0.1:8080'),
      );
      expect(t.player, 0);
      expect(t.serverAuthority, '10.42.0.1:8080');
    });

    test('no player at the bare address', () {
      expect(ClientTarget.fromUri(Uri.parse('http://h:1/')).player, isNull);
    });
  });

  group('PlayerConnection', () {
    late List<StreamChannelController<dynamic>> opened;
    late PlayerConnection connection;

    setUp(() {
      opened = [];
      connection = PlayerConnection(
        Uri.parse('ws://h/ws/player/1'),
        retryDelay: const Duration(milliseconds: 10),
        connect: (_) async {
          final c = StreamChannelController<dynamic>();
          opened.add(c);
          return c.local;
        },
      )..start();
    });

    tearDown(() => connection.dispose());

    void send(StreamChannelController<dynamic> c, ServerMessage m) =>
        c.foreign.sink.add(jsonEncode(m.toJson()));

    test('takes the welcome and phase, then reconnects after a drop', () async {
      await pumpEventQueue();
      expect(connection.status, ConnectionStatus.connected);

      send(
        opened.single,
        const WelcomeMessage(player: 0, skirmishName: 'S', lanceName: 'Alpha'),
      );
      send(opened.single, const PhaseMessage(GamePhase.lobby));
      await pumpEventQueue();
      expect(connection.welcome?.lanceName, 'Alpha');
      expect(connection.phase, GamePhase.lobby);

      await opened.single.foreign.sink.close();
      await pumpEventQueue();
      expect(connection.status, ConnectionStatus.reconnecting);
      // The welcome is kept while reconnecting.
      expect(connection.welcome?.lanceName, 'Alpha');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(opened, hasLength(2));
      expect(connection.status, ConnectionStatus.connected);
    });

    test('ignores messages it cannot read', () async {
      await pumpEventQueue();
      opened.single.foreign.sink
        ..add('not json')
        ..add(jsonEncode({'type': 'later'}));
      await pumpEventQueue();
      expect(connection.welcome, isNull);
      expect(connection.status, ConnectionStatus.connected);
    });
  });

  testWidgets('the player screen shows the lance, connection, and phase', (
    tester,
  ) async {
    late StreamChannelController<dynamic> server;
    final connection = PlayerConnection(
      Uri.parse('ws://h/ws/player/2'),
      connect: (_) async {
        server = StreamChannelController<dynamic>();
        return server.local;
      },
    );
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildClientTheme(),
        home: PlayerScreen(player: 1, connection: connection),
      ),
    );
    expect(find.text('PLAYER 2'), findsOneWidget);
    expect(find.text('Connecting…'), findsOneWidget);

    await tester.runAsync(() async {
      connection.start();
      await pumpEventQueue();
      server.foreign.sink
        ..add(
          jsonEncode(
            const WelcomeMessage(
              player: 1,
              skirmishName: 'Night Raid',
              lanceName: 'Bravo',
            ).toJson(),
          ),
        )
        ..add(jsonEncode(const PhaseMessage(GamePhase.playing).toJson()));
      await pumpEventQueue();
    });
    await tester.pump();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('NIGHT RAID'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text('The game has started.'), findsOneWidget);
  });
}
