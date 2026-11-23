import 'dart:math' as math;
import 'dart:typed_data';

/// Texte et réglages à donner à Pocket TTS pour une phrase.
class PocketPrompt {
  const PocketPrompt(this.text, this.maxFrames, this.framesAfterEos);

  final String text;

  /// Limite dure de longueur (Pocket produit 12,5 trames par seconde).
  final int maxFrames;

  /// Trames gardées après la fin de phrase détectée par le modèle.
  final int framesAfterEos;
}

/// Rend une phrase de livre lisible par Pocket TTS. Son vocabulaire n'a ni
/// guillemets typographiques (“ ” ‘ ’), ni points de suspension (…), ni
/// parenthèses : ces signes, partout dans les dialogues, le faisaient
/// dérailler (sons qui ne ressemblent pas à une voix, phrases deux fois trop
/// longues). [allowed] : caractères connus du modèle (tirés de vocab.json) ;
/// tout autre signe devient une espace.
String pocketCleanText(String text, Set<String> allowed) {
  var t = text
      .replaceAll(RegExp('[“”„«»"]'), '')
      .replaceAll(RegExp('[‘’‛`´]'), "'")
      .replaceAll('…', '...')
      .replaceAll(RegExp(r'\s*[—–]\s*'), ', ')
      .replaceAll(RegExp(r'\s*[()\[\]{}]\s*'), ', ');
  if (allowed.isNotEmpty) {
    final b = StringBuffer();
    for (final r in t.runes) {
      final c = String.fromCharCode(r);
      b.write(c == ' ' || allowed.contains(c) ? c : ' ');
    }
    t = b.toString();
  }
  t = t
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r' ([,.!?;:])'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r',\s*([,.!?])'), (m) => m[1]!);
  return t.replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');
}

/// Prépare une phrase comme le fait le logiciel officiel de Kyutai : sans
/// ça, une phrase très courte (« Yes. », « Chapitre un ») ne s'arrête pas et
/// Pocket produit jusqu'à 30 s de bruits qui ne ressemblent pas à une voix.
///  - ponctuation finale ajoutée si elle manque ;
///  - moins de 5 mots : 8 espaces devant (le modèle trouve alors la fin) ;
///  - longueur plafonnée d'après le nombre de lettres, avec de la marge.
PocketPrompt pocketPrompt(String sentence) {
  var t = sentence.trim();
  if (t.isEmpty) return const PocketPrompt('', 25, 3);
  t = t[0].toUpperCase() + t.substring(1);
  if (!'.!?'.contains(t[t.length - 1])) t = '$t.';
  final words = t.split(RegExp(r'\s+')).length;
  final maxFrames = math.max(25, ((t.length / 9.0 + 2.0) * 12.5).round());
  if (words < 5) t = '        $t';
  return PocketPrompt(t, maxFrames, words <= 4 ? 3 : 1);
}

/// Ramène le silence du début à [leadMs] et celui de la fin à [trailMs]
/// (pause naturelle entre deux phrases), avec un fondu très court aux
/// coupures pour éviter les clics. Rien n'est coupé dans la voix elle-même :
/// seul ce qui reste sous ~−40 dB (fenêtres de 10 ms) avant le premier son et
/// après le dernier est retiré.
Float32List trimSilence(Float32List samples, int sampleRate,
    {int leadMs = 60, int trailMs = 200, double threshold = 0.01}) {
  final n = samples.length;
  final win = math.max(1, sampleRate ~/ 100);
  if (n < win * 3) return samples;

  bool loud(int start) {
    final end = math.min(n, start + win);
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += samples[i] * samples[i];
    }
    return math.sqrt(sum / (end - start)) > threshold;
  }

  var first = -1;
  for (var s = 0; s < n; s += win) {
    if (loud(s)) {
      first = s;
      break;
    }
  }
  if (first < 0) return samples; // que du silence : on n'y touche pas
  var last = first;
  for (var s = ((n - 1) ~/ win) * win; s >= first; s -= win) {
    if (loud(s)) {
      last = math.min(n, s + win);
      break;
    }
  }

  final start = math.max(0, first - leadMs * sampleRate ~/ 1000);
  final end = math.min(n, last + trailMs * sampleRate ~/ 1000);
  if (start == 0 && end == n) return samples;

  final out = Float32List.fromList(samples.sublist(start, end));
  final fade = math.min(out.length ~/ 2, sampleRate * 5 ~/ 1000); // 5 ms
  for (var i = 0; i < fade; i++) {
    final g = i / fade;
    if (start > 0) out[i] *= g;
    if (end < n) out[out.length - 1 - i] *= g;
  }
  return out;
}

/// Baisse tout le volume si une crête dépasse [ceiling] : évite la
/// saturation (craquements) sans déformer la voix.
Float32List limitPeaks(Float32List samples, {double ceiling = 0.97}) {
  var peak = 0.0;
  for (final v in samples) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  if (peak <= ceiling || peak == 0) return samples;
  final g = ceiling / peak;
  final out = Float32List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    out[i] = samples[i] * g;
  }
  return out;
}
