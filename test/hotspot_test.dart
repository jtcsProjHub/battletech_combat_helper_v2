import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_logic/battletech_logic.dart';
import 'package:battletech_combat_helper_v2/server/hotspot.dart';

void main() {
  test('WiFi QR text escapes special characters', () {
    expect(
      wifiQrPayload('Battletech', 'pa;ss:w"d'),
      r'WIFI:T:WPA;S:Battletech;P:pa\;ss\:w\"d;;',
    );
    expect(wifiQrPayload('Open', null), 'WIFI:T:nopass;S:Open;;');
  });

  test('reads the first address from nmcli output', () {
    expect(parseNmcliAddress('10.42.0.1/24\n')?.address, '10.42.0.1');
    expect(
      parseNmcliAddress('10.42.0.1/24 | 192.168.5.1/24')?.address,
      '10.42.0.1',
    );
    expect(parseNmcliAddress(''), isNull);
  });

  group('NmcliHotspot', () {
    late List<List<String>> calls;

    NmcliHotspot hotspot({
      int upExit = 0,
      String secrets = 'Battletech\npw\\:1\n',
      HostConfig config = const HostConfig(hotspotConnection: 'BT'),
    }) {
      calls = [];
      return NmcliHotspot(
        config,
        run: (exe, args) async {
          calls.add(args);
          if (args.contains('up')) {
            return ProcessResult(0, upExit, '', upExit == 0 ? '' : 'no device');
          }
          if (args.contains('IP4.ADDRESS')) {
            return ProcessResult(0, 0, '10.42.0.1/24\n', '');
          }
          if (args.contains('-s')) return ProcessResult(0, 0, secrets, '');
          return ProcessResult(0, 0, '', '');
        },
      );
    }

    test('brings the profile up and reads the network', () async {
      final h = hotspot();
      final info = await h.start();
      expect(calls.first, ['connection', 'up', 'BT']);
      expect(info.ssid, 'Battletech');
      expect(info.password, 'pw:1');
      expect(info.address.address, '10.42.0.1');

      await h.stop();
      expect(calls.last, ['connection', 'down', 'BT']);
    });

    test('a failed up is reported with nmcli output', () async {
      expect(
        hotspot(upExit: 4).start(),
        throwsA(
          isA<HotspotException>().having(
            (e) => e.details,
            'details',
            'no device',
          ),
        ),
      );
    });

    test('starting does not modify the profile', () async {
      await hotspot().start();
      expect(calls.any((c) => c.contains('modify')), isFalse);
    });

    test('an unreadable password is left out', () async {
      final info = await hotspot(secrets: 'Battletech\n\n').start();
      expect(info.password, isNull);
    });
  });

  group('NmcliHotspotProfiles', () {
    late List<List<String>> calls;

    NmcliHotspotProfiles profiles({int exit = 0, String out = ''}) {
      calls = [];
      return NmcliHotspotProfiles(
        Nmcli(
          run: (exe, args) async {
            calls.add(args);
            return ProcessResult(0, exit, out, exit == 0 ? '' : 'unknown');
          },
        ),
      );
    }

    test('reads the network name and password', () async {
      final n = await profiles(out: 'Field\\:1\nlongenough\n').read('BT');
      expect(calls.single, [
        '-s',
        '-g',
        '802-11-wireless.ssid,802-11-wireless-security.psk',
        'connection',
        'show',
        'BT',
      ]);
      expect(n, const HotspotNetwork(ssid: 'Field:1', password: 'longenough'));
    });

    test('an unreadable password reads as null', () async {
      final n = await profiles(out: 'Field\n\n').read('BT');
      expect(n.password, isNull);
    });

    test('a missing profile is reported', () async {
      expect(profiles(exit: 10).read('BT'), throwsA(isA<HotspotException>()));
    });

    test('writes the network; a null password is left alone', () async {
      final p = profiles();
      await p.write(
        'BT',
        const HotspotNetwork(ssid: 'Field', password: 'longenough'),
      );
      expect(calls.single, [
        'connection',
        'modify',
        'BT',
        '802-11-wireless.ssid',
        'Field',
        '802-11-wireless-security.key-mgmt',
        'wpa-psk',
        '802-11-wireless-security.psk',
        'longenough',
      ]);
      await p.write('BT', const HotspotNetwork(ssid: 'Field'));
      expect(calls.last, [
        'connection',
        'modify',
        'BT',
        '802-11-wireless.ssid',
        'Field',
      ]);
    });

    test('a failed write is reported without the password', () async {
      try {
        await profiles(
          exit: 4,
        ).write('BT', const HotspotNetwork(ssid: 'F', password: 'secretpw'));
        fail('should throw');
      } on HotspotException catch (e) {
        expect(e.toString(), isNot(contains('secretpw')));
      }
    });
  });
}
