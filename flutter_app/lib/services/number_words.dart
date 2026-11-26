/// Nombres écrits en toutes lettres (anglais, français, portugais du Brésil et
/// du Portugal), pour que toutes les voix les lisent pareil : certains moteurs
/// lisent mal les chiffres (« 5,99 € » → « simple au 49 », « 1er » → « Nermet »).
class NumberWords {
  NumberWords._();

  // ── Anglais ──────────────────────────────────────────────────────────────
  static const _enOnes = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
    'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
    'seventeen', 'eighteen', 'nineteen',
  ];
  static const _enTens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  ];

  static String _enBelow1000(int n) {
    final parts = <String>[];
    if (n >= 100) {
      parts.add('${_enOnes[n ~/ 100]} hundred');
      n %= 100;
    }
    if (n >= 20) {
      parts.add(n % 10 == 0 ? _enTens[n ~/ 10] : '${_enTens[n ~/ 10]}-${_enOnes[n % 10]}');
    } else if (n > 0 || parts.isEmpty) {
      parts.add(_enOnes[n]);
    }
    return parts.join(' ');
  }

  static String _en(int n) {
    if (n < 0) return 'minus ${_en(-n)}';
    if (n < 1000) return _enBelow1000(n);
    const scales = [(1000000000000, 'trillion'), (1000000000, 'billion'), (1000000, 'million'), (1000, 'thousand')];
    final parts = <String>[];
    for (final (value, name) in scales) {
      if (n >= value) {
        parts.add('${_enBelow1000(n ~/ value)} $name');
        n %= value;
      }
    }
    if (n > 0) parts.add(_enBelow1000(n));
    return parts.join(' ');
  }

  /// « 1987 » → « nineteen eighty-seven » ; « 2005 » → « two thousand five ».
  static String _enYear(int y) {
    if (y >= 2000 && y < 2010) return _en(y);
    if (y % 100 == 0 && y % 1000 != 0) return '${_en(y ~/ 100)} hundred';
    final tail = y % 100;
    return '${_en(y ~/ 100)} ${tail < 10 ? 'oh ${_en(tail)}' : _en(tail)}';
  }

  static String _enOrdinal(int n) {
    final words = _en(n);
    const irregular = {
      'one': 'first', 'two': 'second', 'three': 'third', 'five': 'fifth',
      'eight': 'eighth', 'nine': 'ninth', 'twelve': 'twelfth',
    };
    final cut = words.lastIndexOf(RegExp(r'[ -]'));
    final head = cut < 0 ? '' : words.substring(0, cut + 1);
    final last = cut < 0 ? words : words.substring(cut + 1);
    final ord = irregular[last] ??
        (last.endsWith('y') ? '${last.substring(0, last.length - 1)}ieth' : '${last}th');
    return '$head$ord';
  }

  // ── Français ─────────────────────────────────────────────────────────────
  static const _frOnes = [
    'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
    'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
    'dix-sept', 'dix-huit', 'dix-neuf',
  ];
  static const _frTens = [
    '', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', '', 'quatre-vingt', '',
  ];

  static String _frBelow100(int n, {bool feminine = false}) {
    if (n == 1 && feminine) return 'une';
    if (n < 20) return _frOnes[n];
    final t = n ~/ 10, u = n % 10;
    if (t == 7 || t == 9) {
      final base = _frTens[t - 1];
      final rest = 10 + u;
      final sep = (t == 7 && u == 1) ? ' et ' : '-';
      return '$base$sep${_frOnes[rest]}';
    }
    if (t == 8) return u == 0 ? 'quatre-vingts' : 'quatre-vingt-${u == 1 && feminine ? 'une' : _frOnes[u]}';
    if (u == 0) return _frTens[t];
    if (u == 1) return '${_frTens[t]} et ${feminine ? 'une' : 'un'}';
    return '${_frTens[t]}-${_frOnes[u]}';
  }

  static String _frBelow1000(int n, {bool feminine = false, bool beforeNoun = false}) {
    final h = n ~/ 100, rest = n % 100;
    final parts = <String>[];
    if (h > 0) {
      final cent = h == 1 ? 'cent' : '${_frOnes[h]} cent${rest == 0 && !beforeNoun ? 's' : ''}';
      parts.add(cent);
    }
    if (rest > 0 || h == 0) parts.add(_frBelow100(rest, feminine: feminine));
    return parts.join(' ');
  }

  static String _fr(int n, {bool feminine = false}) {
    if (n < 0) return 'moins ${_fr(-n, feminine: feminine)}';
    if (n < 1000) return _frBelow1000(n, feminine: feminine);
    final parts = <String>[];
    const scales = [(1000000000, 'milliard'), (1000000, 'million')];
    for (final (value, name) in scales) {
      if (n >= value) {
        final k = n ~/ value;
        parts.add('${_frBelow1000(k)} $name${k > 1 ? 's' : ''}');
        n %= value;
      }
    }
    if (n >= 1000) {
      final k = n ~/ 1000;
      parts.add(k == 1 ? 'mille' : '${_frBelow1000(k, beforeNoun: true)} mille');
      n %= 1000;
    }
    if (n > 0) parts.add(_frBelow1000(n, feminine: feminine));
    return parts.join(' ');
  }

  static String _frOrdinal(int n, {bool feminine = false}) {
    if (n == 1) return feminine ? 'première' : 'premier';
    var w = _fr(n);
    if (w.endsWith('quatre-vingts')) w = w.substring(0, w.length - 1);
    if (w.endsWith('cents')) w = w.substring(0, w.length - 1);
    if (w.endsWith('cinq')) return '${w}uième';
    if (w.endsWith('neuf')) return '${w.substring(0, w.length - 1)}vième';
    if (w.endsWith('e')) return '${w.substring(0, w.length - 1)}ième';
    return '${w}ième';
  }

  // ── Portugais ────────────────────────────────────────────────────────────
  static List<String> _ptOnes(bool brazil) => [
        'zero', 'um', 'dois', 'três', 'quatro', 'cinco', 'seis', 'sete', 'oito', 'nove',
        'dez', 'onze', 'doze', 'treze', 'catorze', 'quinze',
        brazil ? 'dezesseis' : 'dezasseis', brazil ? 'dezessete' : 'dezassete',
        'dezoito', brazil ? 'dezenove' : 'dezanove',
      ];
  static const _ptTens = [
    '', '', 'vinte', 'trinta', 'quarenta', 'cinquenta', 'sessenta', 'setenta', 'oitenta', 'noventa',
  ];
  static const _ptHundreds = [
    '', 'cento', 'duzentos', 'trezentos', 'quatrocentos', 'quinhentos', 'seiscentos',
    'setecentos', 'oitocentos', 'novecentos',
  ];

  static String _ptUnit(int n, bool brazil, bool feminine) {
    if (feminine && n == 1) return 'uma';
    if (feminine && n == 2) return 'duas';
    return _ptOnes(brazil)[n];
  }

  static String _ptBelow1000(int n, bool brazil, bool feminine) {
    if (n == 100) return 'cem';
    final parts = <String>[];
    final h = n ~/ 100, rest = n % 100;
    if (h > 0) {
      var hw = _ptHundreds[h];
      if (feminine && h > 1) hw = '${hw.substring(0, hw.length - 2)}as';
      parts.add(hw);
    }
    if (rest > 0 || h == 0) {
      if (rest < 20) {
        parts.add(_ptUnit(rest, brazil, feminine));
      } else {
        final t = rest ~/ 10, u = rest % 10;
        parts.add(u == 0 ? _ptTens[t] : '${_ptTens[t]} e ${_ptUnit(u, brazil, feminine)}');
      }
    }
    return parts.join(' e ');
  }

  static String _pt(int n, {bool brazil = true, bool feminine = false}) {
    if (n < 0) return 'menos ${_pt(-n, brazil: brazil, feminine: feminine)}';
    if (n < 1000) return _ptBelow1000(n, brazil, feminine);
    final groups = <(int, String, String)>[
      (1000000000, brazil ? 'bilhão' : 'mil milhões', brazil ? 'bilhões' : 'mil milhões'),
      (1000000, 'milhão', 'milhões'),
    ];
    final parts = <String>[];
    for (final (value, one, many) in groups) {
      if (n >= value) {
        final k = n ~/ value;
        parts.add(k == 1 ? 'um $one' : '${_ptBelow1000(k, brazil, false)} $many');
        n %= value;
      }
    }
    if (n >= 1000) {
      final k = n ~/ 1000;
      parts.add(k == 1 ? 'mil' : '${_ptBelow1000(k, brazil, feminine)} mil');
      n %= 1000;
    }
    if (n > 0) {
      // « e » avant le dernier groupe s'il est rond ou petit (mil e cem, mil e vinte).
      final joinE = n < 100 || n % 100 == 0;
      final w = _ptBelow1000(n, brazil, feminine);
      parts.add(joinE ? 'e $w' : w);
    }
    return parts.join(' ');
  }

  static const _ptOrdUnits = [
    '', 'primeiro', 'segundo', 'terceiro', 'quarto', 'quinto', 'sexto', 'sétimo', 'oitavo', 'nono',
  ];
  static const _ptOrdTens = [
    '', 'décimo', 'vigésimo', 'trigésimo', 'quadragésimo', 'quinquagésimo', 'sexagésimo',
    'septuagésimo', 'octogésimo', 'nonagésimo',
  ];
  static const _ptOrdHundreds = [
    '', 'centésimo', 'ducentésimo', 'trecentésimo', 'quadringentésimo', 'quingentésimo',
    'sexcentésimo', 'septingentésimo', 'octingentésimo', 'nongentésimo',
  ];

  static String _ptOrdinal(int n, {bool feminine = false}) {
    if (n <= 0 || n >= 1000) return _pt(n);
    final parts = [
      if (n >= 100) _ptOrdHundreds[n ~/ 100],
      if (n % 100 >= 10) _ptOrdTens[(n % 100) ~/ 10],
      if (n % 10 > 0) _ptOrdUnits[n % 10],
    ];
    final w = parts.join(' ');
    return feminine ? w.split(' ').map((p) => '${p.substring(0, p.length - 1)}a').join(' ') : w;
  }

  // ── Accès par langue ─────────────────────────────────────────────────────

  /// [lang] : « en », « fr », « pt-BR », « pt-PT »… (seul le début compte,
  /// sauf pour le portugais : Brésil par défaut).
  static String cardinal(int n, String lang, {bool feminine = false}) {
    final l = lang.toLowerCase();
    if (l.startsWith('fr')) return _fr(n, feminine: feminine);
    if (l.startsWith('pt')) return _pt(n, brazil: l != 'pt-pt', feminine: feminine);
    return _en(n);
  }

  static bool isPortugal(String lang) => lang.toLowerCase() == 'pt-pt';

  static String ordinal(int n, String lang, {bool feminine = false}) {
    final l = lang.toLowerCase();
    if (l.startsWith('fr')) return _frOrdinal(n, feminine: feminine);
    if (l.startsWith('pt')) return _ptOrdinal(n, feminine: feminine);
    return _enOrdinal(n);
  }

  static String year(int y, String lang) =>
      lang.toLowerCase().startsWith('en') && y >= 1100 && y < 2100 ? _enYear(y) : cardinal(y, lang);

  /// Chiffres après la virgule : un par un en anglais (« point one four »),
  /// comme un nombre en français et en portugais (« virgule quatorze »),
  /// en gardant les zéros de tête (« virgule zéro cinq »).
  static String decimals(String digits, String lang) {
    final l = lang.toLowerCase();
    if (l.startsWith('en')) {
      return digits.split('').map((d) => _en(int.parse(d))).join(' ');
    }
    final lead = RegExp(r'^0+').firstMatch(digits)?.group(0)?.length ?? 0;
    final zero = cardinal(0, lang);
    final rest = digits.substring(lead);
    return [
      for (var i = 0; i < lead; i++) zero,
      if (rest.isNotEmpty) cardinal(int.parse(rest), lang),
    ].join(' ');
  }
}
