import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'pc_boost_service.dart';
import 'word_aligner.dart';

/// Moteurs de synthèse. Tous tournent sur le téléphone, sauf [qwen3] qui
/// n'existe que sur l'ordinateur (TalkTome Boost).
enum SherpaModelKind { piper, kokoro, supertonic, pocket, qwen3 }

/// Un modèle de synthèse vocale installé dans `<support>/tts_models/<folder>`.
class SherpaModelSpec {
  const SherpaModelSpec({
    required this.id,
    required this.folder,
    required this.kind,
    required this.modelFile,
    required this.label,
    this.runsOnPhone = true,
    this.extraFiles = const {},
  });

  final String id;
  final String folder;
  final SherpaModelKind kind;
  final String modelFile;
  final String label;

  /// Faux : le modèle n'existe que sur l'ordinateur (TalkTome Boost) ; ses
  /// voix ne marchent pas avec le téléphone seul.
  final bool runsOnPhone;

  /// Fichiers à télécharger en plus de l'archive, rangés dans le dossier du
  /// modèle : chemin relatif → adresse (extraits de voix de Pocket TTS).
  final Map<String, String> extraFiles;

  /// Nom du moteur, affiché devant chaque voix pour savoir laquelle est
  /// laquelle.
  String get engineName => switch (kind) {
        SherpaModelKind.kokoro => 'Kokoro',
        SherpaModelKind.piper => 'Piper',
        SherpaModelKind.supertonic => 'Supertonic 3',
        SherpaModelKind.pocket => 'Pocket TTS',
        SherpaModelKind.qwen3 => 'Qwen3-TTS',
      };
}

/// Une voix proposée dans le sélecteur. Un même modèle peut en porter
/// plusieurs (Kokoro : des dizaines ; Piper « upmc » : deux).
class SherpaVoice {
  const SherpaVoice({
    required this.name,
    required this.displayName,
    required this.languageCode,
    required this.modelId,
    this.sid = 0,
    this.lang = '',
    this.britishLexicon = false,
    this.gender = '',
    this.reference = '',
  });

  final String name;
  final String displayName;
  final String languageCode;
  final String modelId;
  final int sid;

  /// Langue de prononciation : eSpeak pour Kokoro (« fr », « pt-br » ; vide
  /// pour l'anglais, qui passe par le lexique), code de langue pour
  /// Supertonic (« fr », « en », « pt »), nom de langue pour Qwen3-TTS
  /// (« French »…).
  final String lang;

  /// Kokoro : lexique britannique (voix en-GB) plutôt qu'américain.
  final bool britishLexicon;

  /// « F » ou « M ».
  final String gender;

  /// Pocket TTS : extrait de voix (relatif au dossier du modèle) imité par
  /// le moteur.
  final String reference;

  /// Configuration du moteur nécessaire à cette voix : changer de clé
  /// impose de recharger le modèle. Supertonic et Pocket choisissent langue
  /// et voix à chaque phrase : un seul moteur pour toutes leurs voix.
  String get engineKey {
    final kind = SherpaTtsService.modelById(modelId).kind;
    if (kind == SherpaModelKind.supertonic || kind == SherpaModelKind.pocket) {
      return modelId;
    }
    return '$modelId|$lang|${britishLexicon ? 'gb' : 'us'}';
  }
}

/// Voix réservée à l'ordinateur alors que TalkTome Boost ne répond pas.
class PcRequiredException implements Exception {
  const PcRequiredException(this.voiceName);
  final String voiceName;
  @override
  String toString() =>
      'La voix $voiceName ne fonctionne qu\'avec l\'ordinateur (TalkTome Boost), '
      'qui ne répond pas.';
}

/// Résultat d'une synthèse : instant de début de chaque mot (secondes, dans
/// l'audio produit) et durée totale.
class SherpaSynthesis {
  const SherpaSynthesis(this.wordStarts, this.duration);
  final List<double> wordStarts;
  final double duration;
}

/// Voix IA locales, gratuites : synthèse neuronale faite sur le téléphone
/// (sherpa-onnx). Aucune clé API, aucun réseau — seulement des fichiers de
/// modèle présents sur l'appareil.
class SherpaTtsService {
  SherpaTtsService._();
  static final SherpaTtsService instance = SherpaTtsService._();

  static const String voicePrefix = 'sherpa-';
  static bool isSherpaVoice(String voiceName) =>
      voiceName.startsWith(voicePrefix);

  /// Threads du moteur de synthèse (cœurs « performance » du téléphone).
  static int threads = 4;

  static const List<SherpaModelSpec> models = [
    // Kokoro pleine précision (fp32) : la meilleure qualité disponible hors
    // ligne. La version compressée (int8) donnait un timbre métallique.
    SherpaModelSpec(
      id: 'kokoro',
      folder: 'kokoro-multi-lang-v1_0',
      kind: SherpaModelKind.kokoro,
      modelFile: 'model.onnx',
      label: 'Kokoro',
    ),
    // Supertonic 3 : 31 langues, 10 voix (F1–F5, M1–M5) communes à toutes
    // les langues. Seule une version int8 est publiée pour sherpa-onnx.
    SherpaModelSpec(
      id: 'supertonic3',
      folder: 'sherpa-onnx-supertonic-3-tts-int8-2026-05-11',
      kind: SherpaModelKind.supertonic,
      modelFile: 'vector_estimator.int8.onnx',
      label: 'Supertonic 3',
    ),
    // Pocket TTS (Kyutai) : anglais, voix imitée à partir d'un court extrait
    // (corpus VCTK, CC-BY-4.0). Version int8 : la pleine précision est plus
    // lente que le temps réel sur processeur.
    SherpaModelSpec(
      id: 'pocket',
      folder: 'sherpa-onnx-pocket-tts-int8-2026-01-26',
      kind: SherpaModelKind.pocket,
      modelFile: 'lm_main.int8.onnx',
      label: 'Pocket TTS',
      extraFiles: {
        'voices/anna.wav': 'https://huggingface.co/kyutai/tts-voices/resolve/main/vctk/p228_023_enhanced.wav',
        'voices/vera.wav': 'https://huggingface.co/kyutai/tts-voices/resolve/main/vctk/p229_023_enhanced.wav',
        'voices/jane.wav': 'https://huggingface.co/kyutai/tts-voices/resolve/main/vctk/p339_023_enhanced.wav',
        'voices/charles.wav': 'https://huggingface.co/kyutai/tts-voices/resolve/main/vctk/p254_023_enhanced.wav',
        'voices/paul.wav': 'https://huggingface.co/kyutai/tts-voices/resolve/main/vctk/p259_023_enhanced.wav',
        'voices/george.wav': 'https://huggingface.co/kyutai/tts-voices/resolve/main/vctk/p315_023_enhanced.wav',
      },
    ),
    // Qwen3-TTS : tourne uniquement sur l'ordinateur (TalkTome Boost), rien
    // à installer sur le téléphone.
    SherpaModelSpec(
      id: 'qwen3tts',
      folder: '',
      kind: SherpaModelKind.qwen3,
      modelFile: '',
      label: 'Qwen3-TTS (ordinateur)',
      runsOnPhone: false,
    ),
    SherpaModelSpec(
      id: 'fr-miro',
      folder: 'vits-piper-fr_FR-miro-high',
      kind: SherpaModelKind.piper,
      modelFile: 'fr_FR-miro-high.onnx',
      label: 'Piper · Miro (FR)',
    ),
    SherpaModelSpec(
      id: 'fr-tom',
      folder: 'vits-piper-fr_FR-tom-medium',
      kind: SherpaModelKind.piper,
      modelFile: 'fr_FR-tom-medium.onnx',
      label: 'Piper · Tom (FR)',
    ),
    SherpaModelSpec(
      id: 'fr-upmc',
      folder: 'vits-piper-fr_FR-upmc-medium',
      kind: SherpaModelKind.piper,
      modelFile: 'fr_FR-upmc-medium.onnx',
      label: 'Piper · UPMC (FR)',
    ),
    SherpaModelSpec(
      id: 'pt-tugao',
      folder: 'vits-piper-pt_PT-tugao-medium',
      kind: SherpaModelKind.piper,
      modelFile: 'pt_PT-tugao-medium.onnx',
      label: 'Piper · Tugão (PT)',
    ),
    SherpaModelSpec(
      id: 'pt-miro',
      folder: 'vits-piper-pt_PT-miro-high',
      kind: SherpaModelKind.piper,
      modelFile: 'pt_PT-miro-high.onnx',
      label: 'Piper · Miro (PT)',
    ),
    SherpaModelSpec(
      id: 'pt-dii',
      folder: 'vits-piper-pt_PT-dii-high',
      kind: SherpaModelKind.piper,
      modelFile: 'pt_PT-dii-high.onnx',
      label: 'Piper · Dii (PT)',
    ),
    SherpaModelSpec(
      id: 'pt-faber',
      folder: 'vits-piper-pt_BR-faber-medium',
      kind: SherpaModelKind.piper,
      modelFile: 'pt_BR-faber-medium.onnx',
      label: 'Piper · Faber (BR)',
    ),
    SherpaModelSpec(
      id: 'pt-jeff',
      folder: 'vits-piper-pt_BR-jeff-medium',
      kind: SherpaModelKind.piper,
      modelFile: 'pt_BR-jeff-medium.onnx',
      label: 'Piper · Jeff (BR)',
    ),
  ];

  /// Ordre d'affichage : anglais, français, puis portugais. Dans chaque
  /// langue, les voix Kokoro (meilleure qualité) passent en premier.
  /// Identifiants Kokoro : ordre des voix du modèle multi-lang v1.0.
  static const List<SherpaVoice> voices = [
    // ── Anglais ──
    SherpaVoice(
      name: 'sherpa-kokoro-af_heart',
      displayName: 'Heart',
      languageCode: 'en-US',
      modelId: 'kokoro',
      sid: 3,
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-kokoro-af_bella',
      displayName: 'Bella',
      languageCode: 'en-US',
      modelId: 'kokoro',
      sid: 2,
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-kokoro-am_michael',
      displayName: 'Michael',
      languageCode: 'en-US',
      modelId: 'kokoro',
      sid: 16,
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-kokoro-bf_emma',
      displayName: 'Emma',
      languageCode: 'en-GB',
      modelId: 'kokoro',
      sid: 21,
      britishLexicon: true,
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-kokoro-bm_george',
      displayName: 'George',
      languageCode: 'en-GB',
      modelId: 'kokoro',
      sid: 26,
      britishLexicon: true,
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-kokoro-am_fenrir',
      displayName: 'Fenrir',
      languageCode: 'en-US',
      modelId: 'kokoro',
      sid: 14,
      gender: 'M',
    ),
    // Supertonic 3 (en) : F1–F3 = identifiants 0–2, M1–M3 = 5–7.
    SherpaVoice(
      name: 'sherpa-supertonic-en-f1',
      displayName: 'F1',
      languageCode: 'en-US',
      modelId: 'supertonic3',
      sid: 0,
      lang: 'en',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-en-f2',
      displayName: 'F2',
      languageCode: 'en-US',
      modelId: 'supertonic3',
      sid: 1,
      lang: 'en',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-en-f3',
      displayName: 'F3',
      languageCode: 'en-US',
      modelId: 'supertonic3',
      sid: 2,
      lang: 'en',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-en-m1',
      displayName: 'M1',
      languageCode: 'en-US',
      modelId: 'supertonic3',
      sid: 5,
      lang: 'en',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-en-m2',
      displayName: 'M2',
      languageCode: 'en-US',
      modelId: 'supertonic3',
      sid: 6,
      lang: 'en',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-en-m3',
      displayName: 'M3',
      languageCode: 'en-US',
      modelId: 'supertonic3',
      sid: 7,
      lang: 'en',
      gender: 'M',
    ),
    // Pocket TTS (anglais) : voix VCTK (CC-BY-4.0) du catalogue Kyutai.
    SherpaVoice(
      name: 'sherpa-pocket-anna',
      displayName: 'Anna',
      languageCode: 'en-GB',
      modelId: 'pocket',
      gender: 'F',
      reference: 'voices/anna.wav',
    ),
    SherpaVoice(
      name: 'sherpa-pocket-vera',
      displayName: 'Vera',
      languageCode: 'en-GB',
      modelId: 'pocket',
      gender: 'F',
      reference: 'voices/vera.wav',
    ),
    SherpaVoice(
      name: 'sherpa-pocket-jane',
      displayName: 'Jane',
      languageCode: 'en-US',
      modelId: 'pocket',
      gender: 'F',
      reference: 'voices/jane.wav',
    ),
    SherpaVoice(
      name: 'sherpa-pocket-charles',
      displayName: 'Charles',
      languageCode: 'en-GB',
      modelId: 'pocket',
      gender: 'M',
      reference: 'voices/charles.wav',
    ),
    SherpaVoice(
      name: 'sherpa-pocket-paul',
      displayName: 'Paul',
      languageCode: 'en-GB',
      modelId: 'pocket',
      gender: 'M',
      reference: 'voices/paul.wav',
    ),
    SherpaVoice(
      name: 'sherpa-pocket-george',
      displayName: 'George',
      languageCode: 'en-US',
      modelId: 'pocket',
      gender: 'M',
      reference: 'voices/george.wav',
    ),
    // Qwen3-TTS (en) — ordinateur uniquement ; voix décrites dans
    // pc_server/qwen_voices.json (mêmes identifiants).
    SherpaVoice(
      name: 'sherpa-qwen3-en-f1',
      displayName: 'Olivia',
      languageCode: 'en-US',
      modelId: 'qwen3tts',
      lang: 'English',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-en-f2',
      displayName: 'Grace',
      languageCode: 'en-US',
      modelId: 'qwen3tts',
      lang: 'English',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-en-f3',
      displayName: 'Hannah',
      languageCode: 'en-US',
      modelId: 'qwen3tts',
      lang: 'English',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-en-m1',
      displayName: 'Daniel',
      languageCode: 'en-US',
      modelId: 'qwen3tts',
      lang: 'English',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-en-m2',
      displayName: 'James',
      languageCode: 'en-US',
      modelId: 'qwen3tts',
      lang: 'English',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-en-m3',
      displayName: 'Ethan',
      languageCode: 'en-US',
      modelId: 'qwen3tts',
      lang: 'English',
      gender: 'M',
    ),
    // ── Français ──
    // Même nom qu'avant (ancienne voix Piper Siwis) : les livres qui
    // l'utilisaient passent automatiquement à la version Kokoro, bien meilleure.
    SherpaVoice(
      name: 'sherpa-fr-siwis',
      displayName: 'Siwis',
      languageCode: 'fr-FR',
      modelId: 'kokoro',
      sid: 30,
      lang: 'fr',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-fr-miro',
      displayName: 'Miro',
      languageCode: 'fr-FR',
      modelId: 'fr-miro',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-fr-tom',
      displayName: 'Tom',
      languageCode: 'fr-FR',
      modelId: 'fr-tom',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-fr-upmc-jessica',
      displayName: 'Jessica',
      languageCode: 'fr-FR',
      modelId: 'fr-upmc',
      sid: 0,
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-fr-upmc-pierre',
      displayName: 'Pierre',
      languageCode: 'fr-FR',
      modelId: 'fr-upmc',
      sid: 1,
      gender: 'M',
    ),
    // Supertonic 3 (fr) : F1–F3 = identifiants 0–2, M1–M3 = 5–7.
    SherpaVoice(
      name: 'sherpa-supertonic-fr-f1',
      displayName: 'F1',
      languageCode: 'fr-FR',
      modelId: 'supertonic3',
      sid: 0,
      lang: 'fr',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-fr-f2',
      displayName: 'F2',
      languageCode: 'fr-FR',
      modelId: 'supertonic3',
      sid: 1,
      lang: 'fr',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-fr-f3',
      displayName: 'F3',
      languageCode: 'fr-FR',
      modelId: 'supertonic3',
      sid: 2,
      lang: 'fr',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-fr-m1',
      displayName: 'M1',
      languageCode: 'fr-FR',
      modelId: 'supertonic3',
      sid: 5,
      lang: 'fr',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-fr-m2',
      displayName: 'M2',
      languageCode: 'fr-FR',
      modelId: 'supertonic3',
      sid: 6,
      lang: 'fr',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-fr-m3',
      displayName: 'M3',
      languageCode: 'fr-FR',
      modelId: 'supertonic3',
      sid: 7,
      lang: 'fr',
      gender: 'M',
    ),
    // Qwen3-TTS (fr) — ordinateur uniquement ; voix décrites dans
    // pc_server/qwen_voices.json (mêmes identifiants).
    SherpaVoice(
      name: 'sherpa-qwen3-fr-f1',
      displayName: 'Camille',
      languageCode: 'fr-FR',
      modelId: 'qwen3tts',
      lang: 'French',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-fr-f2',
      displayName: 'Élise',
      languageCode: 'fr-FR',
      modelId: 'qwen3tts',
      lang: 'French',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-fr-f3',
      displayName: 'Margaux',
      languageCode: 'fr-FR',
      modelId: 'qwen3tts',
      lang: 'French',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-fr-m1',
      displayName: 'Julien',
      languageCode: 'fr-FR',
      modelId: 'qwen3tts',
      lang: 'French',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-fr-m2',
      displayName: 'Antoine',
      languageCode: 'fr-FR',
      modelId: 'qwen3tts',
      lang: 'French',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-fr-m3',
      displayName: 'Mathis',
      languageCode: 'fr-FR',
      modelId: 'qwen3tts',
      lang: 'French',
      gender: 'M',
    ),
    // ── Portugais (Portugal) ──
    SherpaVoice(
      name: 'sherpa-pt-tugao',
      displayName: 'Tugão',
      languageCode: 'pt-PT',
      modelId: 'pt-tugao',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-pt-miro',
      displayName: 'Miro',
      languageCode: 'pt-PT',
      modelId: 'pt-miro',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-pt-dii',
      displayName: 'Dii',
      languageCode: 'pt-PT',
      modelId: 'pt-dii',
      gender: 'F',
    ),
    // ── Portugais (Brésil) ──
    SherpaVoice(
      name: 'sherpa-kokoro-pf_dora',
      displayName: 'Dora',
      languageCode: 'pt-BR',
      modelId: 'kokoro',
      sid: 42,
      lang: 'pt-br',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-kokoro-pm_alex',
      displayName: 'Alex',
      languageCode: 'pt-BR',
      modelId: 'kokoro',
      sid: 43,
      lang: 'pt-br',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-kokoro-pm_santa',
      displayName: 'Santa',
      languageCode: 'pt-BR',
      modelId: 'kokoro',
      sid: 44,
      lang: 'pt-br',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-pt-faber',
      displayName: 'Faber',
      languageCode: 'pt-BR',
      modelId: 'pt-faber',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-pt-jeff',
      displayName: 'Jeff',
      languageCode: 'pt-BR',
      modelId: 'pt-jeff',
      gender: 'M',
    ),
    // Supertonic 3 (pt) : F1–F3 = identifiants 0–2, M1–M3 = 5–7.
    SherpaVoice(
      name: 'sherpa-supertonic-pt-f1',
      displayName: 'F1',
      languageCode: 'pt-BR',
      modelId: 'supertonic3',
      sid: 0,
      lang: 'pt',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-pt-f2',
      displayName: 'F2',
      languageCode: 'pt-BR',
      modelId: 'supertonic3',
      sid: 1,
      lang: 'pt',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-pt-f3',
      displayName: 'F3',
      languageCode: 'pt-BR',
      modelId: 'supertonic3',
      sid: 2,
      lang: 'pt',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-pt-m1',
      displayName: 'M1',
      languageCode: 'pt-BR',
      modelId: 'supertonic3',
      sid: 5,
      lang: 'pt',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-pt-m2',
      displayName: 'M2',
      languageCode: 'pt-BR',
      modelId: 'supertonic3',
      sid: 6,
      lang: 'pt',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-supertonic-pt-m3',
      displayName: 'M3',
      languageCode: 'pt-BR',
      modelId: 'supertonic3',
      sid: 7,
      lang: 'pt',
      gender: 'M',
    ),
    // Qwen3-TTS (pt) — ordinateur uniquement ; voix décrites dans
    // pc_server/qwen_voices.json (mêmes identifiants).
    SherpaVoice(
      name: 'sherpa-qwen3-pt-f1',
      displayName: 'Inês',
      languageCode: 'pt-PT',
      modelId: 'qwen3tts',
      lang: 'Portuguese',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-pt-f2',
      displayName: 'Beatriz',
      languageCode: 'pt-PT',
      modelId: 'qwen3tts',
      lang: 'Portuguese',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-pt-f3',
      displayName: 'Leonor',
      languageCode: 'pt-PT',
      modelId: 'qwen3tts',
      lang: 'Portuguese',
      gender: 'F',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-pt-m1',
      displayName: 'Tiago',
      languageCode: 'pt-PT',
      modelId: 'qwen3tts',
      lang: 'Portuguese',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-pt-m2',
      displayName: 'Duarte',
      languageCode: 'pt-PT',
      modelId: 'qwen3tts',
      lang: 'Portuguese',
      gender: 'M',
    ),
    SherpaVoice(
      name: 'sherpa-qwen3-pt-m3',
      displayName: 'Rui',
      languageCode: 'pt-PT',
      modelId: 'qwen3tts',
      lang: 'Portuguese',
      gender: 'M',
    ),
  ];

  static SherpaVoice? voiceByName(String name) {
    for (final v in voices) {
      if (v.name == name) return v;
    }
    return null;
  }

  static SherpaModelSpec modelById(String id) =>
      models.firstWhere((m) => m.id == id);

  Future<Directory> modelsRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/tts_models');
  }

  Future<String> _modelDir(SherpaModelSpec spec) async =>
      '${(await modelsRoot()).path}/${spec.folder}';

  Future<bool> isModelInstalled(String modelId) async {
    final spec = modelById(modelId);
    if (!spec.runsOnPhone) return false;
    final dir = await _modelDir(spec);
    if (!await File('$dir/${spec.modelFile}').exists()) return false;
    for (final extra in spec.extraFiles.keys) {
      if (!await File('$dir/$extra').exists()) return false;
    }
    return true;
  }

  /// Seules les voix dont le modèle est effectivement présent sur le
  /// téléphone sont proposées.
  Future<List<SherpaVoice>> installedVoices() async {
    final installed = <String, bool>{};
    final result = <SherpaVoice>[];
    for (final v in voices) {
      installed[v.modelId] ??= await isModelInstalled(v.modelId);
      if (installed[v.modelId]!) result.add(v);
    }
    return result;
  }

  /// Première voix installée pour une langue (« fr », « pt »…), pour la
  /// prononciation d'un mot dans le dictionnaire.
  Future<SherpaVoice?> firstInstalledVoiceFor(String lang) async {
    for (final v in await installedVoices()) {
      if (v.languageCode.toLowerCase().startsWith(lang.toLowerCase())) return v;
    }
    return null;
  }

  // ── Synthèse (dans un isolate dédié : generate() est synchrone et lourd,
  //    sur le fil principal il ferait saccader l'écran et le surlignage) ────

  SendPort? _worker;
  Future<SendPort>? _workerStarting;

  Future<SendPort> _ensureWorker() {
    final existing = _worker;
    if (existing != null) return Future.value(existing);
    return _workerStarting ??= _startWorker();
  }

  Future<SendPort> _startWorker() async {
    final ready = ReceivePort();
    await Isolate.spawn(_workerMain, ready.sendPort);
    final port = await ready.first as SendPort;
    ready.close();
    _worker = port;
    return port;
  }

  /// Synthétise [text] avec la voix [voiceName], directement à la vitesse
  /// [speed] (le moteur parle plus vite lui-même : son naturel, et moins de
  /// calcul qu'en accélérant l'audio après coup), et écrit un WAV dans
  /// [outPath].
  Future<SherpaSynthesis> synthesizeToFile({
    required String text,
    required String voiceName,
    required String outPath,
    double speed = 1.0,
  }) async {
    final voice = voiceByName(voiceName);
    if (voice == null) {
      throw Exception('Voix IA locale inconnue : $voiceName');
    }
    final spec = modelById(voice.modelId);

    // Voix réservée à l'ordinateur (Qwen3-TTS) : pas de repli possible sur
    // le téléphone.
    if (!spec.runsOnPhone) {
      final remote = await PcBoostService.instance.synthesize(
        voiceSpec: {
          'folder': '',
          'kind': spec.kind.name,
          'modelFile': '',
          'voice': voice.name.substring(voicePrefix.length),
          'lang': voice.lang,
        },
        text: text,
        speed: speed,
        outPath: outPath,
        // Premier appel : l'ordinateur charge le modèle (plusieurs
        // secondes), et Qwen3-TTS est plus lent que les voix du téléphone.
        timeout: const Duration(seconds: 120),
      );
      if (remote != null) return SherpaSynthesis(remote.$1, remote.$2);
      throw PcRequiredException(voice.displayName);
    }

    // Ordinateur joignable (TalkTome Boost) : synthèse sur sa carte
    // graphique, ~13× temps réel au lieu de ~2×. Seulement pour Kokoro et
    // Piper, les moteurs que le serveur de l'ordinateur sait faire tourner ;
    // Supertonic et Pocket restent sur le téléphone (déjà rapides).
    if (spec.kind == SherpaModelKind.kokoro || spec.kind == SherpaModelKind.piper) {
      final remote = await PcBoostService.instance.synthesize(
        voiceSpec: {
          'folder': spec.folder,
          'kind': spec.kind.name,
          'modelFile': spec.modelFile,
          'sid': voice.sid,
          'lang': voice.lang,
          'gb': voice.britishLexicon,
        },
        text: text,
        speed: speed,
        outPath: outPath,
      );
      if (remote != null) return SherpaSynthesis(remote.$1, remote.$2);
    }

    final dir = await _modelDir(spec);
    if (!await File('$dir/${spec.modelFile}').exists()) {
      throw Exception('Modèle ${spec.label} non installé sur ce téléphone');
    }

    final worker = await _ensureWorker();
    final reply = ReceivePort();
    worker.send({
      'reply': reply.sendPort,
      'key': voice.engineKey,
      'kind': spec.kind.name,
      'dir': dir,
      'modelFile': spec.modelFile,
      'lang': voice.lang,
      'gb': voice.britishLexicon,
      'threads': threads,
      'text': text,
      'sid': voice.sid,
      'reference': voice.reference.isEmpty ? '' : '$dir/${voice.reference}',
      'speed': speed,
      'outPath': outPath,
    });
    final res = await reply.first as Map;
    reply.close();
    if (res['ok'] != true) {
      throw Exception(res['error'] ?? 'Échec de la synthèse locale');
    }
    return SherpaSynthesis(
      (res['times'] as List).cast<double>(),
      (res['duration'] as num).toDouble(),
    );
  }
}

// ── Isolate de synthèse ─────────────────────────────────────────────────────

void _workerMain(SendPort mainPort) {
  final inbox = ReceivePort();
  mainPort.send(inbox.sendPort);
  sherpa.initBindings();

  String? loadedKey;
  sherpa.OfflineTts? tts;
  final references = <String, (Float32List, int)>{};

  inbox.listen((dynamic raw) {
    final msg = raw as Map;
    final reply = msg['reply'] as SendPort;
    try {
      final key = '${msg['key']}|${msg['threads']}';
      if (key != loadedKey) {
        tts?.free();
        tts = null;
        loadedKey = null;
        tts = sherpa.OfflineTts(_buildConfig(msg));
        loadedKey = key;
      }

      final kind = msg['kind'] as String;
      final text = msg['text'] as String;
      final sid = msg['sid'] as int;
      final speed = (msg['speed'] as num).toDouble();
      final sherpa.GeneratedAudio audio;
      if (kind == SherpaModelKind.supertonic.name) {
        // Langue choisie à chaque phrase (« fr », « en », « pt »…).
        audio = tts!.generateWithConfig(
          text: text,
          config: sherpa.OfflineTtsGenerationConfig(
            sid: sid,
            speed: speed,
            extra: {'lang': msg['lang'] as String},
          ),
        );
      } else if (kind == SherpaModelKind.pocket.name) {
        // Voix imitée à partir d'un court extrait, gardé en mémoire.
        final ref = references[msg['reference'] as String] ??=
            _readWavMono(msg['reference'] as String);
        audio = tts!.generateWithConfig(
          text: text,
          config: sherpa.OfflineTtsGenerationConfig(
            speed: speed,
            referenceAudio: ref.$1,
            referenceSampleRate: ref.$2,
          ),
        );
      } else {
        audio = tts!.generate(text: text, sid: sid, speed: speed);
      }
      if (audio.samples.isEmpty || audio.sampleRate <= 0) {
        throw Exception('Synthèse vide');
      }
      File(msg['outPath'] as String)
          .writeAsBytesSync(_wavBytes(audio.samples, audio.sampleRate));
      final times = alignWordsToAudio(
          msg['text'] as String, audio.samples, audio.sampleRate);
      reply.send({
        'ok': true,
        'times': times,
        'duration': audio.samples.length / audio.sampleRate,
      });
    } catch (e) {
      reply.send({'ok': false, 'error': '$e'});
    }
  });
}

sherpa.OfflineTtsConfig _buildConfig(Map msg) {
  final dir = msg['dir'] as String;
  final modelFile = msg['modelFile'] as String;
  final kind = msg['kind'] as String;
  final threads = msg['threads'] as int;

  final sherpa.OfflineTtsModelConfig model;
  if (kind == SherpaModelKind.kokoro.name) {
    model = sherpa.OfflineTtsModelConfig(
      kokoro: sherpa.OfflineTtsKokoroModelConfig(
        model: '$dir/$modelFile',
        voices: '$dir/voices.bin',
        tokens: '$dir/tokens.txt',
        dataDir: '$dir/espeak-ng-data',
        dictDir: '$dir/dict',
        lexicon: msg['gb'] == true
            ? '$dir/lexicon-gb-en.txt,$dir/lexicon-zh.txt'
            : '$dir/lexicon-us-en.txt,$dir/lexicon-zh.txt',
        lang: msg['lang'] as String,
      ),
      numThreads: threads,
      debug: false, // journal détaillé à chaque phrase : inutile et coûteux
    );
  } else if (kind == SherpaModelKind.supertonic.name) {
    model = sherpa.OfflineTtsModelConfig(
      supertonic: sherpa.OfflineTtsSupertonicModelConfig(
        durationPredictor: '$dir/duration_predictor.int8.onnx',
        textEncoder: '$dir/text_encoder.int8.onnx',
        vectorEstimator: '$dir/vector_estimator.int8.onnx',
        vocoder: '$dir/vocoder.int8.onnx',
        ttsJson: '$dir/tts.json',
        unicodeIndexer: '$dir/unicode_indexer.bin',
        voiceStyle: '$dir/voice.bin',
      ),
      numThreads: threads,
      debug: false, // journal détaillé à chaque phrase : inutile et coûteux
    );
  } else if (kind == SherpaModelKind.pocket.name) {
    model = sherpa.OfflineTtsModelConfig(
      pocket: sherpa.OfflineTtsPocketModelConfig(
        lmFlow: '$dir/lm_flow.int8.onnx',
        lmMain: '$dir/lm_main.int8.onnx',
        encoder: '$dir/encoder.onnx',
        decoder: '$dir/decoder.int8.onnx',
        textConditioner: '$dir/text_conditioner.onnx',
        vocabJson: '$dir/vocab.json',
        tokenScoresJson: '$dir/token_scores.json',
      ),
      numThreads: threads,
      debug: false, // journal détaillé à chaque phrase : inutile et coûteux
    );
  } else {
    model = sherpa.OfflineTtsModelConfig(
      vits: sherpa.OfflineTtsVitsModelConfig(
        model: '$dir/$modelFile',
        tokens: '$dir/tokens.txt',
        dataDir: '$dir/espeak-ng-data',
      ),
      numThreads: threads,
      debug: false, // journal détaillé à chaque phrase : inutile et coûteux
    );
  }

  return sherpa.OfflineTtsConfig(model: model);
}

/// Lit un WAV (PCM 16/24/32 bits ou flottant 32 bits, mono ou stéréo) et
/// renvoie l'audio mono dans [-1, 1] avec sa fréquence d'échantillonnage.
(Float32List, int) _readWavMono(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  String tag(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw FormatException('Extrait de voix illisible : $path');
  }
  var format = 1, channels = 1, rate = 0, bits = 16;
  int? dataStart, dataLength;
  var o = 12;
  while (o + 8 <= bytes.length) {
    final id = tag(o);
    final size = data.getUint32(o + 4, Endian.little);
    final body = o + 8;
    if (id == 'fmt ') {
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      rate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 26) {
        format = data.getUint16(body + 24, Endian.little); // WAVE_FORMAT_EXTENSIBLE
      }
    } else if (id == 'data') {
      dataStart = body;
      dataLength = (body + size <= bytes.length) ? size : bytes.length - body;
      break;
    }
    o = body + size + (size.isOdd ? 1 : 0);
  }
  if (dataStart == null || rate <= 0 || channels <= 0) {
    throw FormatException('Extrait de voix illisible : $path');
  }
  final step = bits ~/ 8;
  final frames = dataLength! ~/ (step * channels);
  final out = Float32List(frames);
  for (var f = 0; f < frames; f++) {
    var sum = 0.0;
    for (var c = 0; c < channels; c++) {
      final p = dataStart + (f * channels + c) * step;
      double v;
      if (format == 3 && bits == 32) {
        v = data.getFloat32(p, Endian.little);
      } else if (bits == 16) {
        v = data.getInt16(p, Endian.little) / 32768.0;
      } else if (bits == 24) {
        var x = bytes[p] | (bytes[p + 1] << 8) | (bytes[p + 2] << 16);
        if (x & 0x800000 != 0) x -= 0x1000000;
        v = x / 8388608.0;
      } else if (bits == 32) {
        v = data.getInt32(p, Endian.little) / 2147483648.0;
      } else {
        v = (bytes[p] - 128) / 128.0; // 8 bits
      }
      sum += v;
    }
    out[f] = sum / channels;
  }
  return (out, rate);
}

/// WAV PCM 16 bits mono — lisible tel quel par just_audio.
Uint8List _wavBytes(Float32List samples, int sampleRate) {
  final n = samples.length;
  final data = ByteData(44 + n * 2);
  void tag(int offset, String text) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}
