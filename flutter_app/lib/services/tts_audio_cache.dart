import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'sentence_mood.dart';

/// Phrase synthétisée, prête à jouer.
class TtsClip {
  const TtsClip({
    required this.path,
    required this.wordStarts,
    required this.duration,
    required this.speed,
    double? baseSpeed,
    this.mood = MoodProfile.neutral,
  }) : baseSpeed = baseSpeed ?? speed;

  final String path;

  /// Début de chaque mot (secondes, dans l'audio lui-même).
  final List<double> wordStarts;

  /// Durée de l'audio (secondes), à la vitesse où il a été synthétisé.
  final double duration;

  /// Vitesse à laquelle l'audio a été synthétisé (humeur comprise).
  final double speed;

  /// Vitesse d'écoute demandée au moment de la synthèse, sans l'humeur.
  final double baseSpeed;

  /// Humeur appliquée (lecture expressive) ; neutre sinon.
  final MoodProfile mood;

  TtsClip withMood(double baseSpeed, MoodProfile mood) => TtsClip(
        path: path,
        wordStarts: wordStarts,
        duration: duration,
        speed: speed,
        baseSpeed: baseSpeed,
        mood: mood,
      );
}

/// Cache disque des phrases déjà synthétisées, BORNÉ : il ne dépasse jamais
/// [maxBytes] et rien n'y reste plus de [maxAge]. Il vit dans le dossier
/// cache de l'app (Android peut aussi le vider s'il manque de place). Relire
/// un passage, revenir en arrière ou rouvrir un livre récent est instantané.
class TtsAudioCache {
  TtsAudioCache._();
  static final TtsAudioCache instance = TtsAudioCache._();

  /// ~1 h 45 d'audio (WAV 24 kHz, 16 bits).
  static const int maxBytes = 300 * 1024 * 1024;
  static const Duration maxAge = Duration(days: 3);

  Directory? _dir;
  int _writesSinceTrim = 0;

  Future<Directory> _directory() async {
    final existing = _dir;
    if (existing != null) return existing;
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/tts_audio');
    await dir.create(recursive: true);
    _dir = dir;
    // Au premier accès : faire le ménage (fichiers trop vieux, taille max)
    // et supprimer les fichiers de l'ancien système de préchargement.
    await _trim();
    try {
      for (final f in tmp.listSync()) {
        if (f is File &&
            RegExp(r'(sentence|prefetch2?)_\d+\.wav$').hasMatch(f.path)) {
          f.deleteSync();
        }
      }
    } catch (_) {}
    return dir;
  }

  /// v3 (2026-11-23) : silences de début/fin raccourcis (Supertonic), phrases
  /// de Pocket TTS qui ne s'arrêtaient pas (plafond de longueur + reprise).
  /// v4 : texte nettoyé pour Pocket TTS (guillemets, …, parenthèses).
  static const String _audioVersion = 'v4';

  /// FNV-1a 64 bits : nom de fichier stable pour (voix, vitesse, texte, et
  /// silence ajouté après la phrase s'il y en a un).
  static String _key(String voice, double speed, String text, int pauseMs) {
    var h = 0xcbf29ce484222325;
    final pause = pauseMs > 0 ? '|p$pauseMs' : '';
    // [_audioVersion] : change quand la fabrication de l'audio change, pour
    // ne pas rejouer d'anciens fichiers (le ménage efface ces derniers).
    for (final c in utf8.encode('$_audioVersion|$voice|${speed.toStringAsFixed(2)}|$text$pause')) {
      h ^= c;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${h.toUnsigned(64).toRadixString(16)}_${text.length}';
  }

  /// Chemin où écrire le WAV d'une nouvelle synthèse.
  Future<String> wavPathFor(String voice, double speed, String text, {int pauseMs = 0}) async =>
      '${(await _directory()).path}/${_key(voice, speed, text, pauseMs)}.wav';

  Future<TtsClip?> get(String voice, double speed, String text, {int pauseMs = 0}) async {
    final base = '${(await _directory()).path}/${_key(voice, speed, text, pauseMs)}';
    final wav = File('$base.wav');
    final meta = File('$base.json');
    try {
      if (!await meta.exists() || !await wav.exists()) return null;
      final j = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      // Marque comme récemment utilisé (le ménage supprime les plus anciens).
      unawaited(wav.setLastModified(DateTime.now()).catchError((_) {}));
      return TtsClip(
        path: wav.path,
        wordStarts: (j['t'] as List).map((e) => (e as num).toDouble()).toList(),
        duration: (j['d'] as num).toDouble(),
        speed: speed,
      );
    } catch (_) {
      return null;
    }
  }

  /// Enregistre les métadonnées d'un WAV déjà écrit à [TtsClip.path].
  Future<void> put(TtsClip clip) async {
    final base = clip.path.substring(0, clip.path.length - 4);
    await File('$base.json')
        .writeAsString(jsonEncode({'t': clip.wordStarts, 'd': clip.duration}));
    if (++_writesSinceTrim >= 25) {
      _writesSinceTrim = 0;
      await _trim();
    }
  }

  Future<void> _trim() async {
    final dir = _dir;
    if (dir == null) return;
    try {
      final now = DateTime.now();
      final wavs = <(File, FileStat)>[];
      var total = 0;
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        if (e.path.endsWith('.json')) {
          // Métadonnées orphelines (WAV déjà supprimé).
          final wav = File('${e.path.substring(0, e.path.length - 5)}.wav');
          if (!wav.existsSync()) e.deleteSync();
          continue;
        }
        final st = e.statSync();
        if (now.difference(st.modified) > maxAge) {
          _delete(e);
          continue;
        }
        wavs.add((e, st));
        total += st.size;
      }
      if (total <= maxBytes) return;
      wavs.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (f, st) in wavs) {
        if (total <= maxBytes * 0.85) break;
        _delete(f);
        total -= st.size;
      }
    } catch (e) {
      debugPrint('[TTS-CACHE] ménage impossible : $e');
    }
  }

  void _delete(File wav) {
    try {
      wav.deleteSync();
      final meta = File('${wav.path.substring(0, wav.path.length - 4)}.json');
      if (meta.existsSync()) meta.deleteSync();
    } catch (_) {}
  }
}
