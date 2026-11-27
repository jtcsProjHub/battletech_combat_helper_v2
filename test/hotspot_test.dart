import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/server/host_config.dart';
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
    }) {
      calls = [];
      return NmcliHotspot(
        const HostConfig(hotspotConnection: 'BT'),
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

    test('an unreadable password is left out', () async {
      final info = await hotspot(secrets: 'Battletech\n\n').start();
      expect(info.password, isNull);
    });
  });
}
