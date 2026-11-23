import 'dart:async';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show appLocaleNotifier, expressiveReadingNotifier;
import 'local_llm_service.dart';
import 'sentence_mood.dart';
import 'sherpa_tts_service.dart';
import 'speech_text_normalizer.dart';
import 'tts_audio_cache.dart';
import 'wav_silence.dart';
import '../models/word_timing.dart';

/// Résout la langue actuelle de l'app (préférence utilisateur, sinon système,
/// sinon français par défaut) sans BuildContext — ce handler est un singleton
/// hors de l'arbre de widgets, donc ne peut pas utiliser AppLocalizations.of().
AppLocalizations _currentL10n() {
  final preferred = appLocaleNotifier.value;
  if (preferred != null) return lookupAppLocalizations(preferred);
  final systemLocale = PlatformDispatcher.instance.locale;
  const supported = [Locale('fr'), Locale('en')];
  final match = supported.firstWhere(
    (l) => l.languageCode == systemLocale.languageCode,
    orElse: () => const Locale('fr'),
  );
  return lookupAppLocalizations(match);
}

/// Gère la session média Android (foreground service + notification de lecture)
/// et toute la chaîne synthèse IA locale → lecture, pour que tout fonctionne
/// en arrière-plan.
///
/// Chargement : une boucle unique (le moteur local ne traite qu'une phrase
/// à la fois) synthétise en continu les phrases à venir, en priorité celle
/// qu'on attend, jusqu'à avoir [_targetSecondsAhead] secondes d'audio
/// d'avance. La synthèse se fait directement à la vitesse choisie : à 1,5×
/// le moteur produit un audio plus court, donc l'avance se constitue aussi
/// vite qu'à 1×, et le son reste naturel (pas d'accélération après coup).
class TalkTomeAudioHandler extends BaseAudioHandler {
  static TalkTomeAudioHandler? _instance;
  static TalkTomeAudioHandler? get instance => _instance;

  /// Avance visée (secondes d'écoute) et plafond en nombre de phrases.
  static const double _targetSecondsAhead = 180;
  static const int _maxSentencesAhead = 80;

  // Double-buffer : deux lecteurs pour des transitions instantanées.
  final List<AudioPlayer> _players = [AudioPlayer(), AudioPlayer()];
  int _currentIdx = 0;
  AudioPlayer get _currentPlayer => _players[_currentIdx];
  AudioPlayer get _bufferPlayer => _players[1 - _currentIdx];

  /// Phrase chargée dans chaque lecteur (null = rien de valable).
  int? _currentLoadedIndex;
  TtsClip? _currentClip;
  int? _bufferIndex;
  TtsClip? _bufferClip;

  // ── État de session ────────────────────────────────────────────────────────

  List<String> _sentenceTexts = [];
  String _bookTitle = '';
  int _currentIndex = 0;

  /// Id du livre (Hive) en cours de lecture — pour le mini-lecteur.
  final ValueNotifier<String?> currentEbookIdNotifier = ValueNotifier(null);

  String get bookTitle => _bookTitle;
  int get totalSentenceCount => _sentenceTexts.length;
  double get speed => _speed;
  String get voiceName => _voiceName;

  String _voiceName = 'sherpa-kokoro-af_heart';
  // ignore: unused_field
  String _languageCode = 'en-US';

  /// Vitesse d'écoute demandée (appliquée tout de suite).
  double _speed = 1.0;

  /// Vitesse à laquelle on synthétise (suit [_speed] après un court délai,
  /// pour ne pas tout régénérer à chaque cran du curseur).
  double _synthSpeed = 1.0;
  Timer? _speedDebounce;

  bool _isSessionActive = false;
  bool _isPlaying = false;

  // ── Pipeline de synthèse ────────────────────────────────────────────────

  final Map<int, TtsClip> _ready = {};

  /// Texte réellement prononcé pour chaque phrase prête (l'original, ou sa
  /// traduction en mode « lire la traduction »).
  final Map<int, String> _spoken = {};

  /// Mode « lire la traduction » : fournit le texte à prononcer à la place
  /// de la phrase du livre, avec une voix de la langue de traduction.
  Future<String> Function(int index)? _textProvider;
  String? _translationVoice;
  bool get isReadingTranslation => _textProvider != null;
  final Set<int> _failed = {};
  final Map<int, Completer<TtsClip?>> _waiters = {};
  int _generation = 0; // change de voix / de session : résultats en cours périmés
  bool _pumping = false;
  int _playToken = 0;

  // ── Lecture expressive ────────────────────────────────────────────────────

  /// Phrases demandées d'un coup à l'IA de l'ordinateur.
  static const int _moodBatch = 12;

  /// Humeur décidée pour chaque phrase de la session (IA ou règles).
  final Map<int, Mood> _moods = {};

  /// Après un échec de l'IA (ordinateur absent, trop lent), on s'en tient
  /// aux règles jusqu'à cette heure-là.
  DateTime _moodAiRetryAt = DateTime(0);

  // ── Suivi mot par mot ─────────────────────────────────────────────────────

  List<WordTiming> _currentWordTimings = [];
  Timer? _wordTrackingTimer;

  // ── Notifiers pour l'UI ───────────────────────────────────────────────────

  final ValueNotifier<int> currentIndexNotifier = ValueNotifier(0);
  final ValueNotifier<int> currentWordIndexNotifier = ValueNotifier(-1);

  /// Texte en train d'être prononcé et mot actif DANS ce texte. Identiques
  /// au livre en lecture normale ; en mode « lire la traduction », c'est la
  /// traduction (affichée dans la bulle, avec son propre suivi des mots),
  /// tandis que [currentWordIndexNotifier] suit le livre en proportion.
  final ValueNotifier<String?> spokenTextNotifier = ValueNotifier(null);
  final ValueNotifier<int> spokenWordIndexNotifier = ValueNotifier(-1);

  /// Vrai quand on attend la synthèse de la phrase à lire (spinner).
  final ValueNotifier<bool> isSynthesizingNotifier = ValueNotifier(false);

  /// Intention de l'utilisateur (jouer ou pause), respectée même pendant un
  /// chargement.
  final ValueNotifier<bool> shouldBePlayingNotifier = ValueNotifier(true);

  TalkTomeAudioHandler() {
    _instance = this;
    for (int i = 0; i < 2; i++) {
      final idx = i;
      _players[idx].playerStateStream.listen((state) {
        if (idx != _currentIdx) return;
        _onPlayerStateChanged(state);
      });
    }
    expressiveReadingNotifier.addListener(_onExpressiveReadingChanged);
  }

  /// Option activée ou coupée : les phrases déjà préparées sont refaites
  /// avec ou sans humeur ; celle qui joue va jusqu'au bout.
  void _onExpressiveReadingChanged() {
    if (!_isSessionActive) return;
    _invalidatePipeline();
    _kickPump();
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (state.processingState == ProcessingState.completed && _isPlaying) {
      _isPlaying = false;
      _onSentenceFinished();
      return;
    }
    if (!state.playing && state.processingState == ProcessingState.completed) return;
    _isPlaying = state.playing;
    _updateNotification(playing: state.playing);
  }

  void _onSentenceFinished() {
    if (_currentIndex < _sentenceTexts.length - 1) {
      _playSentence(_currentIndex + 1);
    } else {
      _isPlaying = false;
      isSynthesizingNotifier.value = false;
      _updateNotification(playing: false);
    }
  }

  // ── Configuration de session ───────────────────────────────────────────────

  void startSession({
    required List<String> sentences,
    required String bookTitle,
    required String ebookId,
    required String voiceName,
    required String languageCode,
    required double speed,
    required int startIndex,
  }) {
    _playToken++;
    _sentenceTexts = sentences;
    _textProvider = null;
    _translationVoice = null;
    _bookTitle = bookTitle;
    currentEbookIdNotifier.value = ebookId;
    _voiceName = voiceName;
    _languageCode = languageCode;
    _speed = speed;
    _synthSpeed = _round(speed);
    _currentIndex = startIndex;
    _isSessionActive = true;
    _isPlaying = false;
    shouldBePlayingNotifier.value = false;
    isSynthesizingNotifier.value = false;
    currentIndexNotifier.value = startIndex;
    _invalidatePipeline();
    _resetWordTracking();
    _updateMediaItem();
    _updateNotification(playing: false);
    // Commence à préparer l'audio dès l'ouverture du livre.
    _kickPump();
  }

  void updateVoice(String voiceName, String languageCode) {
    if (voiceName == _voiceName) {
      _languageCode = languageCode;
      return;
    }
    _voiceName = voiceName;
    _languageCode = languageCode;
    _invalidatePipeline();
    _kickPump();
  }

  /// Active (provider non null) ou coupe le mode « lire la traduction ».
  /// La phrase en cours est relue aussitôt dans le nouveau mode.
  void setTranslationReading({
    Future<String> Function(int index)? textProvider,
    String? voiceName,
  }) {
    _textProvider = textProvider;
    _translationVoice = textProvider == null ? null : voiceName;
    _invalidatePipeline();
    if (shouldBePlayingNotifier.value && _isSessionActive) {
      unawaited(_playSentence(_currentIndex));
    } else {
      _currentLoadedIndex = null;
      _currentClip = null;
      _kickPump();
    }
  }

  /// Vitesse : appliquée immédiatement à la phrase en cours (par le lecteur),
  /// puis, une fois le curseur relâché, les phrases suivantes sont
  /// re-synthétisées à la bonne vitesse par le moteur.
  void updateSpeed(double speed) {
    _speed = speed;
    _applyPlayerSpeeds();
    _speedDebounce?.cancel();
    _speedDebounce = Timer(const Duration(milliseconds: 600), () {
      final s = _round(_speed);
      if (s == _synthSpeed) return;
      _synthSpeed = s;
      _kickPump();
    });
  }

  static double _round(double s) => double.parse(s.toStringAsFixed(2));

  /// Chaque lecteur compense l'écart entre la vitesse voulue et celle à
  /// laquelle son audio a été synthétisé (normalement 1,0 : aucun effet).
  void _applyPlayerSpeeds() {
    final c = _currentClip;
    if (c != null) unawaited(_tune(_currentPlayer, c));
    final b = _bufferClip;
    if (b != null) unawaited(_tune(_bufferPlayer, b));
  }

  // ─── Timbre (plus grave / plus aigu), réglé pour chaque voix ─────────────

  /// Bornes du réglage : au-delà, la voix devient caricaturale.
  static const double pitchMin = 0.85, pitchMax = 1.15;

  static double pitchFor(String voice) =>
      (Hive.box('settings').get('pitch_$voice', defaultValue: 1.0) as num)
          .toDouble()
          .clamp(pitchMin, pitchMax);

  /// Timbre de la voix qui parle en ce moment (celle de la traduction quand
  /// on lit la traduction à voix haute).
  double get _activePitch => pitchFor(_translationVoice ?? _voiceName);

  /// Change le timbre de [voice] : appliqué tout de suite, même en pleine
  /// phrase — rien à re-synthétiser, c'est le lecteur qui transforme l'audio.
  Future<void> setVoicePitch(String voice, double pitch) async {
    await Hive.box('settings').put('pitch_$voice', pitch.clamp(pitchMin, pitchMax));
    _applyPlayerSpeeds();
  }

  /// Vitesse, timbre et volume d'un lecteur pour [clip] (humeur comprise :
  /// sans lecture expressive, le profil neutre ne change rien). Le timbre
  /// est seulement celui choisi pour la voix : l'humeur ne le décale jamais
  /// (voix déformées, aiguës ou graves, d'une phrase à l'autre).
  Future<void> _tune(AudioPlayer player, TtsClip clip) async {
    final mood = clip.mood;
    await player.setSpeed(_speed * mood.speedFactor / clip.speed);
    await player.setPitch(_activePitch);
    await player.setVolume(mood.volume);
  }

  void _invalidatePipeline() {
    _generation++;
    _ready.clear();
    _spoken.clear();
    _moods.clear();
    _failed.clear();
    _bufferIndex = null;
    _bufferClip = null;
  }

  // ── Contrôles audio ────────────────────────────────────────────────────────

  @override
  Future<void> play() async {
    if (!_isSessionActive) return;
    shouldBePlayingNotifier.value = true;

    // En attente de synthèse : la phrase démarrera dès qu'elle sera prête.
    if (isSynthesizingNotifier.value) {
      _updateNotification(playing: true, loading: true);
      return;
    }
    if (_currentLoadedIndex == _currentIndex && _currentClip != null) {
      unawaited(_currentPlayer.play());
      _isPlaying = true;
      _startWordTracking();
      _updateNotification(playing: true);
    } else {
      await _playSentence(_currentIndex);
    }
  }

  @override
  Future<void> pause() async {
    shouldBePlayingNotifier.value = false;
    _isPlaying = false;
    _pauseWordTracking();
    await _currentPlayer.pause();
    _updateNotification(playing: false);
  }

  @override
  Future<void> skipToNext() async {
    final next = _currentIndex + 1;
    if (next < _sentenceTexts.length) {
      shouldBePlayingNotifier.value = true;
      await _playSentence(next);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final prev = _currentIndex - 1;
    if (prev >= 0) {
      shouldBePlayingNotifier.value = true;
      await _playSentence(prev);
    }
  }

  /// Sauter à une phrase précise (tap sur le texte ou navigation).
  Future<void> playSentenceAt(int index) async {
    if (index < 0 || index >= _sentenceTexts.length) return;
    shouldBePlayingNotifier.value = true;
    await _playSentence(index);
  }

  /// Positionner le curseur sans démarrer la lecture (navigation par chapitre).
  void stopAndSeekTo(int index) {
    _playToken++;
    _currentPlayer.stop();
    _bufferPlayer.stop();
    _currentLoadedIndex = null;
    _currentClip = null;
    _bufferIndex = null;
    _bufferClip = null;
    _resetWordTracking();
    _currentIndex = index;
    currentIndexNotifier.value = index;
    _isPlaying = false;
    shouldBePlayingNotifier.value = false;
    isSynthesizingNotifier.value = false;
    _updateNotification(playing: false);
    _kickPump();
  }

  // ── Lecture d'une phrase ───────────────────────────────────────────────────

  Future<void> _playSentence(int index) async {
    if (index < 0 || index >= _sentenceTexts.length) return;
    final myToken = ++_playToken;

    _currentIndex = index;
    currentIndexNotifier.value = index;
    _resetWordTracking();
    _updateMediaItem();
    _kickPump(); // repart de la nouvelle position (priorité à cette phrase)

    TtsClip? clip = _ready[index];
    if (clip == null && !_failed.contains(index)) {
      isSynthesizingNotifier.value = true;
      _updateNotification(playing: shouldBePlayingNotifier.value, loading: true);
      _currentPlayer.stop();
      clip = await _waitFor(index);
      if (myToken != _playToken) return;
    }

    if (clip == null) {
      // Phrase impossible à synthétiser (ex: uniquement de la ponctuation) :
      // on passe à la suivante plutôt que de bloquer la lecture.
      isSynthesizingNotifier.value = false;
      debugPrint('[TTS] phrase $index ignorée (synthèse impossible)');
      if (shouldBePlayingNotifier.value) _onSentenceFinished();
      return;
    }

    try {
      if (_bufferIndex == index && _bufferClip != null) {
        // Déjà chargée dans le second lecteur : bascule instantanée.
        _currentPlayer.stop();
        _currentIdx = 1 - _currentIdx;
        _bufferIndex = null;
        _bufferClip = null;
      } else {
        _currentPlayer.stop();
        await _currentPlayer.setAudioSource(AudioSource.uri(Uri.file(clip.path)));
        if (myToken != _playToken) return;
      }
      _currentLoadedIndex = index;
      _currentClip = clip;
      await _tune(_currentPlayer, clip);
      if (myToken != _playToken) return;

      final spokenText = _spoken[index] ?? _sentenceTexts[index];
      spokenTextNotifier.value = spokenText;
      final words = spokenText
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      _currentWordTimings = clip.wordStarts.length == words.length
          ? [for (var i = 0; i < words.length; i++) WordTiming(words[i], clip.wordStarts[i])]
          : <WordTiming>[];

      if (shouldBePlayingNotifier.value) {
        // unawaited : le Future de play() ne se termine qu'à la fin de la phrase.
        unawaited(_currentPlayer.play());
        _isPlaying = true;
        _startWordTracking();
      } else {
        _isPlaying = false;
      }
      isSynthesizingNotifier.value = false;
      _updateNotification(playing: _isPlaying);
      unawaited(_preloadBuffer());
    } catch (e) {
      if (myToken != _playToken) return;
      isSynthesizingNotifier.value = false;
      debugPrint('[TTS] ❌ lecture phrase $index impossible : $e');
      _updateNotification(playing: false);
    }
  }

  /// Charge la phrase suivante dans le second lecteur, si elle est prête.
  Future<void> _preloadBuffer() async {
    final next = _currentIndex + 1;
    final clip = _ready[next];
    if (clip == null || _bufferIndex == next) return;
    final token = _playToken;
    try {
      _bufferIndex = null;
      _bufferClip = null;
      await _bufferPlayer.setAudioSource(AudioSource.uri(Uri.file(clip.path)));
      await _tune(_bufferPlayer, clip);
      if (token != _playToken || _currentIndex + 1 != next) return;
      _bufferIndex = next;
      _bufferClip = clip;
    } catch (e) {
      debugPrint('[TTS] préchargement lecteur impossible : $e');
    }
  }

  Future<TtsClip?> _waitFor(int index) {
    final ready = _ready[index];
    if (ready != null) return Future.value(ready);
    return (_waiters[index] ??= Completer<TtsClip?>()).future;
  }

  void _complete(int index, TtsClip? clip) {
    final w = _waiters.remove(index);
    if (w != null && !w.isCompleted) w.complete(clip);
  }

  // ── Boucle de synthèse ─────────────────────────────────────────────────────

  void _kickPump() {
    if (_pumping || !_isSessionActive) return;
    unawaited(_pump());
  }

  /// Prochaine phrase à synthétiser : la plus proche de la position actuelle
  /// qui manque (ou qui a été synthétisée à une autre vitesse), tant que
  /// l'avance visée n'est pas atteinte.
  int? _nextToSynthesize() {
    if (_sentenceTexts.isEmpty || _currentIndex >= _sentenceTexts.length) return null;
    var ahead = 0.0;
    final end = (_currentIndex + _maxSentencesAhead).clamp(0, _sentenceTexts.length - 1);
    for (var i = _currentIndex; i <= end; i++) {
      final c = _ready[i];
      if (c == null) {
        if (!_failed.contains(i)) return i;
        continue;
      }
      // Ancienne vitesse : à refaire, sauf la phrase en cours et la suivante
      // (déjà chargées dans les lecteurs, le lecteur compense l'écart).
      if (c.baseSpeed != _synthSpeed && i > _currentIndex + 1) return i;
      if (i > _currentIndex) ahead += c.duration * c.speed / (_speed * c.mood.speedFactor);
      if (ahead >= _targetSecondsAhead) return null;
    }
    return null;
  }

  Future<void> _pump() async {
    _pumping = true;
    try {
      while (_isSessionActive) {
        // L'IA locale (dictionnaire, traduction) travaille : on lui laisse
        // tout le processeur, sauf si la phrase à lire tout de suite manque.
        if (LocalLlmService.busy.value && _ready.containsKey(_currentIndex)) {
          await _waitLlmIdle();
          continue;
        }
        final index = _nextToSynthesize();
        if (index == null) break;
        final gen = _generation;
        var voice = _voiceName;
        final speed = _synthSpeed;
        var text = _sentenceTexts[index];
        final provider = _textProvider;
        final altVoice = _translationVoice;
        if (provider != null && altVoice != null) {
          try {
            final t = (await provider(index)).trim();
            if (t.isNotEmpty) {
              text = t;
              voice = altVoice;
            }
          } catch (e) {
            // Traduction impossible : la phrase originale est lue à la place.
            debugPrint('[TTS] traduction phrase $index impossible : $e');
          }
          if (gen != _generation) continue;
        }

        // Ce que la voix prononce : mots allongés et fautes de frappe
        // corrigés (un mot pour un mot, le surlignage reste aligné). _spoken
        // garde, lui, le texte d'origine.
        var toSpeak = text;
        try {
          toSpeak = await SpeechTextNormalizer.instance.normalize(text, _langOf(voice));
        } catch (e) {
          debugPrint('[TTS] nettoyage du texte impossible : $e');
        }
        var mood = Mood.neutral;
        if (expressiveReadingNotifier.value) {
          try {
            mood = await _moodFor(index);
          } catch (e) {
            mood = MoodRules.classify(_sentenceTexts[index]);
          }
        }
        if (gen != _generation) continue;

        TtsClip? clip;
        try {
          clip = await _synthesize(toSpeak, voice, speed, mood.profile);
        } catch (e) {
          debugPrint('[TTS] ⚠ synthèse phrase $index échouée : $e');
        }
        if (gen != _generation) continue; // voix/livre changé entre-temps

        if (clip == null) {
          _failed.add(index);
          _complete(index, null);
          continue;
        }
        _ready[index] = clip;
        _spoken[index] = text;
        _complete(index, clip);
        if (index == _currentIndex + 1) unawaited(_preloadBuffer());

        // Mémoire : on oublie ce qui est loin derrière (reste sur disque).
        _ready.removeWhere((i, _) => i < _currentIndex - 5);
        _spoken.removeWhere((i, _) => !_ready.containsKey(i));
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _waitLlmIdle() {
    final c = Completer<void>();
    void check() {
      if (!LocalLlmService.busy.value && !c.isCompleted) {
        LocalLlmService.busy.removeListener(check);
        c.complete();
      }
    }

    LocalLlmService.busy.addListener(check);
    check();
    // Garde-fou : jamais plus de 20 s de pause, quoi qu'il arrive.
    return c.future.timeout(const Duration(seconds: 20), onTimeout: () {
      LocalLlmService.busy.removeListener(check);
    });
  }

  /// [baseSpeed] : vitesse d'écoute choisie ; l'humeur la module à la
  /// synthèse (le moteur parle naturellement plus vite ou plus lentement).
  Future<TtsClip> _synthesize(
      String text, String voice, double baseSpeed, MoodProfile mood) async {
    final speed = _round(baseSpeed * mood.speedFactor);
    final pauseMs = mood.pauseAfterMs;
    final cache = TtsAudioCache.instance;
    final cached = await cache.get(voice, speed, text, pauseMs: pauseMs);
    if (cached != null) return cached.withMood(baseSpeed, mood);
    if (!SherpaTtsService.isSherpaVoice(voice)) {
      throw Exception('Voix non disponible : $voice');
    }
    final path = await cache.wavPathFor(voice, speed, text, pauseMs: pauseMs);
    final res = await SherpaTtsService.instance.synthesizeToFile(
      text: text,
      voiceName: voice,
      outPath: path,
      speed: speed,
    );
    var duration = res.duration;
    if (pauseMs > 0) {
      try {
        duration += await appendWavSilence(path, pauseMs);
      } catch (e) {
        debugPrint('[TTS] pause après la phrase impossible : $e');
      }
    }
    final clip = TtsClip(
      path: path,
      wordStarts: res.wordStarts,
      duration: duration,
      speed: speed,
      baseSpeed: baseSpeed,
      mood: mood,
    );
    await cache.put(clip);
    return clip;
  }

  /// Langue d'une voix, en code court (« fr », « en », « pt »).
  String _langOf(String voice) =>
      (SherpaTtsService.voiceByName(voice)?.languageCode ?? _languageCode)
          .split('-')
          .first
          .toLowerCase();

  /// Humeur de la phrase [index] : déjà connue, sinon l'IA de l'ordinateur
  /// (par lots, avec un peu de contexte, mémorisée pour les prochaines
  /// lectures), sinon des règles instantanées. Le téléphone n'utilise jamais
  /// son IA pour ça : la voix devrait s'interrompre.
  Future<Mood> _moodFor(int index) async {
    final known = _moods[index];
    if (known != null) return known;
    final text = _sentenceTexts[index];
    final lang = _langOf(_voiceName);
    final box = Hive.box('mood_cache');
    final cached = parseMood(box.get(moodCacheKey(lang, text)) as String?);
    if (cached != null) return _moods[index] = cached;

    if (DateTime.now().isAfter(_moodAiRetryAt)) {
      final gen = _generation;
      final end = math.min(index + _moodBatch, _sentenceTexts.length);
      final batch = _sentenceTexts.sublist(index, end);
      final context = _sentenceTexts.sublist(math.max(0, index - 2), index);
      List<Mood?>? labels;
      try {
        labels = await LocalLlmService.instance
            .classifyMoods(batch, context: context)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        labels = null;
      }
      // Livre ou voix changé pendant la demande : ces index ne correspondent
      // plus aux mêmes phrases (le cache disque, lui, reste juste).
      if (gen != _generation) {
        if (labels != null) {
          for (var k = 0; k < labels.length; k++) {
            final m = labels[k];
            if (m != null) unawaited(box.put(moodCacheKey(lang, batch[k]), m.name));
          }
        }
        return Mood.neutral;
      }
      if (labels == null) {
        _moodAiRetryAt = DateTime.now().add(const Duration(minutes: 1));
      } else {
        for (var k = 0; k < labels.length; k++) {
          final m = labels[k];
          if (m == null) continue;
          _moods[index + k] = m;
          unawaited(box.put(moodCacheKey(lang, batch[k]), m.name));
        }
        final fromAi = _moods[index];
        if (fromAi != null) return fromAi;
      }
    }
    return _moods[index] = MoodRules.classify(text);
  }

  // ── Suivi mot par mot ─────────────────────────────────────────────────────

  void _resetWordTracking() {
    _wordTrackingTimer?.cancel();
    _wordTrackingTimer = null;
    _currentWordTimings = [];
    currentWordIndexNotifier.value = -1;
    spokenWordIndexNotifier.value = -1;
  }

  /// Mot actif dans le texte prononcé → mot à surligner dans le livre. En
  /// lecture de traduction, les mots ne se correspondent pas un à un : on
  /// avance dans la phrase originale au même rythme (en proportion).
  void _setActiveWord(int spokenIdx) {
    if (spokenIdx != spokenWordIndexNotifier.value) {
      spokenWordIndexNotifier.value = spokenIdx;
    }
    var bookIdx = spokenIdx;
    final spokenCount = _currentWordTimings.length;
    if (_spoken[_currentIndex] != null &&
        _spoken[_currentIndex] != _sentenceTexts[_currentIndex] &&
        spokenIdx >= 0 &&
        spokenCount > 0) {
      final bookCount = _sentenceTexts[_currentIndex].split(' ').length;
      bookIdx = ((spokenIdx + 0.5) * bookCount / spokenCount).floor().clamp(0, bookCount - 1);
    }
    if (bookIdx != currentWordIndexNotifier.value) {
      currentWordIndexNotifier.value = bookIdx;
    }
  }

  void _pauseWordTracking() {
    _wordTrackingTimer?.cancel();
    _wordTrackingTimer = null;
  }

  /// Repli si l'alignement n'a pas pu fournir un instant par mot : répartit
  /// la durée réelle au prorata de la longueur des mots.
  List<WordTiming> _estimateWordTimings(String text, Duration? duration) {
    if (duration == null || duration <= Duration.zero) return const [];
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final totalChars = words.fold<int>(0, (sum, w) => sum + w.length) + (words.length - 1);
    if (totalChars <= 0) return const [];
    final totalSeconds = duration.inMilliseconds / 1000.0;
    final timings = <WordTiming>[];
    var charsBefore = 0;
    for (final word in words) {
      timings.add(WordTiming(word, totalSeconds * charsBefore / totalChars));
      charsBefore += word.length + 1;
    }
    return timings;
  }

  /// Interroge la position de lecture toutes les 25 ms pour savoir quel mot
  /// est prononcé (la position est dans le temps de l'audio lui-même).
  void _startWordTracking() {
    _wordTrackingTimer?.cancel();
    if (_currentWordTimings.isEmpty && _currentIndex < _sentenceTexts.length) {
      _currentWordTimings = _estimateWordTimings(
          _spoken[_currentIndex] ?? _sentenceTexts[_currentIndex], _currentPlayer.duration);
    }
    if (_currentWordTimings.isEmpty) return;
    _setActiveWord(0);
    _wordTrackingTimer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      final posSeconds = _currentPlayer.position.inMilliseconds / 1000.0;
      var idx = -1;
      for (var i = 0; i < _currentWordTimings.length; i++) {
        if (_currentWordTimings[i].time <= posSeconds) {
          idx = i;
        } else {
          break;
        }
      }
      _setActiveWord(idx);
    });
  }

  // ── Notification Android ───────────────────────────────────────────────────

  void _updateNotification({required bool playing, bool loading = false}) {
    final position = Duration(seconds: _currentIndex);
    playbackState.add(playbackState.value.copyWith(
      playing: playing,
      processingState:
          loading ? AudioProcessingState.loading : AudioProcessingState.ready,
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      systemActions: const {
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
      },
      updatePosition: position,
      speed: _speed,
    ));
  }

  void _updateMediaItem() {
    final total = _sentenceTexts.length;
    mediaItem.add(MediaItem(
      id: 'talktome_current',
      title: _bookTitle,
      artist: _currentL10n().audioHandler_sentenceProgress(_currentIndex + 1, total),
      duration: Duration(seconds: total),
    ));
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  /// Réinitialise complètement le handler quand on quitte le lecteur.
  void reset() {
    _playToken++;
    _isSessionActive = false;
    _isPlaying = false;
    _speedDebounce?.cancel();
    _currentPlayer.stop();
    _bufferPlayer.stop();
    _currentLoadedIndex = null;
    _currentClip = null;
    _textProvider = null;
    _translationVoice = null;
    spokenTextNotifier.value = null;
    _invalidatePipeline();
    for (final w in _waiters.values) {
      if (!w.isCompleted) w.complete(null);
    }
    _waiters.clear();
    _resetWordTracking();
    isSynthesizingNotifier.value = false;
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    mediaItem.add(null);
  }
}
