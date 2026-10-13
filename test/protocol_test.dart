import 'package:flutter_test/flutter_test.dart';
import 'package:rtc/models/devices.dart';
import 'package:rtc/models/envelope.dart';
import 'package:rtc/models/ice_config.dart';

void main() {
  test('Envelope: parse, fraîcheur, rejet', () {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final env = Envelope.tryParse(
        {'v': 1, 'ts': now, 'sid': 'abc', 'type': 'bye', 'data': {}});
    expect(env!.isFresh, isTrue);
    expect(Envelope.tryParse({'v': 1, 'ts': now - 60, 'type': 'x'})!.isFresh,
        isFalse);
    expect(Envelope.tryParse({'type': 'bye'}), isNull);
    expect(Envelope('bye', {}, sid: 's').toJson()['v'], 1);
  });

  test('Device: parsing tolérant et conservation des caps', () {
    final d = Device.fromState('cam-1', {
      'name': 'Entrée',
      'online': true,
      'busy': false,
      'viewer': null,
      'kind': 'relay',
      'caps': {'cmds': ['flip']},
    });
    expect(d.caps.cmds, ['flip']);
    d.applyState({'online': false}); // pas de caps : conservées
    expect(d.online, isFalse);
    expect(d.caps.cmds, ['flip']);
    expect(d.name, 'Entrée');
  });

  test('IceConfig: TURN sans identifiants, message invalide ignoré', () {
    final c = IceConfig.tryParse({
      'turn': {'urls': ['turn:x:3478']}
    });
    expect(c!.servers.single.containsKey('username'), isFalse);
    expect(IceConfig.tryParse('nope'), isNull);
    expect(IceConfig.tryParse({}), isNull);
  });
}
