import 'offline_dictionary_service.dart';

/// Mots (en minuscules) de [words] présents dans le dictionnaire de [lang].
typedef KnownWords = Future<Set<String>> Function(Set<String> words, String lang);

/// Nettoie le texte juste avant la synthèse vocale, pour que la voix lise
/// « waaaiiit » comme « wait » et « becuase » comme « because ».
///
/// Règle d'or : un mot remplacé par exactement un mot, espaces intacts — le
/// surlignage mot par mot compte les mots du texte prononcé.
class SpeechTextNormalizer {
  SpeechTextNormalizer(this._known);

  static final SpeechTextNormalizer instance =
      SpeechTextNormalizer(OfflineDictionaryService.instance.knownWords);

  final KnownWords _known;
  final Map<String, String> _memo = {};

  static final _word = RegExp(r'\p{L}+', unicode: true);
  static final _stretchRun = RegExp(r'(\p{L})\1{2,}', unicode: true);
  static final _glue = RegExp(r"[\p{L}\p{N}'’\-‐]", unicode: true);

  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz';
  static const _accents = {
    'fr': 'àâäçéèêëîïôöùûüÿœæ',
    'pt': 'áàâãçéêíóôõú',
    'es': 'áéíóúñü',
  };

  Future<String> normalize(String text, String lang) async {
    final tokens = <RegExpMatch>[
      // Les morceaux de mots composés (aujourd'hui, peut-être, l'homme…) et
      // les mots collés à des chiffres restent intacts : hors contexte, une
      // moitié de mot ressemble à une faute.
      for (final m in _word.allMatches(text))
        if (!_glued(text, m.start - 1) && !_glued(text, m.end)) m,
    ];
    final pending = <String>{
      for (final m in tokens)
        if (!_memo.containsKey('$lang|${m[0]}') && _worthChecking(m[0]!)) m[0]!,
    };
    if (pending.isNotEmpty) await _resolve(pending, lang);

    var changed = false;
    final out = StringBuffer();
    var last = 0;
    for (final m in tokens) {
      final fixed = _memo['$lang|${m[0]}'];
      if (fixed == null || fixed == m[0]) continue;
      out
        ..write(text.substring(last, m.start))
        ..write(fixed);
      last = m.end;
      changed = true;
    }
    if (!changed) return text;
    out.write(text.substring(last));
    return out.toString();
  }

  static bool _glued(String text, int i) =>
      i >= 0 && i < text.length && _glue.hasMatch(text[i]);

  /// Allongés (« noooo »), ou en minuscules et assez longs pour être une
  /// faute de frappe. Les mots avec une majuscule (noms, sigles) ne sont
  /// corrigés que s'ils sont allongés (« NOOOO »).
  static bool _worthChecking(String w) =>
      _stretchRun.hasMatch(w.toLowerCase()) ||
      (w == w.toLowerCase() && w.length >= 4 && w.length <= 20);

  Future<void> _resolve(Set<String> words, String lang) async {
    final stretched = <String, List<String>>{};
    final plain = <String>{};
    for (final w in words) {
      final lower = w.toLowerCase();
      if (_stretchRun.hasMatch(lower)) {
        stretched[w] = stretchCandidates(lower);
      } else {
        plain.add(lower);
      }
    }

    final known = await _safeKnown({...plain, for (final c in stretched.values) ...c}, lang);

    stretched.forEach((w, candidates) {
      final pick = candidates.firstWhere(known.contains, orElse: () => collapseRuns(w.toLowerCase()));
      _remember(lang, w, matchCase(w, pick));
    });

    final unknown = plain.difference(known);
    for (final w in plain.intersection(known)) {
      _remember(lang, w, w);
    }
    if (unknown.isEmpty) return;

    // Sans dictionnaire installé, cette recherche revient vide aussitôt et
    // les mots restent tels quels.
    final variantsOf = {for (final w in unknown) w: editVariants(w, lang)};
    final knownVariants =
        await _safeKnown({for (final v in variantsOf.values) ...v}, lang);
    variantsOf.forEach((w, variants) {
      final hits = variants.where(knownVariants.contains).toSet();
      // Une seule correction possible : on l'applique ; plusieurs (ou aucune) :
      // on ne devine pas, le mot reste tel quel.
      _remember(lang, w, hits.length == 1 ? hits.first : w);
    });
  }

  Future<Set<String>> _safeKnown(Set<String> words, String lang) async {
    if (words.isEmpty) return {};
    try {
      return await _known(words, lang);
    } catch (_) {
      return {};
    }
  }

  void _remember(String lang, String word, String fixed) {
    if (_memo.length > 20000) _memo.clear();
    _memo['$lang|$word'] = fixed;
  }

  /// « waaaiiit » → waaiit, waait, waiit, wait : chaque série de 3 lettres
  /// identiques ou plus est réduite à 2 puis à 1 lettre, les doubles
  /// d'abord (« goooood » → good avant god).
  static List<String> stretchCandidates(String lower) {
    final runs = _stretchRun.allMatches(lower).toList();
    if (runs.length > 4) return [collapseRuns(lower)];
    final out = <String>[];
    for (var mask = 0; mask < (1 << runs.length); mask++) {
      final b = StringBuffer();
      var last = 0;
      for (var r = 0; r < runs.length; r++) {
        final m = runs[r];
        b
          ..write(lower.substring(last, m.start))
          ..write(m[1]! * ((mask >> r) & 1 == 0 ? 2 : 1));
        last = m.end;
      }
      b.write(lower.substring(last));
      out.add(b.toString());
    }
    return out;
  }

  static String collapseRuns(String lower) =>
      lower.replaceAllMapped(_stretchRun, (m) => m[1]!);

  /// Variantes à une faute près : lettre en moins, en trop, remplacée, ou
  /// deux lettres voisines inversées.
  static Set<String> editVariants(String w, String lang) {
    final letters = '$_alphabet${_accents[lang] ?? ''}'.split('');
    final out = <String>{};
    for (var i = 0; i <= w.length; i++) {
      final a = w.substring(0, i), b = w.substring(i);
      if (b.isNotEmpty) out.add(a + b.substring(1));
      if (b.length > 1) out.add(a + b[1] + b[0] + b.substring(2));
      for (final c in letters) {
        if (b.isNotEmpty) out.add(a + c + b.substring(1));
        out.add(a + c + b);
      }
    }
    out.remove(w);
    return out;
  }

  static String matchCase(String original, String fixed) {
    if (original.length > 1 && original == original.toUpperCase()) {
      return fixed.toUpperCase();
    }
    if (original[0] != original[0].toLowerCase()) {
      return fixed[0].toUpperCase() + fixed.substring(1);
    }
    return fixed;
  }
}
