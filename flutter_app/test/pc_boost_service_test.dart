import 'package:flutter_test/flutter_test.dart';
import 'package:talktome/services/pc_boost_service.dart';

void main() {
  group('migrateHosts', () {
    test('ajoute Home Connections devant l\'ancien /talktome', () {
      expect(
        PcBoostService.migrateHosts('192.168.0.18, https://pc.tail1.ts.net/talktome'),
        '192.168.0.18, https://pc.tail1.ts.net, https://pc.tail1.ts.net/talktome',
      );
    });
    test('ne duplique pas une adresse déjà présente', () {
      const h = 'https://pc.tail1.ts.net, https://pc.tail1.ts.net/talktome/';
      expect(PcBoostService.migrateHosts(h), h);
      expect(PcBoostService.migrateHosts(PcBoostService.migrateHosts(h)), h);
    });
    test('laisse les adresses Wi-Fi telles quelles', () {
      expect(PcBoostService.migrateHosts('192.168.0.18:47815'), '192.168.0.18:47815');
    });
  });

  group('hubLlmFromPing', () {
    Map<String, Object> ping(String state) => {
          'ok': true,
          'services': {
            'llm': {'state': state},
            'tts': {'state': 'ready'},
          },
        };
    test('prête, endormie, en chargement ou arrêtée = utilisable', () {
      for (final s in ['ready', 'asleep', 'loading', 'off']) {
        expect(PcBoostService.hubLlmFromPing(ping(s)), isTrue, reason: s);
      }
    });
    test('absente du PC = pas d\'IA', () {
      expect(PcBoostService.hubLlmFromPing(ping('missing')), isFalse);
    });
    test('réponse invalide = pas Home Connections', () {
      expect(PcBoostService.hubLlmFromPing({'ok': false}), isNull);
      expect(PcBoostService.hubLlmFromPing('x'), isNull);
      expect(PcBoostService.hubLlmFromPing({'ok': true}), isNull);
    });
  });
}
