import 'package:battletech_logic/battletech_logic.dart';
import 'package:test/test.dart';

void main() {
  test('paths round-trip from 0-based players to 1-based URLs', () {
    expect(ClientPaths.playerPage(0), '/player/1');
    expect(ClientPaths.playerSocket(1), '/ws/player/2');
    expect(ClientPaths.parsePlayerPage('/player/2'), 1);
    expect(ClientPaths.parsePlayerSocket('/ws/player/1'), 0);
    expect(ClientPaths.parsePlayerPage('/player/0'), isNull);
    expect(ClientPaths.parsePlayerPage('/player/x'), isNull);
    expect(ClientPaths.parsePlayerPage('/'), isNull);
  });

  test('messages round-trip through JSON', () {
    const welcome = WelcomeMessage(
      player: 1,
      skirmishName: 'Test',
      lanceName: 'Bravo',
    );
    final decoded = ServerMessage.fromJson(welcome.toJson());
    expect(decoded, isA<WelcomeMessage>());
    decoded as WelcomeMessage;
    expect(decoded.player, 1);
    expect(decoded.skirmishName, 'Test');
    expect(decoded.lanceName, 'Bravo');

    final phase = ServerMessage.fromJson(
      const PhaseMessage(GamePhase.playing).toJson(),
    );
    expect((phase as PhaseMessage).phase, GamePhase.playing);
  });

  test('unknown types and phases are tolerated', () {
    expect(ServerMessage.fromJson({'type': 'later'}), isNull);
    final phase = ServerMessage.fromJson({'type': 'phase', 'phase': 'new'});
    expect((phase as PhaseMessage).phase, isNull);
  });
}
