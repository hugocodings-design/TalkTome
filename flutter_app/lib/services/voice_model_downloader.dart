import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'sherpa_tts_service.dart';

/// Étape d'installation d'un modèle de voix IA.
enum VoiceDownloadPhase { downloading, extracting, failed }

/// Avancement d'une installation en cours.
class VoiceDownloadState {
  const VoiceDownloadState(this.phase, {this.progress = 0, this.error});

  final VoiceDownloadPhase phase;

  /// 0 → 1 pendant le téléchargement (inconnu pendant la décompression).
  final double progress;
  final String? error;
}

/// Télécharge et installe les voix IA (sherpa-onnx) directement depuis
/// l'application, dans le dossier où [SherpaTtsService] les cherche.
///
/// Les archives viennent des versions officielles de sherpa-onnx sur GitHub
/// (mêmes fichiers que ceux copiés à la main sur le téléphone Android) : le
/// nom de chaque archive est exactement le dossier attendu par le service.
class VoiceModelDownloader {
  VoiceModelDownloader._();
  static final VoiceModelDownloader instance = VoiceModelDownloader._();

  static const String _baseUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models';

  /// Taille approximative de chaque téléchargement, en Mo (affichage).
  static const Map<String, int> downloadSizeMb = {
    'kokoro': 334,
    'fr-miro': 64,
    'fr-tom': 64,
    'fr-upmc': 77,
    'pt-tugao': 64,
    'pt-miro': 64,
    'pt-dii': 64,
    'pt-faber': 64,
    'pt-jeff': 64,
    'supertonic3': 123,
    'pocket': 95,
  };

  static String urlFor(SherpaModelSpec spec) =>
      '$_baseUrl/${spec.folder}.tar.bz2';

  final Dio _dio = Dio();

  /// Installations en cours (ou en échec), par identifiant de modèle.
  final ValueNotifier<Map<String, VoiceDownloadState>> states =
      ValueNotifier(const {});

  final Map<String, CancelToken> _cancelTokens = {};

  bool isBusy(String modelId) {
    final s = states.value[modelId];
    return s != null && s.phase != VoiceDownloadPhase.failed;
  }

  void _set(String modelId, VoiceDownloadState? state) {
    final next = Map<String, VoiceDownloadState>.from(states.value);
    if (state == null) {
      next.remove(modelId);
    } else {
      next[modelId] = state;
    }
    states.value = next;
  }

  /// Télécharge puis décompresse le modèle [modelId]. Le dossier final
  /// n'apparaît qu'une fois tout décompressé : une installation interrompue
  /// ne laisse jamais un modèle à moitié présent.
  Future<void> install(String modelId) async {
    if (isBusy(modelId)) return;
    final spec = SherpaTtsService.modelById(modelId);
    final root = await SherpaTtsService.instance.modelsRoot();
    final work = Directory('${root.path}/.download-${spec.folder}');
    final archivePath = '${work.path}/${spec.folder}.tar.bz2';
    final extractDir = '${work.path}/extract';
    final finalDir = Directory('${root.path}/${spec.folder}');

    final cancel = CancelToken();
    _cancelTokens[modelId] = cancel;
    _set(modelId, const VoiceDownloadState(VoiceDownloadPhase.downloading));

    try {
      if (await work.exists()) await work.delete(recursive: true);
      await work.create(recursive: true);

      var lastShown = -1;
      await _dio.download(
        urlFor(spec),
        archivePath,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final percent = received * 100 ~/ total;
          if (percent == lastShown) return; // pas de rafraîchissement inutile
          lastShown = percent;
          _set(modelId, VoiceDownloadState(VoiceDownloadPhase.downloading,
              progress: received / total));
        },
      );

      _set(modelId, const VoiceDownloadState(VoiceDownloadPhase.extracting));
      // Décompression bzip2 en pur Dart : lourde, donc hors du fil principal.
      await Isolate.run(() => extractFileToDisk(archivePath, extractDir));

      final extracted = Directory('$extractDir/${spec.folder}');
      if (!await File('${extracted.path}/${spec.modelFile}').exists()) {
        throw StateError('Archive incomplète : ${spec.modelFile} introuvable');
      }
      // Fichiers complémentaires (extraits de voix de Pocket TTS), rangés
      // dans le dossier du modèle avant qu'il ne devienne visible.
      for (final extra in spec.extraFiles.entries) {
        final target = File('${extracted.path}/${extra.key}');
        await target.parent.create(recursive: true);
        await _dio.download(extra.value, target.path, cancelToken: cancel);
      }
      if (await finalDir.exists()) await finalDir.delete(recursive: true);
      await extracted.rename(finalDir.path);
      _set(modelId, null);
    } catch (e) {
      if (cancel.isCancelled) {
        _set(modelId, null);
      } else {
        debugPrint('[VOICES] installation de ${spec.folder} échouée : $e');
        _set(modelId,
            VoiceDownloadState(VoiceDownloadPhase.failed, error: '$e'));
      }
    } finally {
      _cancelTokens.remove(modelId);
      if (await work.exists()) {
        try {
          await work.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Interrompt un téléchargement en cours.
  void cancel(String modelId) => _cancelTokens[modelId]?.cancel();

  /// Efface l'échec affiché pour [modelId].
  void dismissError(String modelId) {
    if (states.value[modelId]?.phase == VoiceDownloadPhase.failed) {
      _set(modelId, null);
    }
  }

  /// Supprime un modèle installé pour libérer de la place.
  Future<void> remove(String modelId) async {
    final spec = SherpaTtsService.modelById(modelId);
    final root = await SherpaTtsService.instance.modelsRoot();
    final dir = Directory('${root.path}/${spec.folder}');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
