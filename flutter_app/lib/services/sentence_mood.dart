import 'dart:convert';

/// Humeur d'une phrase, pour la lecture expressive.
enum Mood { neutral, happy, excited, sad, angry, scared, calm }

/// Comment une humeur se traduit dans la voix. Les moteurs n'ont pas de
/// réglage d'émotion : on joue sur le rythme (demandé au moteur lui-même,
/// donc naturel), le volume et une pause après la phrase. Valeurs
/// volontairement discrètes.
///
/// Pas de changement de timbre : décaler la hauteur après coup, phrase par
/// phrase, donnait des voix bizarrement aiguës ou graves (« distorsion »).
/// [pitchFactor] reste à 1,0 pour toutes les humeurs.
class MoodProfile {
  const MoodProfile({
    this.speedFactor = 1.0,
    this.pitchFactor = 1.0,
    this.volume = 1.0,
    this.pauseAfterMs = 0,
  });

  final double speedFactor;
  final double pitchFactor;
  final double volume;
  final int pauseAfterMs;

  static const MoodProfile neutral = MoodProfile();
}

const Map<Mood, MoodProfile> moodProfiles = {
  Mood.neutral: MoodProfile.neutral,
  Mood.happy: MoodProfile(speedFactor: 1.04),
  Mood.excited: MoodProfile(speedFactor: 1.08),
  Mood.sad: MoodProfile(speedFactor: 0.90, volume: 0.85, pauseAfterMs: 350),
  Mood.angry: MoodProfile(speedFactor: 1.05),
  Mood.scared: MoodProfile(speedFactor: 1.06, volume: 0.9),
  Mood.calm: MoodProfile(speedFactor: 0.94, volume: 0.85, pauseAfterMs: 200),
};

extension MoodVoice on Mood {
  MoodProfile get profile => moodProfiles[this] ?? MoodProfile.neutral;
}

/// Lit un libellé d'humeur (réponse de l'IA ou valeur en cache) ; null si
/// inconnu.
Mood? parseMood(String? label) {
  if (label == null) return null;
  final l = label.trim().toLowerCase();
  for (final m in Mood.values) {
    if (m.name == l) return m;
  }
  const synonyms = {
    'joyful': Mood.happy,
    'cheerful': Mood.happy,
    'surprised': Mood.excited,
    'afraid': Mood.scared,
    'fearful': Mood.scared,
    'tense': Mood.scared,
    'furious': Mood.angry,
    'gentle': Mood.calm,
    'melancholic': Mood.sad,
  };
  return synonyms[l];
}

/// Réponse de l'IA, une ligne « N: humeur » par phrase numérotée à partir
/// de 1. Les lignes manquantes ou illisibles donnent null.
List<Mood?> parseMoodLines(String answer, int count) {
  final out = List<Mood?>.filled(count, null);
  final line = RegExp(r'^\s*(\d+)\s*[:.)\-]\s*([A-Za-z]+)', multiLine: true);
  for (final m in line.allMatches(answer)) {
    final i = int.parse(m[1]!) - 1;
    if (i >= 0 && i < count) out[i] ??= parseMood(m[2]);
  }
  return out;
}

/// Clé du cache d'humeurs (FNV-1a 64 bits sur langue + phrase).
String moodCacheKey(String lang, String sentence) {
  var h = 0xcbf29ce484222325;
  for (final c in utf8.encode('$lang|$sentence')) {
    h ^= c;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return h.toUnsigned(64).toRadixString(16);
}

/// Humeur devinée instantanément, sans IA : verbes et mots qui disent
/// l'émotion (français, anglais, portugais), puis la ponctuation.
class MoodRules {
  MoodRules._();

  // « mot* » = tout mot qui commence ainsi ; sinon le mot exact (les mots
  // courts en préfixe donneraient trop de faux positifs, ex. « chor » → chore).
  static const _cues = <Mood, List<String>>{
    Mood.sad: [
      'pleur*', 'sanglot*', 'larme*', 'triste*', 'chagrin*', 'désespoir', 'deuil',
      'cried', 'crying', 'cries', 'sobb*', 'wept', 'weep*', 'tears', 'sorrow*',
      'grief', 'griev*', 'mourn*', 'heartbroken',
      'chorou', 'chorava', 'chorando', 'chorar', 'lágrima*', 'saudade*', 'luto',
    ],
    Mood.scared: [
      'peur', 'effray*', 'terrifi*', 'trembl*', 'angoiss*', 'paniqu*', 'horreur',
      'afraid', 'scared', 'frighten*', 'terrified', 'panick*', 'dread*', 'horror',
      'medo', 'assustad*', 'aterroriz*', 'pânico', 'tremia', 'tremendo',
    ],
    Mood.angry: [
      'colère', 'furieu*', 'hurla', 'hurlait', 'hurler', 'hurlant', 'cria',
      'criait', 'crier', 'enrag*', 'rage',
      'angry', 'anger', 'angrily', 'furious*', 'shout*', 'yell*', 'scream*',
      'snapped', 'raged',
      'raiva', 'furios*', 'gritou', 'gritava', 'gritar', 'gritando', 'zangad*',
    ],
    Mood.happy: [
      'rit', 'riait', 'rire', 'rires', 'riant', 'sourit', 'souriait', 'souriant',
      'joie*', 'heureu*', 'ravie', 'ravi',
      'laugh*', 'smil*', 'happy', 'happily', 'joy*', 'delight*', 'cheerful*',
      'riu', 'ria', 'rindo', 'sorriu', 'sorria', 'sorrindo', 'feliz*', 'alegr*',
    ],
    Mood.calm: [
      'chuchot*', 'murmur*', 'doucement', 'calme*', 'paisibl*',
      'whisper*', 'softly', 'gently', 'calm*', 'quietly',
      'sussurr*', 'baixinho', 'suavemente', 'calma*',
    ],
  };

  static final _letters = RegExp(r'\p{L}+', unicode: true);
  static final _stretched = RegExp(r'(\p{L})\1\1', unicode: true);
  static final _capsWord = RegExp(r'(?<!\p{L})\p{Lu}{4,}(?!\p{L})', unicode: true);

  static Mood classify(String sentence) {
    final s = sentence.trim();
    if (s.isEmpty) return Mood.neutral;
    final words = _letters.allMatches(s.toLowerCase()).map((m) => m[0]!).toList();

    bool has(Mood mood) => (_cues[mood] ?? const []).any((cue) => cue.endsWith('*')
        ? words.any((w) => w.startsWith(cue.substring(0, cue.length - 1)))
        : words.contains(cue));

    if (has(Mood.sad)) return Mood.sad;
    if (has(Mood.scared)) return Mood.scared;
    if (has(Mood.angry)) return Mood.angry;
    if (s.contains('!') || _stretched.hasMatch(s.toLowerCase()) || _capsWord.hasMatch(s)) {
      return Mood.excited;
    }
    if (has(Mood.happy)) return Mood.happy;
    if (has(Mood.calm)) return Mood.calm;
    if (s.contains('…') || s.contains('...')) return Mood.calm;
    return Mood.neutral;
  }
}
