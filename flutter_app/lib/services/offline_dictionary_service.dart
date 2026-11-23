import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Un sens d'un mot : définition + exemple éventuel.
class OfflineSense {
  const OfflineSense(this.gloss, this.example);
  final String gloss;
  final String example;
}

/// Une entrée du dictionnaire hors ligne (un mot pour une nature donnée).
class OfflineEntry {
  const OfflineEntry({
    required this.word,
    required this.partOfSpeech,
    required this.senses,
    required this.synonyms,
  });
  final String word;
  final String partOfSpeech;
  final List<OfflineSense> senses;
  final List<String> synonyms;
}

/// Résultat d'une recherche : entrées du mot (ou de son lemme quand le mot
/// est une forme conjuguée/accordée, ex. « regardait » → « regarder »).
class OfflineLookup {
  const OfflineLookup({
    required this.entries,
    required this.definitionLang,
    this.formOf,
    this.formDescription,
  });
  final List<OfflineEntry> entries;

  /// Langue des définitions (celle demandée, ou une autre si le mot manquait
  /// dans le dictionnaire de cette langue).
  final String definitionLang;

  /// Lemme quand le mot cherché est une forme fléchie.
  final String? formOf;

  /// Description de la forme (« Troisième personne du singulier de… »).
  final String? formDescription;
}

/// Dictionnaire hors ligne, instantané : données Wiktionary converties en
/// bases SQLite (une par langue de définition) placées sur le téléphone dans
/// `<support>/dict/dict_<langue>.db`. Gratuit, aucun réseau.
class OfflineDictionaryService {
  OfflineDictionaryService._();
  static final OfflineDictionaryService instance = OfflineDictionaryService._();

  final Map<String, Future<Database?>> _dbs = {};

  Future<Database?> _db(String defLang) {
    return _dbs[defLang] ??= () async {
      final support = await getApplicationSupportDirectory();
      final path = '${support.path}/dict/dict_$defLang.db';
      if (!await File(path).exists()) return null;
      return openDatabase(path, readOnly: true, singleInstance: true);
    }();
  }

  /// Ordre de repli : la langue demandée, puis l'anglais (le plus complet),
  /// puis la langue du mot elle-même.
  Future<OfflineLookup?> lookup({
    required String word,
    required String sourceLang,
    required String targetLang,
  }) async {
    final order = <String>{targetLang, 'en', sourceLang, 'fr', 'pt'};
    for (final defLang in order) {
      final r = await _lookupIn(defLang, word, sourceLang);
      if (r != null) return r;
    }
    return null;
  }

  /// Mots de [words] (en minuscules) qui existent en [lang], d'après tous les
  /// dictionnaires installés. Vide si aucun n'est installé.
  Future<Set<String>> knownWords(Set<String> words, String lang) async {
    final found = <String>{};
    for (final defLang in <String>{lang, 'en', 'fr', 'pt'}) {
      final remaining = words.difference(found).toList();
      if (remaining.isEmpty) break;
      final db = await _db(defLang);
      if (db == null) continue;
      // SQLite limite le nombre de paramètres d'une requête.
      for (var i = 0; i < remaining.length; i += 500) {
        final chunk = remaining.sublist(i, i + 500 > remaining.length ? remaining.length : i + 500);
        final rows = await db.rawQuery(
          'SELECT DISTINCT word FROM entries WHERE lang = ? AND word IN '
          '(${List.filled(chunk.length, '?').join(',')})',
          [lang, ...chunk],
        );
        for (final r in rows) {
          found.add(r['word'] as String);
        }
      }
    }
    return found;
  }

  Future<OfflineLookup?> _lookupIn(String defLang, String word, String lang) async {
    final db = await _db(defLang);
    if (db == null) return null;
    final key = word.toLowerCase().replaceAll('’', "'");
    var rows = await _rows(db, key, lang);
    if (rows.isEmpty && key.contains("'")) {
      rows = await _rows(db, key.replaceAll("'", '’'), lang);
    }
    if (rows.isEmpty) return null;

    final entries = <OfflineEntry>[];
    String? lemma;
    String? formDesc;
    for (final r in rows) {
      final data = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      final of = data['of'] as String?;
      final senses = _senses(data);
      if (of != null && lemma == null) {
        lemma = of;
        formDesc = senses.isNotEmpty ? senses.first.gloss : null;
        continue; // les sens d'une forme fléchie ne disent que « forme de… »
      }
      if (senses.isEmpty) continue;
      entries.add(OfflineEntry(
        word: word,
        partOfSpeech: _pos(r['pos'] as String?),
        senses: senses,
        synonyms: ((data['syn'] as List?) ?? const []).cast<String>(),
      ));
    }

    // Forme fléchie : on affiche aussi les sens du lemme.
    if (lemma != null) {
      final lemmaRows = await _rows(db, lemma.toLowerCase(), lang);
      for (final r in lemmaRows) {
        final data = jsonDecode(r['data'] as String) as Map<String, dynamic>;
        if (data['of'] != null) continue;
        final senses = _senses(data);
        if (senses.isEmpty) continue;
        entries.add(OfflineEntry(
          word: lemma,
          partOfSpeech: _pos(r['pos'] as String?),
          senses: senses,
          synonyms: ((data['syn'] as List?) ?? const []).cast<String>(),
        ));
      }
    }
    if (entries.isEmpty && formDesc == null) return null;
    return OfflineLookup(
      entries: entries,
      definitionLang: defLang,
      formOf: lemma,
      formDescription: formDesc,
    );
  }

  Future<List<Map<String, Object?>>> _rows(Database db, String word, String lang) =>
      db.query('entries',
          columns: ['pos', 'data'], where: 'lang = ? AND word = ?', whereArgs: [lang, word]);

  /// « Nom commun 1 » → « Nom commun ».
  String _pos(String? p) => (p ?? '').replaceAll(RegExp(r'\s+\d+$'), '');

  List<OfflineSense> _senses(Map<String, dynamic> data) => [
        for (final s in (data['s'] as List? ?? const []))
          OfflineSense((s as List)[0] as String, s.length > 1 ? s[1] as String : ''),
      ];
}
