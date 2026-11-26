import 'number_words.dart';

/// Texte prêt à être dit, et pour chaque mot dit, le mot du livre dont il
/// vient (pour garder le surlignage juste quand « E = mc² » devient « E
/// equals m c squared »).
class SpokenText {
  const SpokenText(this.text, this.sourceWord, this.originalWordCount);

  /// Texte envoyé à la voix, avec des marques de pause `[[pause:350]]`.
  final String text;

  /// Pour chaque mot dit (hors marques de pause), l'index du mot du livre.
  final List<int> sourceWord;

  /// Nombre de mots du texte d'origine (séparés par des espaces).
  final int originalWordCount;

  /// Début de chaque mot du livre, à partir du début de chaque mot dit. Un
  /// mot du livre sans mot dit (fusionné dans le précédent, ex. « 000 » de
  /// « 1 000 ») prend le début du mot dit le plus proche avant lui.
  List<double> mapStarts(List<double> spokenStarts) {
    if (spokenStarts.length != sourceWord.length) return const [];
    final out = List<double?>.filled(originalWordCount, null);
    for (var i = 0; i < spokenStarts.length; i++) {
      final src = sourceWord[i];
      if (src < originalWordCount) out[src] ??= spokenStarts[i];
    }
    double last = spokenStarts.isEmpty ? 0 : spokenStarts.first;
    return [
      for (final v in out) last = v ?? last,
    ];
  }
}

/// Marque de pause insérée dans le texte dit (millisecondes).
String pauseMarker(int ms) => '[[pause:$ms]]';
final RegExp pauseMarkerPattern = RegExp(r'\[\[pause:(\d+)\]\]');

/// Transforme ce qui n'est pas un mot ordinaire en ce qu'un lecteur dirait :
/// abréviations (Dr., M., Sra.), chiffres romains (Louis XIV), nombres,
/// prix, heures, ordinaux, températures, unités, symboles mathématiques,
/// adresses web et e-mails — en anglais, français et portugais — et ajoute
/// de vraies pauses (tirets, points de suspension, parenthèses).
class SpeechExpander {
  SpeechExpander._();

  /// [lang] : code de la voix (« en-US », « fr-FR », « pt-BR », « pt-PT »).
  static SpokenText expand(String text, String lang) {
    final l = _Lang(lang);
    final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final units = _group(tokens, l);
    final words = <String>[];
    final source = <int>[];
    for (var u = 0; u < units.length; u++) {
      final unit = units[u];
      final out = _expandUnit(
        unit.text,
        prev: u > 0 ? units[u - 1].text : null,
        next: u + 1 < units.length ? units[u + 1].text : null,
        first: u == 0,
        last: u == units.length - 1,
        l: l,
      );
      for (final w in out.split(RegExp(r'\s+'))) {
        if (w.isEmpty) continue;
        words.add(w);
        if (!pauseMarkerPattern.hasMatch(w)) source.add(unit.first);
      }
    }
    // Pas de pause au tout début ni à la toute fin (la phrase s'en charge).
    while (words.isNotEmpty && pauseMarkerPattern.hasMatch(words.first)) {
      words.removeAt(0);
    }
    while (words.isNotEmpty && pauseMarkerPattern.hasMatch(words.last)) {
      words.removeLast();
    }
    return SpokenText(words.join(' '), source, tokens.length);
  }

  /// Silence voulu après la phrase, selon sa ponctuation finale : plus long
  /// après des points de suspension, un peu plus après « ? » ou « ! ».
  static int trailingPauseMs(String sentence) {
    final s = sentence.trimRight().replaceAll(RegExp(r'''["'’”»)\]]+$'''), '');
    if (s.endsWith('…') || s.endsWith('...')) return 750;
    if (s.endsWith('?') || s.endsWith('!')) return 420;
    if (s.endsWith(':')) return 400;
    if (s.endsWith('.') || s.endsWith(';')) return 340;
    if (s.endsWith(',')) return 200;
    return 140; // morceau d'une longue phrase coupée
  }

  /// Vrai si [sentence] a été coupée à tort après une abréviation (« Mr. »,
  /// « Dr. », « M. », « e.g. », initiale « J. ») et doit être recollée à
  /// [next].
  static bool continuesAfter(String sentence, String next) {
    final words = sentence.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || next.trim().isEmpty) return false;
    final lastWord = words.last.replaceAll(RegExp(r'''^["'“«(]+'''), '');
    final nextStart = next.trimLeft().replaceAll(RegExp(r'''^["'“«(]+'''), '');
    final upperNext = nextStart.isNotEmpty &&
        (RegExp(r'^\p{Lu}', unicode: true).hasMatch(nextStart) || RegExp(r'^\d').hasMatch(nextStart));
    if (_alwaysContinue.contains(lastWord.toLowerCase())) return true;
    if (_titlesWithDot.contains(lastWord) && upperNext) return true;
    // Initiale isolée (« J. K. Rowling ») : seulement pour un fragment court,
    // pour ne pas recoller « … le plan A. Puis … ».
    if (RegExp(r'^\p{Lu}\.$', unicode: true).hasMatch(lastWord) && upperNext && words.length <= 2) {
      return true;
    }
    return false;
  }

  static const _titlesWithDot = {
    'Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.', 'St.', 'Mt.', 'Sr.', 'Sra.', 'Srta.', 'Dra.',
    'Profa.', 'M.', 'MM.', 'Mme.', 'Mlle.', 'Pr.', 'D.', 'Sto.', 'Sta.', 'Gen.', 'Capt.',
    'Lt.', 'Sgt.', 'Col.', 'Gov.', 'Rev.', 'No.', 'Fig.', 'Vol.', 'Ch.', 'Chap.', 'Ste.',
  };
  static const _alwaysContinue = {'e.g.', 'i.e.', 'vs.', 'cf.', 'p.', 'pp.', 'n°', 'nº', 'n.º', 'ex.'};

  // ── Regroupement des mots qui forment une seule chose ─────────────────────

  static final _num = RegExp(r'^[+\-−]?\d');
  static final _thousandGroup = RegExp(r'^\d{3}(?:[.,]\d+)?[^\p{L}\p{N}]*$', unicode: true);
  static final _unitToken = RegExp(
      r'^(%|‰|€|\$|£|¥|°[CF]?|°|h|km/h|km²|m²|m³|cm²|km|cm|mm|kg|mg|ml|cl|dl|min|mph|m|g|l|L|s)[.,;:!?…)»”"]*$');

  static List<_Unit> _group(List<String> tokens, _Lang l) {
    final units = <_Unit>[];
    var i = 0;
    while (i < tokens.length) {
      var text = tokens[i];
      final first = i;
      i++;
      // « R$ 10,50 », « US$ 5 »
      if ((text == 'R\$' || text == 'US\$' || text == '\$' || text == '€' || text == '£') &&
          i < tokens.length && _num.hasMatch(tokens[i])) {
        text = '$text${tokens[i]}';
        i++;
      }
      if (_num.hasMatch(text)) {
        // « 1 000 000 » (français, portugais)
        while (!l.en && i < tokens.length && RegExp(r'^[+\-−]?[\d ]*\d{1,3}$').hasMatch(text) &&
            _thousandGroup.hasMatch(tokens[i])) {
          text = '$text${tokens[i]}';
          i++;
        }
        // « 20 % », « 25 °C », « 5,99 € », « 19 h 45 »
        if (i < tokens.length && _unitToken.hasMatch(tokens[i]) && RegExp(r'\d$').hasMatch(text)) {
          text = '$text ${tokens[i]}';
          i++;
          if (text.endsWith(' h') && i < tokens.length && RegExp(r'^\d{2}\b').hasMatch(tokens[i])) {
            text = '$text${tokens[i]}';
            i++;
          }
        }
      }
      units.add(_Unit(text, first));
    }
    return units;
  }

  // ── Un groupe ─────────────────────────────────────────────────────────────

  static final _leadPunct = RegExp(r'''^[\"'“”‘’«»(\[¿¡—–―\-]+''');
  static final _trailPunct = RegExp(r'''[\"'“”‘’«»)\].,;:!?…]+$''');

  static String _expandUnit(String unit,
      {String? prev, String? next, required bool first, required bool last, required _Lang l}) {
    // Groupes faits seulement de ponctuation / symboles.
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(unit)) {
      return _symbolOnly(unit, prev: prev, next: next, first: first, last: last, l: l);
    }
    var lead = _leadPunct.firstMatch(unit)?.group(0) ?? '';
    var rest = unit.substring(lead.length);
    var trail = _trailPunct.firstMatch(rest)?.group(0) ?? '';
    var core = rest.substring(0, rest.length - trail.length);
    if (core.isEmpty) return unit;

    final before = <String>[];
    final after = <String>[];
    if (lead.contains('(') || lead.contains('[')) before.add(pauseMarker(180));
    // Tiret de dialogue en tête : pas prononcé.
    lead = lead.replaceAll(RegExp(r'[—–―\-(\[]'), '');
    if (trail.contains(')') || trail.contains(']')) {
      if (!last) after.add(pauseMarker(180));
      trail = trail.replaceAll(RegExp(r'[)\]]'), '');
    }
    // Points de suspension au milieu de la phrase : vraie pause.
    if (!last && (trail.contains('…') || trail.contains('...'))) {
      trail = trail.replaceAll('...', '').replaceAll('…', '');
      after.add(pauseMarker(500));
    }

    // Abréviations (le point fait partie de l'abréviation).
    final withDot = trail.startsWith('.') ? '$core.' : core;
    final abbr = _abbreviation(withDot, core, next: next, l: l);
    if (abbr != null) {
      if (withDot != core) trail = trail.substring(1);
      // En fin de phrase, garder un point pour l'intonation.
      if (last && trail.isEmpty && withDot != core) trail = '.';
      return _join(before, '$lead$abbr$trail', after);
    }

    final spoken = _core(core, prev: prev, next: next, l: l);
    return _join(before, '$lead$spoken$trail', after);
  }

  static String _join(List<String> before, String middle, List<String> after) =>
      [...before, middle, ...after].join(' ');

  static String _symbolOnly(String unit,
      {String? prev, String? next, required bool first, required bool last, required _Lang l}) {
    final u = unit.trim();
    if (u == '…' || u == '...') return (first || last) ? '' : pauseMarker(500);
    final numbersAround = prev != null && next != null &&
        RegExp(r'\d[^\p{L}]*$', unicode: true).hasMatch(prev) && RegExp(r'^[^\p{L}]*\d').hasMatch(next);
    if (RegExp(r'^[—–―]+$').hasMatch(u) || (u == '-' && !numbersAround)) {
      if (numbersAround && u != '—') return l.minus;
      return (first || last) ? '' : pauseMarker(350);
    }
    final symbol = _symbolWord(u, l, numbersAround: numbersAround);
    return symbol ?? unit;
  }

  static String? _symbolWord(String s, _Lang l, {bool numbersAround = false}) {
    switch (s) {
      case '=': return l.pick('equals', 'égale', 'igual a');
      case '+': return l.pick('plus', 'plus', 'mais');
      case '−': return l.minus;
      case '-': return numbersAround ? l.minus : null;
      case '×':
      case '*': return numbersAround || s == '×' ? l.pick('times', 'fois', 'vezes') : null;
      case 'x': return numbersAround ? l.pick('times', 'fois', 'vezes') : null;
      case '÷': return l.pick('divided by', 'divisé par', 'dividido por');
      case '/': return numbersAround ? l.pick('divided by', 'divisé par', 'dividido por') : null;
      case '±': return l.pick('plus or minus', 'plus ou moins', 'mais ou menos');
      case '≈': return l.pick('approximately', 'environ', 'aproximadamente');
      case '≠': return l.pick('is not equal to', 'différent de', 'diferente de');
      case '<': return l.pick('less than', 'inférieur à', 'menor que');
      case '>': return l.pick('greater than', 'supérieur à', 'maior que');
      case '≤': return l.pick('less than or equal to', 'inférieur ou égal à', 'menor ou igual a');
      case '≥': return l.pick('greater than or equal to', 'supérieur ou égal à', 'maior ou igual a');
      case '&': return l.pick('and', 'et', 'e');
      case '@': return l.pick('at', 'arobase', 'arroba');
      case '%': return l.pick('percent', 'pour cent', 'por cento');
      case '§': return l.pick('section', 'paragraphe', 'parágrafo');
      case '→': return l.pick('to', 'vers', 'para');
      case '∞': return l.pick('infinity', 'l’infini', 'infinito');
      case '√': return l.pick('the square root of', 'racine carrée de', 'raiz quadrada de');
      case 'π': return 'pi';
      case '©': return 'copyright';
      case '™': return 'trademark';
      case '½': return l.pick('one half', 'un demi', 'um meio');
      case '¼': return l.pick('one quarter', 'un quart', 'um quarto');
      case '¾': return l.pick('three quarters', 'trois quarts', 'três quartos');
      case '⅓': return l.pick('one third', 'un tiers', 'um terço');
    }
    return null;
  }

  // ── Abréviations ──────────────────────────────────────────────────────────

  static String? _abbreviation(String withDot, String core, {String? next, required _Lang l}) {
    final nextCap = next != null &&
        RegExp(r'^[«"“(]*\p{Lu}', unicode: true).hasMatch(next);
    final nextDigit = next != null && RegExp(r'^[«"“(]*\d').hasMatch(next);
    if (l.en) {
      const always = {
        'Dr.': 'Doctor', 'Mr.': 'Mister', 'Mrs.': 'Missus', 'Ms.': 'Miz', 'Prof.': 'Professor',
        'Jr.': 'Junior', 'Sr.': 'Senior', 'vs.': 'versus', 'etc.': 'et cetera',
        'e.g.': 'for example', 'i.e.': 'that is', 'approx.': 'approximately', 'Mt.': 'Mount',
        'Lt.': 'Lieutenant', 'Capt.': 'Captain', 'Sgt.': 'Sergeant', 'Gen.': 'General',
        'Gov.': 'Governor', 'Rev.': 'Reverend', 'Ave.': 'Avenue', 'Blvd.': 'Boulevard',
        'Dept.': 'Department', 'Inc.': 'Incorporated', 'Ltd.': 'Limited', 'Jan.': 'January',
        'Feb.': 'February', 'Aug.': 'August', 'Sept.': 'September', 'Oct.': 'October',
        'Nov.': 'November', 'Dec.': 'December', 'a.m.': 'A M', 'p.m.': 'P M', 'U.S.': 'U S',
        'U.K.': 'U K', 'cf.': 'compare',
      };
      if (always.containsKey(withDot)) return always[withDot];
      if (withDot == 'St.') return nextCap ? 'Saint' : 'Street';
      if (withDot == 'No.' && nextDigit) return 'Number';
      if (withDot == 'Fig.' && nextDigit) return 'Figure';
      if (withDot == 'Ch.' && nextDigit) return 'Chapter';
      if (withDot == 'Vol.' && nextDigit) return 'Volume';
      if (withDot == 'p.' && nextDigit) return 'page';
      if (withDot == 'pp.' && nextDigit) return 'pages';
      return null;
    }
    if (l.fr) {
      const always = {
        'Mme': 'Madame', 'Mme.': 'Madame', 'Mmes': 'Mesdames', 'Mlle': 'Mademoiselle',
        'Mlle.': 'Mademoiselle', 'Mlles': 'Mesdemoiselles', 'MM.': 'Messieurs',
        'Dr': 'Docteur', 'Dr.': 'Docteur', 'Pr': 'Professeur', 'Pr.': 'Professeur',
        'etc.': 'etcétéra', 'cf.': 'confer', 'env.': 'environ', 'av.': 'avenue',
        'bd': 'boulevard', 'bd.': 'boulevard', 'Ste': 'Sainte', 'Ste.': 'Sainte',
        'c.-à-d.': 'c’est-à-dire', 'ex.': 'par exemple', 'chap.': 'chapitre',
        'J.-C.': 'Jésus-Christ', 'apr.': 'après', 'vol.': 'volume',
      };
      if (always.containsKey(withDot)) return always[withDot];
      if ((withDot == 'M.' || withDot == 'M') && nextCap) return 'Monsieur';
      if (withDot == 'St' || withDot == 'St.') return nextCap ? 'Saint' : null;
      if ((withDot == 'p.' || withDot == 'p') && nextDigit) return 'page';
      if ((withDot == 'n°' || withDot == 'no' || withDot == 'N°') && nextDigit) return 'numéro';
      if (withDot == 'av.' && next == 'J.-C.') return 'avant';
      return null;
    }
    // Portugais
    const always = {
      'Sr.': 'Senhor', 'Sra.': 'Senhora', 'Srta.': 'Senhorita', 'Dr.': 'Doutor',
      'Dra.': 'Doutora', 'Prof.': 'Professor', 'Profa.': 'Professora', 'Sto.': 'Santo',
      'Sta.': 'Santa', 'etc.': 'et cetera', 'pág.': 'página', 'págs.': 'páginas',
      'Exa.': 'Excelência', 'V.': 'Vossa', 'Av.': 'Avenida', 'ex.': 'exemplo',
      'cap.': 'capítulo', 'a.C.': 'antes de Cristo', 'd.C.': 'depois de Cristo',
    };
    if (always.containsKey(withDot)) return always[withDot];
    if (withDot == 'D.' && nextCap) return 'Dom';
    if ((withDot == 'nº' || withDot == 'n.º' || withDot == 'Nº') && nextDigit) return 'número';
    if ((withDot == 'p.' || withDot == 'pg.') && nextDigit) return 'página';
    return null;
  }

  // ── Le reste : nombres, heures, prix, chiffres romains, maths, adresses ─

  static final _roman = RegExp(r'^M{0,3}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$');
  static const _chapterWords = {
    'chapter', 'part', 'book', 'volume', 'act', 'scene', 'section', 'appendix', 'tome',
    'chapitre', 'partie', 'livre', 'acte', 'scène', 'annexe',
    'capítulo', 'parte', 'livro', 'ato', 'acto', 'cena',
  };

  /// Noms suivis d'un numéro et non d'un rang (« World War II » = « two »).
  static const _numberedThings = {
    'war', 'bowl', 'episode', 'phase', 'type', 'class', 'level', 'stage', 'mark', 'grade',
    'guerre', 'épisode', 'niveau', 'guerra', 'episódio', 'nível', 'fase',
  };

  static int _romanValue(String r) {
    const v = {'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100, 'D': 500, 'M': 1000};
    var total = 0;
    for (var i = 0; i < r.length; i++) {
      final cur = v[r[i]]!;
      final nxt = i + 1 < r.length ? v[r[i + 1]]! : 0;
      total += cur < nxt ? -cur : cur;
    }
    return total;
  }

  static String _core(String core, {String? prev, String? next, required _Lang l}) {
    // Points de suspension ou tiret collés au milieu d'un mot : pause.
    final inner = RegExp(r'(\.\.\.|…|—|–)').firstMatch(core);
    if (inner != null && inner.start > 0 && inner.end < core.length) {
      final pause = inner.group(0)!.contains('.') || inner.group(0) == '…' ? 500 : 350;
      return '${_core(core.substring(0, inner.start), prev: prev, next: next, l: l)} '
          '${pauseMarker(pause)} ${_core(core.substring(inner.end), prev: prev, next: next, l: l)}';
    }

    // Adresse e-mail / web.
    final email = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$').firstMatch(core);
    if (email != null) {
      final parts = core.split('@');
      return '${_spellAddress(parts[0], l)} ${l.pick('at', 'arobase', 'arroba')} ${_spellAddress(parts[1], l)}';
    }
    if (RegExp(r'^(https?://)?(www\.)?[\w\-]+(\.[\w\-]+)*\.(com|org|net|fr|pt|br|ca|io|gov|edu|info|co|uk|eu|be|ch|app|dev)(/\S*)?$',
            caseSensitive: false)
        .hasMatch(core)) {
      return _spellAddress(core.replaceFirst(RegExp(r'^https?://'), ''), l);
    }

    // Opérateurs collés : « E=mc² », « 3+4 ».
    final op = RegExp(r'^(.+?)([=+×÷≈≠≤≥<>])(.+)$').firstMatch(core);
    if (op != null && !core.startsWith('+')) {
      return '${_core(op.group(1)!, prev: prev, next: op.group(2), l: l)} '
          '${_symbolWord(op.group(2)!, l, numbersAround: true)} '
          '${_core(op.group(3)!, prev: op.group(2), next: next, l: l)}';
    }

    // Lettre seule à côté d'un opérateur (« E = mc² », « x + y ») : son nom.
    bool isOp(String? t) => t != null && t.length == 1 && '=+×÷≈≠≤≥<>−'.contains(t);
    if (RegExp(r'^\p{L}$', unicode: true).hasMatch(core) && (isOp(prev) || isOp(next))) {
      return _letterName(core, l);
    }

    // Heures : « 7:45 », « 19h45 », « 19 h 45 », « 19h ».
    final hm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(core) ??
        (l.en ? null : RegExp(r'^(\d{1,2}) ?[hH] ?(\d{2})?$').firstMatch(core));
    if (hm != null) {
      final h = int.parse(hm.group(1)!);
      final m = hm.group(2) == null ? 0 : int.parse(hm.group(2)!);
      if (h < 25 && m < 60) return _time(h, m, l);
    }

    // Prix : « $5.99 », « 5,99 € », « R$ 10,50 ».
    final money = RegExp(r'^(R\$|US\$|\$|€|£|¥)(\d[\d.,\s]*)$').firstMatch(core);
    final money2 = RegExp(r'^(\d[\d.,\s]*?)\s?(€|\$|£|¥)$').firstMatch(core);
    if (money != null) return _money(money.group(2)!, money.group(1)!, l);
    if (money2 != null) return _money(money2.group(1)!, money2.group(2)!, l);

    // Nombre + unité / pourcentage / degrés.
    final unit = RegExp(r'^([+\-−]?\d[\d.,\s]*?)\s?(%|‰|°[CF]?|km/h|km²|m²|m³|cm²|km|cm|mm|kg|mg|ml|cl|dl|min|mph|m|g|l|L|s|h)$')
        .firstMatch(core);
    if (unit != null) {
      final n = _number(unit.group(1)!.trim(), l);
      if (n != null) return '$n ${_unitWord(unit.group(2)!, unit.group(1)!.trim(), l)}';
    }

    // Ordinaux : « 3rd », « 1er », « 2e », « 1º », « XIXe ».
    final ordEn = RegExp(r'^(\d+)(st|nd|rd|th)$').firstMatch(core);
    if (l.en && ordEn != null) return NumberWords.ordinal(int.parse(ordEn.group(1)!), 'en');
    final ordFr = RegExp(r'^(\d+|[IVXLCDM]+)(er|re|ère|e|ème|è|es|èmes)$').firstMatch(core);
    if (l.fr && ordFr != null) {
      final raw = ordFr.group(1)!;
      // Chiffre romain d'au moins 2 lettres (« XIXe ») ou « Ier » ; jamais
      // « Le », « Ce », « De », « Me ».
      final romanOk = raw.length >= 2 || (raw == 'I' && ordFr.group(2)!.startsWith('er'));
      final n = int.tryParse(raw) ?? (romanOk && _roman.hasMatch(raw) ? _romanValue(raw) : 0);
      if (n > 0) {
        final fem = ordFr.group(2) == 're' || ordFr.group(2) == 'ère';
        return NumberWords.ordinal(n, 'fr', feminine: fem);
      }
    }
    final ordPt = RegExp(r'^(\d+)\.?([ºª°])$').firstMatch(core);
    if (l.pt && ordPt != null) {
      return NumberWords.ordinal(int.parse(ordPt.group(1)!), 'pt', feminine: ordPt.group(2) == 'ª');
    }

    // Chiffres romains : « Louis XIV », « Chapter IV ».
    if (_roman.hasMatch(core) && core.isNotEmpty) {
      final prevWord = (prev ?? '').replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
      final afterChapter = _chapterWords.contains(prevWord.toLowerCase());
      final afterName = prevWord.isNotEmpty &&
          RegExp(r'^\p{Lu}\p{Ll}+$', unicode: true).hasMatch(prevWord) && !afterChapter;
      final n = _romanValue(core);
      if (afterChapter || _numberedThings.contains(prevWord.toLowerCase())) {
        return NumberWords.cardinal(n, l.code);
      }
      // Rois, papes… (« Louis XIV ») : jamais au-delà de 40, pour ne pas
      // lire « Washington DC » comme un chiffre romain.
      if (afterName && core.length >= 2 && n <= 40) return _regnal(n, l);
    }

    // Lettres + exposant (« mc² », « x³ ») ou lettres courtes en formule.
    final power = RegExp(r'^(\p{L}{1,3}|\d+)([⁰¹²³⁴⁵⁶⁷⁸⁹]+)$', unicode: true).firstMatch(core);
    if (power != null) {
      final base = power.group(1)!;
      final spokenBase = RegExp(r'^\d+$').hasMatch(base)
          ? _number(base, l)!
          : base.split('').map((c) => _letterName(c, l)).join(' ');
      return '$spokenBase ${_power(power.group(2)!, l)}';
    }

    // Nombre seul.
    final n = _number(core, l, yearStyle: true);
    if (n != null) return n;
    return core;
  }

  static String _spellAddress(String s, _Lang l) {
    final dot = l.pick('dot', 'point', 'ponto');
    final slash = l.pick('slash', 'barre oblique', 'barra');
    final dash = l.pick('dash', 'tiret', 'hífen');
    var t = s;
    var prefix = '';
    if (t.toLowerCase().startsWith('www.')) {
      final w = _letterName('w', l);
      prefix = '$w $w $w $dot ';
      t = t.substring(4);
    }
    t = t
        .replaceAll('.', ' $dot ')
        .replaceAll('/', ' $slash ')
        .replaceAll('-', ' $dash ')
        .replaceAll('_', ' underscore ');
    return '$prefix$t'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Nom d'une lettre isolée (formules, sigles), écrit comme il se prononce :
  /// les voix lisent « èm cé » bien mieux que « m c » en français.
  static String _letterName(String c, _Lang l) {
    const fr = {'a': 'a', 'b': 'bé', 'c': 'cé', 'd': 'dé', 'e': 'e', 'f': 'èf', 'g': 'jé',
      'h': 'ache', 'i': 'i', 'j': 'ji', 'k': 'ka', 'l': 'èl', 'm': 'èm', 'n': 'èn', 'o': 'o',
      'p': 'pé', 'q': 'ku', 'r': 'èr', 's': 'èss', 't': 'té', 'u': 'u', 'v': 'vé',
      'w': 'double vé', 'x': 'ixe', 'y': 'i grec', 'z': 'zèd'};
    const pt = {'a': 'á', 'b': 'bê', 'c': 'cê', 'd': 'dê', 'e': 'é', 'f': 'efe', 'g': 'gê',
      'h': 'agá', 'i': 'i', 'j': 'jota', 'k': 'cá', 'l': 'ele', 'm': 'eme', 'n': 'ene', 'o': 'ó',
      'p': 'pê', 'q': 'quê', 'r': 'erre', 's': 'esse', 't': 'tê', 'u': 'u', 'v': 'vê',
      'w': 'dáblio', 'x': 'xis', 'y': 'ípsilon', 'z': 'zê'};
    final k = c.toLowerCase();
    if (l.fr) return fr[k] ?? c;
    if (l.en) return k == 'w' ? 'double-u' : c;
    return pt[k] ?? c;
  }

  static String _power(String sup, _Lang l) {
    const digits = {'⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4', '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9'};
    final n = int.parse(sup.split('').map((c) => digits[c]).join());
    if (n == 2) return l.pick('squared', 'au carré', 'ao quadrado');
    if (n == 3) return l.pick('cubed', 'au cube', 'ao cubo');
    final w = NumberWords.cardinal(n, l.code);
    return l.pick('to the power of $w', 'puissance $w', 'elevado a $w');
  }

  static String _regnal(int n, _Lang l) {
    if (l.en) return 'the ${NumberWords.ordinal(n, 'en')}';
    if (l.fr) return n == 1 ? 'premier' : NumberWords.cardinal(n, 'fr');
    return n <= 10 ? NumberWords.ordinal(n, 'pt') : NumberWords.cardinal(n, l.code);
  }

  static String _time(int h, int m, _Lang l) {
    if (l.en) {
      if (m == 0) return '${NumberWords.cardinal(h, 'en')} o’clock';
      final mm = m < 10 ? 'oh ${NumberWords.cardinal(m, 'en')}' : NumberWords.cardinal(m, 'en');
      return '${NumberWords.cardinal(h, 'en')} $mm';
    }
    if (l.fr) {
      final hw = '${NumberWords.cardinal(h, 'fr', feminine: true)} heure${h > 1 ? 's' : ''}';
      return m == 0 ? hw : '$hw ${NumberWords.cardinal(m, 'fr', feminine: true)}';
    }
    final hw = '${NumberWords.cardinal(h, l.code, feminine: true)} hora${h > 1 ? 's' : ''}';
    return m == 0 ? hw : '$hw e ${NumberWords.cardinal(m, l.code)}';
  }

  static String _money(String amount, String symbol, _Lang l) {
    final clean = amount.replaceAll(RegExp(r'\s'), '');
    final sep = l.en || symbol == '\$' && !l.pt && !l.fr ? '.' : ',';
    final parts = _splitDecimal(clean, l, preferred: sep);
    if (parts == null) return '$amount $symbol';
    final (whole, cents) = parts;
    String unit(int n) {
      final plural = n != 1;
      switch (symbol) {
        case '€': return l.pick(plural ? 'euros' : 'euro', plural ? 'euros' : 'euro', plural ? 'euros' : 'euro');
        case '£': return l.pick(plural ? 'pounds' : 'pound', plural ? 'livres' : 'livre', plural ? 'libras' : 'libra');
        case '¥': return l.pick('yen', 'yens', 'ienes');
        case 'R\$': return plural ? 'reais' : 'real';
        default: return l.pick(plural ? 'dollars' : 'dollar', plural ? 'dollars' : 'dollar', plural ? 'dólares' : 'dólar');
      }
    }
    String cent(int n) {
      final plural = n != 1;
      if (symbol == '£') return l.pick(plural ? 'pence' : 'penny', 'pence', plural ? 'pence' : 'pêni');
      return l.pick(plural ? 'cents' : 'cent', plural ? 'centimes' : 'centime',
          NumberWords.isPortugal(l.code) ? (plural ? 'cêntimos' : 'cêntimo') : (plural ? 'centavos' : 'centavo'));
    }
    final w = NumberWords.cardinal(whole, l.code);
    if (cents == null || cents == 0) return '$w ${unit(whole)}';
    final c = NumberWords.cardinal(cents, l.code);
    if (l.en) return '$w ${unit(whole)} and $c ${cent(cents)}';
    if (l.fr) return '$w ${unit(whole)} $c';
    return '$w ${unit(whole)} e $c ${cent(cents)}';
  }

  /// (partie entière, centimes sur 2 chiffres) ou null.
  static (int, int?)? _splitDecimal(String s, _Lang l, {String? preferred}) {
    final dec = preferred ?? (l.en ? '.' : ',');
    final thousands = dec == '.' ? ',' : '.';
    final t = s.replaceAll(thousands, '');
    final m = RegExp('^(\\d+)(?:\\${dec}(\\d{1,2}))?\$').firstMatch(t);
    if (m == null) return null;
    final c = m.group(2);
    return (int.parse(m.group(1)!), c == null ? null : int.parse(c.padRight(2, '0')));
  }

  static String? _number(String s, _Lang l, {bool yearStyle = false}) {
    var t = s.replaceAll('−', '-').replaceAll(RegExp(r'[\s  ]'), '');
    var negative = false;
    if (t.startsWith('-') || t.startsWith('+')) {
      negative = t.startsWith('-');
      t = t.substring(1);
    }
    if (!RegExp(r'^\d[\d.,]*$').hasMatch(t)) return null;
    String body;
    if (l.en) {
      if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(t)) t = t.replaceAll(',', '');
      final m = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(t);
      if (m == null) return null;
      final whole = int.parse(m.group(1)!);
      if (yearStyle && m.group(2) == null && m.group(1)!.length == 4 && whole >= 1100 && whole < 2100 && !negative) {
        return NumberWords.year(whole, 'en');
      }
      body = NumberWords.cardinal(whole, 'en');
      if (m.group(2) != null) body = '$body point ${NumberWords.decimals(m.group(2)!, 'en')}';
    } else {
      if (RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(t)) t = t.replaceAll('.', '');
      final m = RegExp(r'^(\d+)(?:[,.](\d+))?$').firstMatch(t);
      if (m == null) return null;
      body = NumberWords.cardinal(int.parse(m.group(1)!), l.code);
      if (m.group(2) != null) {
        body = '$body ${l.pick('point', 'virgule', 'vírgula')} ${NumberWords.decimals(m.group(2)!, l.code)}';
      }
    }
    return negative ? '${l.minus} $body' : body;
  }

  static String _unitWord(String unit, String amount, _Lang l) {
    final one = RegExp(r'^[+\-−]?1$').hasMatch(amount.trim());
    String p(String en, String fr, String pt) => l.pick(en, fr, pt);
    switch (unit) {
      case '%': return p('percent', 'pour cent', 'por cento');
      case '‰': return p('per mille', 'pour mille', 'por mil');
      case '°C': return p(one ? 'degree Celsius' : 'degrees Celsius', 'degrés Celsius', 'graus Celsius');
      case '°F': return p(one ? 'degree Fahrenheit' : 'degrees Fahrenheit', 'degrés Fahrenheit', 'graus Fahrenheit');
      case '°': return p(one ? 'degree' : 'degrees', one ? 'degré' : 'degrés', one ? 'grau' : 'graus');
      case 'km/h': return p('kilometers per hour', 'kilomètres heure', 'quilómetros por hora');
      case 'mph': return 'miles per hour';
      case 'km²': return p('square kilometers', 'kilomètres carrés', 'quilómetros quadrados');
      case 'm²': return p('square meters', 'mètres carrés', 'metros quadrados');
      case 'cm²': return p('square centimeters', 'centimètres carrés', 'centímetros quadrados');
      case 'm³': return p('cubic meters', 'mètres cubes', 'metros cúbicos');
      case 'km': return p(one ? 'kilometer' : 'kilometers', one ? 'kilomètre' : 'kilomètres', one ? 'quilómetro' : 'quilómetros');
      case 'cm': return p(one ? 'centimeter' : 'centimeters', one ? 'centimètre' : 'centimètres', one ? 'centímetro' : 'centímetros');
      case 'mm': return p(one ? 'millimeter' : 'millimeters', one ? 'millimètre' : 'millimètres', one ? 'milímetro' : 'milímetros');
      case 'm': return p(one ? 'meter' : 'meters', one ? 'mètre' : 'mètres', one ? 'metro' : 'metros');
      case 'kg': return p(one ? 'kilogram' : 'kilograms', one ? 'kilo' : 'kilos', one ? 'quilo' : 'quilos');
      case 'g': return p(one ? 'gram' : 'grams', one ? 'gramme' : 'grammes', one ? 'grama' : 'gramas');
      case 'mg': return p(one ? 'milligram' : 'milligrams', one ? 'milligramme' : 'milligrammes', one ? 'miligrama' : 'miligramas');
      case 'l':
      case 'L': return p(one ? 'liter' : 'liters', one ? 'litre' : 'litres', one ? 'litro' : 'litros');
      case 'ml': return p(one ? 'milliliter' : 'milliliters', one ? 'millilitre' : 'millilitres', one ? 'mililitro' : 'mililitros');
      case 'cl': return p(one ? 'centiliter' : 'centiliters', one ? 'centilitre' : 'centilitres', one ? 'centilitro' : 'centilitros');
      case 'dl': return p(one ? 'deciliter' : 'deciliters', one ? 'décilitre' : 'décilitres', one ? 'decilitro' : 'decilitros');
      case 'min': return p(one ? 'minute' : 'minutes', one ? 'minute' : 'minutes', one ? 'minuto' : 'minutos');
      case 's': return p(one ? 'second' : 'seconds', one ? 'seconde' : 'secondes', one ? 'segundo' : 'segundos');
      case 'h': return p(one ? 'hour' : 'hours', one ? 'heure' : 'heures', one ? 'hora' : 'horas');
    }
    return unit;
  }
}

class _Unit {
  const _Unit(this.text, this.first);
  final String text;
  final int first;
}

class _Lang {
  _Lang(String code)
      : code = code,
        en = !code.toLowerCase().startsWith('fr') && !code.toLowerCase().startsWith('pt'),
        fr = code.toLowerCase().startsWith('fr'),
        pt = code.toLowerCase().startsWith('pt');
  final String code;
  final bool en, fr, pt;
  String pick(String enWord, String frWord, String ptWord) => fr ? frWord : pt ? ptWord : enWord;
  String get minus => pick('minus', 'moins', 'menos');
}
