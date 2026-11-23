import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talktome/services/audio_cleanup.dart';

/// [silenceBefore] s de silence, [voice] s de son, [silenceAfter] s de silence.
Float32List _clip(int sr, double silenceBefore, double voice, double silenceAfter) {
  final a = (silenceBefore * sr).round();
  final b = (voice * sr).round();
  final c = (silenceAfter * sr).round();
  final out = Float32List(a + b + c);
  for (var i = 0; i < b; i++) {
    out[a + i] = 0.5 * math.sin(2 * math.pi * 220 * i / sr);
  }
  return out;
}

void main() {
  group('trimSilence', () {
    test('ramène les longs silences de Supertonic à une pause naturelle', () {
      const sr = 44100;
      final out = trimSilence(_clip(sr, 0.6, 2.0, 0.9), sr);
      final seconds = out.length / sr;
      // 2 s de voix + 60 ms avant + 200 ms après (à une fenêtre près)
      expect(seconds, closeTo(2.26, 0.03));
    });

    test('ne touche pas un audio déjà serré', () {
      const sr = 24000;
      final input = _clip(sr, 0.02, 1.0, 0.05);
      expect(trimSilence(input, sr).length, input.length);
    });

    test('laisse tel quel un audio entièrement silencieux', () {
      final input = Float32List(24000);
      expect(trimSilence(input, 24000).length, input.length);
    });
  });

  group('limitPeaks', () {
    test('baisse un audio qui sature', () {
      final input = Float32List.fromList([0.1, -1.2, 0.6]);
      final out = limitPeaks(input);
      expect(out.map((v) => v.abs()).reduce(math.max), closeTo(0.97, 1e-6));
    });

    test('laisse un audio normal intact', () {
      final input = Float32List.fromList([0.1, -0.5, 0.6]);
      expect(identical(limitPeaks(input), input), isTrue);
    });
  });

  group('pocketCleanText', () {
    // Caractères ASCII imprimables sauf ( ) # [ ] { } et guillemets droits,
    // comme le vocabulaire de Pocket.
    final allowed = {
      for (var c = 32; c < 127; c++) String.fromCharCode(c),
    }..removeAll(['(', ')', '#', '[', ']', '{', '}', '"']);

    test('dialogue de livre : guillemets typographiques retirés', () {
      expect(pocketCleanText('“Oh!” Larry said. “It’s the sun!”', allowed),
          "Oh! Larry said. It's the sun!");
    });

    test('tirets, parenthèses, points de suspension, signes inconnus', () {
      expect(
          pocketCleanText(
              'Outsmarted (again). Wasn’t the first time…', allowed),
          "Outsmarted, again. Wasn't the first time...");
      expect(pocketCleanText('Warning – hull breach #3.', allowed),
          'Warning, hull breach 3.');
      expect(pocketCleanText('“Three thousand, nine hundre—”', allowed),
          'Three thousand, nine hundre');
    });

    test('sans vocabulaire connu, seule la typographie est simplifiée', () {
      expect(pocketCleanText('“Été” — fin', const {}), 'Été, fin');
    });
  });

  group('pocketPrompt', () {
    test('phrase courte : ponctuation, espaces devant, peu de trames', () {
      final p = pocketPrompt('chapter one');
      expect(p.text, '        Chapter one.');
      expect(p.framesAfterEos, 3);
      expect(p.maxFrames, lessThanOrEqualTo(50));
    });

    test('phrase longue : texte gardé, plafond proportionnel', () {
      const s = 'The ship hummed quietly as the stars drifted past the window.';
      final p = pocketPrompt(s);
      expect(p.text, s);
      expect(p.framesAfterEos, 1);
      // ~6,6 s de marge à 12,5 trames/s : largement assez, jamais 30 s.
      expect(p.maxFrames, inInclusiveRange(80, 120));
    });
  });
}
