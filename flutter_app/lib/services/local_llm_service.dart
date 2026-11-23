import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';

import 'pc_boost_service.dart';
import 'sentence_mood.dart';

/// IA locale (Qwen 3 4B Instruct, via llama.cpp) pour le dictionnaire et la
/// traduction d'un passage : tout se passe sur le téléphone, sans réseau ni
/// clé API.
///
/// Fluidité :
///  - le modèle est chargé une seule fois puis gardé en mémoire ;
///  - un préambule d'instructions COMMUN aux deux tâches reste dans le cache
///    du moteur : seule la demande elle-même (le mot, la phrase) est
///    recalculée à chaque fois ;
///  - la réponse arrive mot à mot (flux), l'interface l'affiche au fil de
///    l'eau au lieu d'attendre la fin ;
///  - une nouvelle demande interrompt proprement la précédente.
class LocalLlmService {
  LocalLlmService._();
  static final LocalLlmService instance = LocalLlmService._();

  static const String modelFileName = 'qwen3-4b-instruct.gguf';

  /// Cœurs « performance » du Snapdragon 8 Gen 3 (1 X4 + 5 A720) — mesuré
  /// sur le S24 Ultra, voir le journal [PERF] du moteur.
  static int threads = 6;
  static const int _contextSize = 2048;

  static const Map<String, String> languageNames = {
    'en': 'English',
    'fr': 'French',
    'es': 'Spanish',
    'pt': 'Portuguese',
  };

  /// Vrai pendant le chargement du modèle ou une génération : la synthèse
  /// vocale se met alors en pause pour laisser tout le processeur à l'IA
  /// (sinon les deux se partagent les cœurs et l'IA est ~3× plus lente).
  static final ValueNotifier<bool> busy = ValueNotifier(false);
  int _busyCount = 0;
  void _enterBusy() {
    _busyCount++;
    busy.value = true;
  }

  void _leaveBusy() {
    if (_busyCount > 0) _busyCount--;
    if (_busyCount == 0) busy.value = false;
  }

  final LlamaController _llama = LlamaController();
  Future<void>? _loading;
  bool _loaded = false;

  /// Génération en cours (pour l'interrompre si une autre demande arrive).
  Completer<void>? _activeDone;
  int _requestSerial = 0;

  Future<File> modelFile() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/llm/$modelFileName');
  }

  /// Le moteur llama.cpp intégré n'existe que sur Android : ailleurs
  /// (iPhone), l'IA ne passe que par l'ordinateur (TalkTome Boost).
  Future<bool> isInstalled() async =>
      Platform.isAndroid && await (await modelFile()).exists();

  /// L'IA est utilisable : sur l'ordinateur (TalkTome Boost) ou sur le
  /// téléphone.
  Future<bool> isAvailable() async =>
      await PcBoostService.instance.llmAvailable() || await isInstalled();

  Future<void> _ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= () async {
      try {
        final file = await modelFile();
        if (!await file.exists()) {
          throw StateError('Modèle IA locale non installé');
        }
        final sw = Stopwatch()..start();
        if (!await _llama.isModelLoaded()) {
          await _llama.loadModel(
            modelPath: file.path,
            threads: threads,
            contextSize: _contextSize,
            gpuLayers: 0,
          );
        }
        _loaded = true;
        debugPrint('[LOCAL-LLM] modèle chargé en ${sw.elapsedMilliseconds} ms');
      } finally {
        _loading = null;
      }
    }();
  }

  /// Charge le modèle et met le préambule commun en cache, en arrière-plan,
  /// pour que la première vraie demande réponde vite. Sans effet si le
  /// modèle n'est pas installé.
  /// [pauseAudio] : faux pour un préchargement de fond (à l'ouverture d'un
  /// livre) — le chargement lit surtout le stockage et ne gêne pas la voix ;
  /// on ne met donc pas la synthèse vocale en pause pour lui.
  Future<void> warmUp({bool pauseAudio = true}) async {
    // Déjà prêt, ou une demande est en cours : ne surtout pas l'interrompre.
    if (_warmed || _warming) return;
    final active = _activeDone;
    if (active != null && !active.isCompleted) return;
    // L'ordinateur s'en charge : inutile d'occuper ~3 Go de mémoire sur le
    // téléphone.
    if (await PcBoostService.instance.llmAvailable()) return;
    if (!await isInstalled()) return;
    _warming = true;
    try {
      await _warmUpNow(pauseAudio);
      _warmed = true;
    } finally {
      _warming = false;
    }
  }

  bool _warmed = false;
  bool _warming = false;

  Future<void> _warmUpNow(bool pauseAudio) async {
    try {
      // Préchauffe avec le préambule de « Dans cette phrase », la demande
      // la plus fréquente : il reste ensuite en cache dans le moteur.
      await for (final _ in _generate(_contextTurn('Reply with: OK'), maxTokens: 1, pauseAudio: pauseAudio)) {}
    } catch (e) {
      debugPrint('[LOCAL-LLM] préchauffage échoué : $e');
    }
  }

  // ── Prompt ────────────────────────────────────────────────────────────────

  /// Préambule identique pour TOUTES les demandes (dictionnaire comme
  /// traduction) : c'est ce qui permet au moteur de le garder en cache.
  static const String _system =
      'You are a precise bilingual language assistant inside an ebook reader. '
      'You do two kinds of tasks.\n'
      'TASK DEFINE: explain one word as a high-quality learner\'s dictionary would. '
      'If a context sentence is given, explain the meaning the word has IN THAT '
      'SENTENCE. Answer with exactly these five lines and nothing else:\n'
      'TRANSLATION: <the word translated into the answer language; the word '
      'itself if same language>\n'
      'TYPE: <part of speech, in the answer language>\n'
      'DEFINITION: <what the word means: one or two accurate, dictionary-style '
      'sentences in the answer language; do not just paraphrase the context>\n'
      'EXAMPLE: <a NEW short example sentence, written in the example language>\n'
      'SYNONYMS: <up to 4 true synonyms in the answer language, comma-separated, '
      'or the word none>\n'
      'TASK CONTEXT: give the meaning of one word in one given sentence, very '
      'briefly. Answer with exactly these two lines and nothing else:\n'
      'TRANSLATION: <the word translated into the answer language, as used in '
      'the sentence; the word itself if same language>\n'
      'MEANING: <at most 20 words, in the answer language: what the word means '
      'in this sentence>\n'
      'TASK TRANSLATE: translate the given text faithfully and naturally, '
      'keeping its tone, names and punctuation. Answer with the translation only, '
      'no quotes, no notes.';

  /// Préambule COURT, dédié au sens d'un mot dans sa phrase : ~4× moins de
  /// texte à lire que le préambule commun, donc une réponse bien plus rapide.
  static const String _contextSystem =
      'You explain one word as used in one sentence, briefly. Dictionary senses '
      'may be given: rely on them. Answer with exactly these two lines and '
      'nothing else:\n'
      'TRANSLATION: <ONLY the word itself translated into the answer language '
      '(1 to 3 words), never the whole sentence; the word itself if same '
      'language>\n'
      'MEANING: <at most 15 words, in the answer language: what the word means '
      'in this sentence>';

  static String _contextTurn(String content) =>
      '<|im_start|>system\n$_contextSystem<|im_end|>\n'
      '<|im_start|>user\n$content<|im_end|>\n'
      '<|im_start|>assistant\n';

  static String _userTurn(String content) =>
      '<|im_start|>system\n$_system<|im_end|>\n'
      '<|im_start|>user\n$content<|im_end|>\n'
      '<|im_start|>assistant\n';

  // ── Génération ────────────────────────────────────────────────────────────

  Stream<String> _generate(String prompt,
      {required int maxTokens, double temperature = 0.2, bool pauseAudio = true}) async* {
    final serial = ++_requestSerial;

    // Interrompre la demande précédente et attendre qu'elle soit vraiment
    // terminée côté moteur (sinon sa fin fermerait le flux de la nouvelle).
    final previous = _activeDone;
    if (previous != null && !previous.isCompleted) {
      if (Platform.isAndroid) await _llama.stop();
      await previous.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    }
    if (serial != _requestSerial) return; // déjà remplacée par une plus récente

    // Ordinateur joignable : génération sur sa carte graphique (~10× plus
    // rapide). En cas de coupure avant le premier mot, on continue sur le
    // téléphone.
    final boost = PcBoostService.instance;
    if (await boost.llmAvailable()) {
      var yielded = false;
      try {
        await for (final piece in boost.generate(
            prompt: prompt, maxTokens: maxTokens, temperature: temperature)) {
          if (serial != _requestSerial) return;
          yielded = true;
          yield piece;
        }
        return;
      } catch (e) {
        debugPrint('[LOCAL-LLM] ordinateur indisponible, retour au téléphone : $e');
        boost.markFailed();
        if (yielded) return;
      }
      if (serial != _requestSerial) return;
    }

    if (pauseAudio) _enterBusy();
    void leave() {
      if (pauseAudio) _leaveBusy();
    }

    try {
      await _ensureLoaded();
    } catch (e) {
      leave();
      rethrow;
    }
    if (serial != _requestSerial) {
      leave();
      return;
    }

    final done = Completer<void>();
    _activeDone = done;
    try {
      final stream = _llama.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topK: 20,
        topP: 0.8,
        minP: 0.0,
        repeatPenalty: 1.0,
      );
      await for (final piece in stream) {
        if (serial != _requestSerial) break;
        yield piece;
      }
      _warmed = true; // le préambule commun est désormais en cache
    } finally {
      if (!done.isCompleted) done.complete();
      leave();
    }
  }

  // ── Dictionnaire ──────────────────────────────────────────────────────────

  /// Définit [word] ; chaque élément du flux est la réponse complète à jour
  /// (champs remplis au fur et à mesure de l'écriture).
  Stream<LocalDefinition> define({
    required String word,
    required String sourceLang,
    required String targetLang,
    String? contextSentence,
  }) async* {
    final src = languageNames[sourceLang] ?? sourceLang;
    final tgt = languageNames[targetLang] ?? targetLang;
    final ctx = (contextSentence ?? '').trim();
    final request = StringBuffer()
      ..writeln('TASK DEFINE')
      ..writeln('Word ($src): $word');
    if (ctx.isNotEmpty) request.writeln('Context sentence: $ctx');
    request
      ..writeln('Answer language: $tgt')
      ..write('Example language: $src');

    var text = '';
    await for (final piece in _generate(_userTurn(request.toString()), maxTokens: 220)) {
      text += piece;
      yield LocalDefinition.parse(text);
    }
    yield LocalDefinition.parse(text, complete: true);
  }

  // ── Sens dans la phrase (complément rapide du dictionnaire hors ligne) ────

  /// Réponse courte (~20 mots, 2-3 s) : traduction du mot et sens qu'il a
  /// dans [sentence]. Chaque élément du flux est la réponse à jour.
  Stream<LocalContextMeaning> explainInContext({
    required String word,
    required String sentence,
    required String sourceLang,
    required String targetLang,
    List<String> senses = const [],
  }) async* {
    final src = languageNames[sourceLang] ?? sourceLang;
    final tgt = languageNames[targetLang] ?? targetLang;
    // Sens du dictionnaire hors ligne : ils ancrent la réponse (évite les
    // contresens, ex. « sótão » = grenier, pas sous-sol).
    final hints = senses
        .take(4)
        .map((g) => g.length > 70 ? '${g.substring(0, 70)}…' : g)
        .join(' | ');
    var text = '';
    await for (final piece in _generate(
        _contextTurn('Word ($src): $word\nSentence: $sentence\n'
            '${hints.isEmpty ? '' : 'Dictionary senses: $hints\n'}'
            'Answer language: $tgt'),
        maxTokens: 50)) {
      text += piece;
      yield LocalContextMeaning.parse(text);
    }
  }

  // ── Traduction ────────────────────────────────────────────────────────────

  /// Traduit [text] ; chaque élément du flux est la traduction partielle à jour.
  Stream<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async* {
    final src = languageNames[sourceLang] ?? sourceLang;
    final tgt = languageNames[targetLang] ?? targetLang;
    // Marge confortable : une traduction fait rarement plus de 2x l'original.
    final maxTokens = (text.length / 2).clamp(64, 900).round();
    var out = '';
    await for (final piece in _generate(
        _userTurn('TASK TRANSLATE\nFrom $src to $tgt:\n$text'),
        maxTokens: maxTokens)) {
      out += piece;
      yield out.trimLeft();
    }
  }

  // ── Humeur des phrases (lecture expressive) ──────────────────────────────

  static const String _moodSystem =
      'You label the emotional tone of sentences from a book, for an expressive '
      'text-to-speech narrator. Labels: neutral, happy, excited, sad, angry, '
      'scared, calm. Use neutral unless the emotion is clear. Answer with exactly '
      'one line per numbered sentence, in the form "<number>: <label>", and '
      'nothing else.';

  /// Humeur de chaque phrase de [sentences] (null si illisible), ou null si
  /// l'ordinateur (TalkTome Boost) n'est pas joignable. Jamais sur le
  /// téléphone : ce serait trop lent et la voix devrait s'interrompre.
  Future<List<Mood?>?> classifyMoods(List<String> sentences,
      {List<String> context = const []}) async {
    final boost = PcBoostService.instance;
    if (sentences.isEmpty || !await boost.llmAvailable()) return null;
    String oneLine(String s) {
      final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      return t.length > 300 ? t.substring(0, 300) : t;
    }

    final user = StringBuffer();
    if (context.isNotEmpty) {
      user.writeln('Preceding text (do not label):');
      for (final c in context) {
        user.writeln(oneLine(c));
      }
      user.writeln();
    }
    user.writeln('Sentences:');
    for (var i = 0; i < sentences.length; i++) {
      user.writeln('${i + 1}. ${oneLine(sentences[i])}');
    }
    final prompt = '<|im_start|>system\n$_moodSystem<|im_end|>\n'
        '<|im_start|>user\n$user<|im_end|>\n'
        '<|im_start|>assistant\n';

    final answer = StringBuffer();
    try {
      await for (final piece in boost.generate(
          prompt: prompt, maxTokens: 6 * sentences.length + 8, temperature: 0.1)) {
        answer.write(piece);
      }
    } catch (e) {
      debugPrint('[LOCAL-LLM] humeurs indisponibles : $e');
      return null;
    }
    return parseMoodLines(answer.toString(), sentences.length);
  }
}

/// Sens d'un mot dans sa phrase (réponse éventuellement partielle).
class LocalContextMeaning {
  const LocalContextMeaning(this.translation, this.meaning);
  final String translation;
  final String meaning;

  factory LocalContextMeaning.parse(String raw) {
    final d = LocalDefinition.parse(raw.replaceAll(
        RegExp(r'^\s*MEANING\s*:', caseSensitive: false, multiLine: true), 'DEFINITION:'));
    return LocalContextMeaning(d.translatedWord, d.definition);
  }
}

/// Réponse (éventuellement partielle) du dictionnaire local.
class LocalDefinition {
  LocalDefinition({
    required this.translatedWord,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    required this.synonyms,
    required this.complete,
  });

  final String translatedWord;
  final String partOfSpeech;
  final String definition;
  final String example;
  final List<String> synonyms;
  final bool complete;

  bool get hasContent => definition.isNotEmpty || translatedWord.isNotEmpty;

  static final _field = RegExp(
      r'^\s*(TRANSLATION|TYPE|DEFINITION|EXAMPLE|SYNONYMS)\s*:\s*(.*)$',
      caseSensitive: false);

  factory LocalDefinition.parse(String raw, {bool complete = false}) {
    final values = <String, String>{};
    String? current;
    // Le modèle recopie parfois des entités HTML apprises sur le web.
    raw = raw
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    for (final line in raw.split('\n')) {
      final m = _field.firstMatch(line);
      if (m != null) {
        current = m.group(1)!.toUpperCase();
        values[current] = m.group(2)!.trim();
      } else if (current != null && line.trim().isNotEmpty) {
        values[current] = '${values[current]} ${line.trim()}';
      }
    }
    String clean(String? s) =>
        (s ?? '').trim().replaceAll(RegExp(r'''^["«“'\s]+|["»”'\s]+$'''), '');
    final syn = clean(values['SYNONYMS']);
    return LocalDefinition(
      translatedWord: clean(values['TRANSLATION']),
      partOfSpeech: clean(values['TYPE']),
      definition: clean(values['DEFINITION']),
      example: clean(values['EXAMPLE']),
      synonyms: syn.isEmpty || RegExp(r'^(none|-+)$', caseSensitive: false).hasMatch(syn)
          ? const []
          : syn
              .split(RegExp(r'[,;]'))
              .map((s) => s.replaceAll(RegExp(r'[.\->]+$'), '').trim())
              .where((s) => s.isNotEmpty && s.toLowerCase() != 'none')
              .take(4)
              .toList(),
      complete: complete,
    );
  }
}
