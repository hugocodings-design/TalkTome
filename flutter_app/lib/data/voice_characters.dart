import '../services/sherpa_tts_service.dart';
import 'chirp3_personas.dart';

/// Un personnage fictif associé à une voix TTS : nom, langue et photo.
/// Pour une voix locale sans photo connue (isLocal sans entrée dédiée dans
/// la table), un icône générique est affiché à la place.
class VoiceCharacter {
  final String name;
  final String language;
  final String photoAsset;
  final bool isLocal;

  const VoiceCharacter({
    required this.name,
    required this.language,
    required this.photoAsset,
    this.isLocal = false,
  });
}

const String _base = 'assets/avatars';

/// Table de correspondance voix Google TTS -> personnage fictif.
const Map<String, VoiceCharacter> voiceCharacters = {
  // English (US) — Journey remplacé par Neural2 (Google a retiré Journey)
  'en-US-Neural2-D': VoiceCharacter(
    name: 'Marcus', language: 'Anglais (US)', photoAsset: '$_base/en-US-Journey-D.jpg',
  ),
  'en-US-Neural2-C': VoiceCharacter(
    name: 'Luna', language: 'Anglais (US)', photoAsset: '$_base/en-US-Journey-F.jpg',
  ),
  'en-US-Neural2-F': VoiceCharacter(
    name: 'Aria', language: 'Anglais (US)', photoAsset: '$_base/en-US-Journey-O.jpg',
  ),

  // English (UK) — Journey remplacé par Neural2
  'en-GB-Neural2-B': VoiceCharacter(
    name: 'Oliver', language: 'Anglais (UK)', photoAsset: '$_base/en-GB-Journey-D.jpg',
  ),
  'en-GB-Neural2-F': VoiceCharacter(
    name: 'Emma', language: 'Anglais (UK)', photoAsset: '$_base/en-GB-Journey-F.jpg',
  ),

  // Français (Canada)
  'fr-CA-Neural2-A': VoiceCharacter(
    name: 'Camille', language: 'Français (Canada)', photoAsset: '$_base/fr-CA-Neural2-A.jpg',
  ),
  'fr-CA-Neural2-B': VoiceCharacter(
    name: 'Étienne', language: 'Français (Canada)', photoAsset: '$_base/fr-CA-Neural2-B.jpg',
  ),
  'fr-CA-Neural2-C': VoiceCharacter(
    name: 'Béatrice', language: 'Français (Canada)', photoAsset: '$_base/fr-CA-Neural2-C.jpg',
  ),
  'fr-CA-Neural2-D': VoiceCharacter(
    name: 'Gabriel', language: 'Français (Canada)', photoAsset: '$_base/fr-CA-Neural2-D.jpg',
  ),

  // Français (France) — seulement 2 voix Neural2 existent chez Google pour
  // cette langue (F et G) ; Margaux/Julien/Adèle n'ont plus de voix réelle
  // à laquelle correspondre et ont donc été retirées.
  'fr-FR-Neural2-F': VoiceCharacter(
    name: 'Chloé', language: 'Français (France)', photoAsset: '$_base/fr-FR-Neural2-A.jpg',
  ),
  'fr-FR-Neural2-G': VoiceCharacter(
    name: 'Antoine', language: 'Français (France)', photoAsset: '$_base/fr-FR-Neural2-B.jpg',
  ),

  // Español (España) — lettres réelles corrigées (A/F/H/G, pas A/B/C/D)
  'es-ES-Neural2-A': VoiceCharacter(
    name: 'Sofía', language: 'Espagnol (Espagne)', photoAsset: '$_base/es-ES-Neural2-A.jpg',
  ),
  'es-ES-Neural2-F': VoiceCharacter(
    name: 'Diego', language: 'Espagnol (Espagne)', photoAsset: '$_base/es-ES-Neural2-B.jpg',
  ),
  'es-ES-Neural2-H': VoiceCharacter(
    name: 'Valentina', language: 'Espagnol (Espagne)', photoAsset: '$_base/es-ES-Neural2-C.jpg',
  ),
  'es-ES-Neural2-G': VoiceCharacter(
    name: 'Mateo', language: 'Espagnol (Espagne)', photoAsset: '$_base/es-ES-Neural2-D.jpg',
  ),

  // Español (US)
  'es-US-Neural2-A': VoiceCharacter(
    name: 'Isabella', language: 'Espagnol (US)', photoAsset: '$_base/es-US-Neural2-A.jpg',
  ),
  'es-US-Neural2-B': VoiceCharacter(
    name: 'Santiago', language: 'Espagnol (US)', photoAsset: '$_base/es-US-Neural2-B.jpg',
  ),
  'es-US-Neural2-C': VoiceCharacter(
    name: 'Camila', language: 'Espagnol (US)', photoAsset: '$_base/es-US-Neural2-C.jpg',
  ),

  // Português (Brasil)
  'pt-BR-Neural2-A': VoiceCharacter(
    name: 'Beatriz', language: 'Portugais (Brésil)', photoAsset: '$_base/pt-BR-Neural2-A.jpg',
  ),
  'pt-BR-Neural2-B': VoiceCharacter(
    name: 'Rafael', language: 'Portugais (Brésil)', photoAsset: '$_base/pt-BR-Neural2-B.jpg',
  ),
  'pt-BR-Neural2-C': VoiceCharacter(
    name: 'Larissa', language: 'Portugais (Brésil)', photoAsset: '$_base/pt-BR-Neural2-C.jpg',
  ),

  // Português (Portugal) — seulement 2 voix (Wavenet, pas de Neural2 pour
  // cette langue) existent chez Google ; Mariana/Duarte ont été retirées
  // faute de voix réelle correspondante.
  'pt-PT-Wavenet-E': VoiceCharacter(
    name: 'Inês', language: 'Portugais (Portugal)', photoAsset: '$_base/pt-PT-Neural2-A.jpg',
  ),
  'pt-PT-Wavenet-F': VoiceCharacter(
    name: 'Tiago', language: 'Portugais (Portugal)', photoAsset: '$_base/pt-PT-Neural2-B.jpg',
  ),
};

/// Personnages Chirp3-HD — pas de vraie photo (voix nouvelles, pas de
/// portrait dédié) : VoiceAvatar affiche à la place un cercle avec
/// l'initiale du prénom quand photoAsset est vide et que ce n'est pas
/// une voix locale.
final Map<String, VoiceCharacter> chirp3Characters = {
  for (final lang in chirp3Languages.entries)
    for (var i = 0; i < chirp3Personas.length; i++)
      '${lang.key}-Chirp3-HD-${chirp3Personas[i].name}': VoiceCharacter(
        name: chirp3LocalizedNames[lang.key]![i],
        language: lang.value,
        // Photos de vrais visages (randomuser.me), une par voix — nommage
        // déterministe assorti au script qui les a téléchargées.
        photoAsset: '$_base/chirp3-${lang.key}-${chirp3Personas[i].name}.jpg',
      ),
};

final Map<String, VoiceCharacter> allVoiceCharacters = {
  ...voiceCharacters,
  ...chirp3Characters,
};

/// Personnage pour une voix — gère aussi les voix IA locales
/// non encore répertoriées avec une vraie photo, en repli générique.
VoiceCharacter characterForVoice(String voiceName) {
  final known = allVoiceCharacters[voiceName];
  if (known != null) return known;

  final ai = SherpaTtsService.voiceByName(voiceName);
  if (ai != null) {
    const languages = {
      'fr-FR': 'Français (France)',
      'en-US': 'Anglais (US)',
      'en-GB': 'Anglais (UK)',
      'pt-PT': 'Portugais (Portugal)',
      'pt-BR': 'Portugais (Brésil)',
    };
    // Phase de développement : chaque voix affiche son moteur (et son
    // genre), et chaque section dit où elle tourne — téléphone, ou
    // ordinateur obligatoire (TalkTome Boost).
    final spec = SherpaTtsService.modelById(ai.modelId);
    const tags = {
      SherpaModelKind.kokoro: 'Kokoro',
      SherpaModelKind.piper: 'Piper',
      SherpaModelKind.supertonic: 'Supertonic',
      SherpaModelKind.pocket: 'Pocket',
      SherpaModelKind.qwen3: 'Qwen3',
    };
    final gender = switch (ai.gender) { 'F' => ' ♀', 'M' => ' ♂', _ => '' };
    final where = spec.runsOnPhone ? 'téléphone' : 'ordinateur requis';
    return VoiceCharacter(
      name: '${tags[spec.kind]} ${ai.displayName}$gender',
      // « émotions » : voix qui expriment elles-mêmes l'humeur.
      language: '${languages[ai.languageCode] ?? ai.languageCode} · '
          '${spec.engineName}${SherpaTtsService.isEmotionalVoice(voiceName) ? ' émotions' : ''}'
          '${ai.emotionSource.isNotEmpty ? ' (extraits de l\'ordinateur)' : ''} · $where',
      photoAsset: '',
    );
  }

  return VoiceCharacter(
    name: voiceName,
    language: '',
    photoAsset: '$_base/en-US-Journey-D.jpg',
  );
}
