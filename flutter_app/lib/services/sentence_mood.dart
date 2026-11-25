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
      'afraid', 'scared', 'frighten*', 'terrified', 'panic*', 'dread*', 'horror',
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
      'riu', 'ria', 'riram', 'riam', 'rindo', 'sorriu', 'sorria', 'sorriram', 'sorrindo', 'feliz*', 'alegr*',
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

  // Mots qui annulent l'émotion qui suit (« he didn't laugh », « elle ne
  // pleurait pas », « não chorou ») : jusqu'à 3 mots avant l'indice.
  static const _negators = {
    'not', 'no', 'never', 'nobody', 'nothing', 'without', 'didn', 'don', 'doesn',
    'wasn', 'weren', 'couldn', 'wouldn', 'won', 'isn', 'aren', 'hadn', 'hasn',
    'ne', 'n', 'pas', 'jamais', 'sans', 'aucun', 'aucune',
    'não', 'nunca', 'nem', 'sem',
  };

  static Mood classify(String sentence) => read(sentence).mood;

  /// Humeur et force (0,6 = légère, 1,0 = marquée), sans IA.
  static MoodReading read(String sentence) {
    final s = sentence.trim();
    if (s.isEmpty) return const MoodReading(Mood.neutral, 0);
    final words = _letters.allMatches(s.toLowerCase()).map((m) => m[0]!).toList();

    bool matches(String cue, String w) => cue.endsWith('*')
        ? w.startsWith(cue.substring(0, cue.length - 1))
        : w == cue;
    bool negated(int i) {
      for (var k = i - 1; k >= 0 && k >= i - 3; k--) {
        if (_negators.contains(words[k])) return true;
      }
      return false;
    }

    /// Nombre d'indices (non niés) de cette humeur dans la phrase.
    int count(Mood mood) {
      final cues = _cues[mood] ?? const <String>[];
      var n = 0;
      for (var i = 0; i < words.length; i++) {
        if (!negated(i) && cues.any((c) => matches(c, words[i]))) n++;
      }
      return n;
    }

    final bangs = '!'.allMatches(s).length;
    final shouting = _stretched.hasMatch(s.toLowerCase()) || _capsWord.hasMatch(s);
    double strength(int n) => (n >= 2 || bangs >= 2 || shouting) ? 1.0 : 0.6;

    for (final mood in const [Mood.sad, Mood.scared, Mood.angry]) {
      final n = count(mood);
      if (n > 0) return MoodReading(mood, strength(n));
    }
    if (bangs > 0 || shouting) {
      return MoodReading(Mood.excited, strength(0));
    }
    for (final mood in const [Mood.happy, Mood.calm]) {
      final n = count(mood);
      if (n > 0) return MoodReading(mood, strength(n));
    }
    if (s.contains('…') || s.contains('...')) return const MoodReading(Mood.calm, 0.6);
    return const MoodReading(Mood.neutral, 0);
  }
}

// ── Lecture expressive « par scène » ─────────────────────────────────────────

/// Humeur d'une phrase et sa force : 0 (neutre) à 1 (marquée).
class MoodReading {
  const MoodReading(this.mood, this.strength);
  final Mood mood;
  final double strength;

  @override
  bool operator ==(Object other) =>
      other is MoodReading && other.mood == mood && other.strength == strength;
  @override
  int get hashCode => Object.hash(mood, strength);
  @override
  String toString() => '${mood.name}:$strength';
}

/// Valeur rangée dans le cache : « sad:2 » (marquée) ou « sad:1 » (légère).
/// Les anciennes valeurs sans force (« sad ») restent lisibles.
String encodeMoodReading(MoodReading r) => '${r.mood.name}:${r.strength >= 0.8 ? 2 : 1}';

MoodReading? decodeMoodReading(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  final mood = parseMood(parts.first);
  if (mood == null) return null;
  if (mood == Mood.neutral) return const MoodReading(Mood.neutral, 0);
  final level = parts.length > 1 ? int.tryParse(parts[1].trim()) : null;
  return MoodReading(mood, level == 2 ? 1.0 : level == 1 ? 0.6 : 0.8);
}

/// Réponse de l'IA : une ligne « N: humeur force » par phrase (force 1 =
/// légère, 2 = marquée ; absente = moyenne).
List<MoodReading?> parseMoodReadings(String answer, int count) {
  final out = List<MoodReading?>.filled(count, null);
  final line = RegExp(r'^\s*(\d+)\s*[:.)\-]\s*([A-Za-z]+)(?:\s*[,(]?\s*([12]))?',
      multiLine: true);
  for (final m in line.allMatches(answer)) {
    final i = int.parse(m[1]!) - 1;
    if (i < 0 || i >= count || out[i] != null) continue;
    out[i] = decodeMoodReading(m[3] == null ? m[2] : '${m[2]}:${m[3]}');
  }
  return out;
}

/// Réplique d'un personnage (guillemets, tiret de dialogue) plutôt que
/// narration.
bool isDialogue(String sentence) {
  final s = sentence.trimLeft();
  return RegExp(r'["«»“”„]').hasMatch(s) || s.startsWith('—') || s.startsWith('– ') ||
      s.startsWith('- ');
}

/// Transforme les humeurs brutes en une lecture naturelle : le narrateur
/// reste posé (les émotions passent surtout par les répliques), une phrase
/// isolée dont l'humeur tranche avec ses voisines est atténuée, et la
/// vitesse change par paliers au lieu de sauter d'une phrase à l'autre.
class MoodPlanner {
  MoodPlanner._();

  /// Part d'émotion gardée pour la narration (1 pour les répliques).
  static const double narrationShare = 0.5;

  /// Atténuation d'une phrase isolée (humeur différente avant ET après).
  static const double isolatedShare = 0.6;

  /// Écart de vitesse maximal entre deux phrases qui se suivent.
  static const double maxSpeedStep = 0.04;

  /// Intensité finale (0 à 1) de l'humeur de [here].
  static double intensity({
    required MoodReading here,
    MoodReading? previous,
    MoodReading? next,
    required bool dialogue,
    double userIntensity = 1.0,
  }) {
    if (here.mood == Mood.neutral || here.strength <= 0) return 0;
    var i = here.strength * userIntensity;
    if (!dialogue) i *= narrationShare;
    final isolated = previous != null && next != null &&
        previous.mood != here.mood && next.mood != here.mood;
    if (isolated) i *= isolatedShare;
    return i.clamp(0.0, 1.0);
  }

  /// Profil de voix de [mood] à l'intensité [intensity] (0 = neutre).
  static MoodProfile blend(Mood mood, double intensity) {
    final p = mood.profile;
    final k = intensity.clamp(0.0, 1.0);
    return MoodProfile(
      speedFactor: 1 + (p.speedFactor - 1) * k,
      volume: 1 + (p.volume - 1) * k,
      pauseAfterMs: (p.pauseAfterMs * k).round(),
    );
  }

  /// Vitesse rapprochée de la précédente (pas plus de [maxSpeedStep]).
  static double ramp(double target, double? previous) {
    if (previous == null) return target;
    return target.clamp(previous - maxSpeedStep, previous + maxSpeedStep);
  }

  /// Voix capables d'émotion (Qwen3-TTS, Pocket émotionnel) : l'émotion
  /// passe par la voix elle-même ; on garde seulement un peu de rythme et
  /// la pause, sans baisser le volume.
  static MoodProfile forEmotionalVoice(MoodProfile p) => MoodProfile(
        speedFactor: 1 + (p.speedFactor - 1) * 0.4,
        pauseAfterMs: p.pauseAfterMs,
      );
}
