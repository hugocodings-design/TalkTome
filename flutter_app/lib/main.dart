import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'l10n/generated/app_localizations.dart';
import 'models/ebook.dart';
import 'models/chapter.dart';
import 'models/audio_chunk.dart';
import 'models/folder.dart';
import 'models/annotation.dart';
import 'models/dictionary_entry.dart';
import 'models/translation_entry.dart';
import 'screens/main_screen.dart';
import 'services/llm_selftest.dart';
import 'services/pc_boost_service.dart';
import 'services/reading_theme.dart';
import 'services/talktome_audio_handler.dart';
import 'theme/talktome_theme.dart';

// Préférences globales accessibles partout dans l'app
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<String?> fontFamilyNotifier = ValueNotifier(null);
final ValueNotifier<double> fontSizeNotifier = ValueNotifier(16.0);

/// Marge (en px) au-dessus et au-dessous du texte en mode livre, et en
/// défilement quand on masque le lecteur avec l'œil — réglable dans Profil >
/// Texte. Simple padding : prend la couleur du thème de lecture choisi.
final ValueNotifier<double> readerMarginNotifier = ValueNotifier(32.0);

/// Lecture expressive (Profil > Apparence) : la voix adapte rythme, timbre,
/// volume et pauses à l'humeur de chaque phrase.
final ValueNotifier<bool> expressiveReadingNotifier = ValueNotifier(false);

/// Intensité de la lecture expressive (Profil > Apparence), de 0,3 (discrète)
/// à 1 (marquée).
final ValueNotifier<double> expressiveIntensityNotifier = ValueNotifier(0.8);

/// Langue dans laquelle Gemini rédige les définitions du dictionnaire.
/// Code court ISO ('fr', 'en', 'pt', 'es') et non une locale complète comme
/// pour les voix TTS ('fr-FR'). Réglable séparément de
/// translationLanguageNotifier ci-dessous : rien n'oblige à vouloir lire les
/// définitions et la traduction en direct dans la même langue.
final ValueNotifier<String> dictionaryLanguageNotifier = ValueNotifier('fr');

/// Langue de la traduction en direct/manuelle pendant la lecture (Google
/// Cloud Translation) — voir dictionaryLanguageNotifier ci-dessus pour la
/// raison de la séparation.
final ValueNotifier<String> translationLanguageNotifier = ValueNotifier('fr');

/// Langue de l'INTERFACE (menus, boutons, dialogues) — distincte de
/// dictionaryLanguageNotifier/translationLanguageNotifier ci-dessus, qui
/// contrôlent le contenu généré (définitions, traductions), pas l'UI.
/// null = suit la langue du téléphone (comportement par défaut au premier
/// lancement).
final ValueNotifier<Locale?> appLocaleNotifier = ValueNotifier(null);

// Handler audio global pour la notification de lecture en arrière-plan
TalkTomeAudioHandler? audioHandler;

// Réinitialise AudioService si audioHandler est null (artefact de hot restart en dev)
Future<void> ensureAudioHandler() async {
  if (audioHandler != null) return;
  // Récupérer l'instance existante si AudioService est déjà initialisé
  if (TalkTomeAudioHandler.instance != null) {
    audioHandler = TalkTomeAudioHandler.instance;
    debugPrint('✅ AudioService handler récupéré via _instance');
    return;
  }
  try {
    audioHandler = await AudioService.init(
      builder: () => TalkTomeAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.hugocodings.talktome.audio',
        androidNotificationChannelName: 'TalkTome',
        androidNotificationIcon: 'drawable/ic_notification',
        androidStopForegroundOnPause: false,
      ),
    );
    debugPrint('✅ AudioService (re)init OK');
  } catch (e) {
    // Peu importe la cause (AssertionError si le service Android tourne
    // encore, PlatformException si l'Activity n'est pas prête...) : le
    // builder de AudioService.init() peut avoir déjà tourné et construit un
    // TalkTomeAudioHandler avant l'échec, auquel cas TalkTomeAudioHandler
    // .instance pointe déjà dessus. Il FAUT récupérer cette même instance
    // plutôt que d'en construire une nouvelle — sinon les widgets qui
    // écoutent l'instance capturée avant l'échec (ex: le mini-lecteur, dont
    // le ValueNotifier est lié à une instance précise) ne voient plus jamais
    // les mises à jour faites sur la "vraie" instance utilisée ensuite pour
    // la lecture.
    debugPrint('⚠️ AudioService.init a échoué ($e) — récupération du handler existant');
    audioHandler = TalkTomeAudioHandler.instance ?? TalkTomeAudioHandler();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Filet de sécurité global : un pépin de rendu transitoire n'importe où
  // dans l'app (ex: un débordement de layout pendant un défilement rapide
  // ou un changement de taille de police) ne doit jamais remplacer l'écran
  // par le grand rectangle rouge/jaune-noir de Flutter — surtout pendant la
  // lecture d'un livre, où ça cache tout le texte. On affiche à la place un
  // espace vide et discret pour le seul widget concerné ; le reste de
  // l'écran continue de fonctionner normalement.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    FlutterError.reportError(details);
    return const SizedBox.shrink();
  };

  await ensureAudioHandler();

  // Initialiser Hive
  await Hive.initFlutter();

  // Enregistrer les adaptateurs Hive
  Hive.registerAdapter(EbookAdapter());
  Hive.registerAdapter(ChapterAdapter());
  Hive.registerAdapter(AudioChunkAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(AnnotationAdapter());
  Hive.registerAdapter(DictionaryEntryAdapter());
  Hive.registerAdapter(TranslationEntryAdapter());

  // Ouvrir les boxes persistantes
  await Hive.openBox<Folder>('folders');
  final ebookBox = await Hive.openBox<Ebook>('ebooks');
  await _repairCoverPaths(ebookBox);
  final annotationBox = await Hive.openBox<Annotation>('annotations');
  await _cleanupAnnotationArtifacts(annotationBox);
  await Hive.openBox('reading_stats');
  // 'dictionary' : les mots enregistrés par l'utilisateur (liste de
  // vocabulaire, par livre et tous livres confondus — voir DictionaryEntry).
  // 'dictionary_cache' : box séparée, NON affichée à l'utilisateur, qui
  // mémorise le résultat de CHAQUE recherche (même non enregistrée) pour que
  // ré-chercher un mot déjà vu soit gratuit et fonctionne hors-ligne — voir
  // DictionaryService. Les deux doivent être ouvertes ici, avant runApp :
  // annotations_screen.dart (et bientôt l'onglet Dictionnaire) utilisent
  // Hive.box<...>() de façon SYNCHRONE, qui lève une HiveError si la box
  // n'a pas déjà été ouverte.
  await _openBoxOrResetIfCorrupt<DictionaryEntry>('dictionary');
  await _openBoxOrResetIfCorrupt('dictionary_cache');
  // Cache des traductions à la volée pendant la lecture (voir
  // TranslationService) — jamais affichée à l'utilisateur, juste là pour
  // que relire un livre déjà lu ne coûte plus rien et marche hors-ligne.
  await _openBoxOrResetIfCorrupt('translation_cache');
  // 'translations' : mots/phrases traduits manuellement et enregistrés par
  // l'utilisateur (bouton "Traduire" dans la barre de sélection) — voir
  // TranslationEntry. Distincte de translation_cache ci-dessus.
  await _openBoxOrResetIfCorrupt<TranslationEntry>('translations');
  // Humeur de chaque phrase déjà analysée par l'IA (lecture expressive).
  await _openBoxOrResetIfCorrupt('mood_cache');
  final settings = await Hive.openBox('settings');

  // Restaurer les préférences sauvegardées
  final savedTheme = settings.get('themeMode', defaultValue: 'dark') as String;
  themeModeNotifier.value = _parseThemeMode(savedTheme);
  fontFamilyNotifier.value = settings.get('fontFamily') as String?;
  fontSizeNotifier.value = (settings.get('fontSize', defaultValue: 16.0) as num).toDouble();
  readerMarginNotifier.value =
      (settings.get('readerMargin', defaultValue: 32.0) as num).toDouble();
  expressiveReadingNotifier.value =
      settings.get('expressiveReading', defaultValue: false) as bool;
  expressiveIntensityNotifier.value =
      (settings.get('expressiveIntensity', defaultValue: 0.8) as num).toDouble();
  dictionaryLanguageNotifier.value =
      settings.get('dictionaryLanguage', defaultValue: 'fr') as String;
  translationLanguageNotifier.value =
      settings.get('translationLanguage', defaultValue: 'fr') as String;
  final savedAppLanguage = settings.get('appLanguage') as String?; // absent = système
  appLocaleNotifier.value = savedAppLanguage != null ? Locale(savedAppLanguage) : null;
  pageThemeNotifier.value = settings.get('pageTheme', defaultValue: 'auto') as String;
  warmthNotifier.value = (settings.get('warmth', defaultValue: 0.0) as num).toDouble();
  dimNotifier.value = (settings.get('dim', defaultValue: 0.0) as num).toDouble();

  // TalkTome Boost : appairage déposé par adb (développement), puis
  // recherche de l'ordinateur en arrière-plan.
  await PcBoostService.instance.importPairingFileIfAny();
  if (PcBoostService.instance.enabled) {
    unawaited(PcBoostService.instance.base(force: true));
  }

  runApp(const TalkTomeApp());

  // Debug uniquement, et seulement si un fichier déclencheur a été déposé
  // via adb — voir llm_selftest.dart.
  unawaited(runLlmSelfTestIfRequested());
}

/// Les couvertures sont enregistrées avec un chemin absolu, qui contient
/// l'identifiant du paquet Android : après une copie des données depuis une
/// installation sous un autre identifiant, on les rattache au dossier covers/
/// actuel quand le fichier s'y trouve. Sans effet une fois les chemins bons.
Future<void> _repairCoverPaths(Box<Ebook> box) async {
  final coversDir = '${(await getApplicationDocumentsDirectory()).path}/covers';
  for (final key in box.keys.toList()) {
    final ebook = box.get(key);
    final path = ebook?.coverImagePath;
    if (ebook == null || path == null || File(path).existsSync()) continue;
    final relocated = '$coversDir/${path.split('/').last}';
    if (!File(relocated).existsSync()) continue;
    ebook.coverImagePath = relocated;
    await box.put(key, ebook);
  }
}

/// Ouvre une box Hive, et si sa lecture échoue (typiquement un
/// TypeError/HiveError parce que le SCHÉMA d'un modèle a changé entre deux
/// versions de l'app — ex: DictionaryEntry a perdu ses champs de traduction
/// lors de la simplification du dictionnaire), supprime le fichier de la
/// box et la rouvre vide plutôt que de planter l'app entière au démarrage.
/// N'affecte QUE cette box précise : les autres (ebooks, annotations...)
/// restent intactes. Acceptable ici parce que 'dictionary'/'dictionary_cache'
/// ne contiennent que quelques mots de test à ce stade, jamais une
/// bibliothèque ou une progression de lecture.
Future<void> _openBoxOrResetIfCorrupt<T>(String name) async {
  try {
    final box = await Hive.openBox<T>(name);
    // openBox ne lit pas forcément chaque valeur elle-même — forcer une
    // lecture complète ici pour détecter un schéma incompatible tout de
    // suite, plutôt que plus tard au premier accès depuis l'UI.
    box.values.toList();
  } catch (e) {
    debugPrint('⚠️ Box "$name" illisible ($e) — réinitialisation');
    await Hive.deleteBoxFromDisk(name);
    await Hive.openBox<T>(name);
  }
}

// Nettoyage ponctuel des annotations sauvegardées avant le correctif qui
// retire le caractère objet (U+FFFC) des ancres de phrase invisibles — ce
// caractère pouvait se retrouver au milieu du texte surligné quand la
// sélection traversait plusieurs phrases, et s'affichait comme un petit
// carré "obj". Se relance à chaque démarrage mais ne réécrit rien une fois
// toutes les annotations propres (comparaison avant/après).
Future<void> _cleanupAnnotationArtifacts(Box<Annotation> box) async {
  for (final key in box.keys.toList()) {
    final a = box.get(key);
    if (a == null) continue;
    final cleaned = a.selectedText
        .replaceAll('￼', '')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    if (cleaned != a.selectedText) {
      await box.put(
        key,
        Annotation(
          id: a.id,
          ebookId: a.ebookId,
          chapterId: a.chapterId,
          paragraphIndexInChapter: a.paragraphIndexInChapter,
          startOffset: a.startOffset,
          endOffset: a.endOffset,
          selectedText: cleaned,
          createdAt: a.createdAt,
          note: a.note,
        ),
      );
    }
  }
}

ThemeMode _parseThemeMode(String value) {
  switch (value) {
    case 'light': return ThemeMode.light;
    case 'dark':  return ThemeMode.dark;
    default:      return ThemeMode.system;
  }
}

class TalkTomeApp extends StatefulWidget {
  const TalkTomeApp({Key? key}) : super(key: key);

  @override
  State<TalkTomeApp> createState() => _TalkTomeAppState();
}

class _TalkTomeAppState extends State<TalkTomeApp> {
  @override
  void initState() {
    super.initState();
    // Demander la permission notification dès le premier frame affiché
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
    // Exemption batterie Samsung One UI — évite que le foreground service soit tué
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: appLocaleNotifier,
          builder: (context, appLocale, _) {
            return MaterialApp(
              title: 'TalkTome',
              debugShowCheckedModeBanner: false,
              // "Mystic night" — voir lib/theme/talktome_theme.dart
              theme: buildTalkTomeTheme(Brightness.light),
              darkTheme: buildTalkTomeTheme(Brightness.dark),
              themeMode: themeMode,
              locale: appLocale,
              // Français en premier : langue de repli si celle du téléphone
              // n'est ni le français ni l'anglais (l'ordre de la liste
              // générée par AppLocalizations est alphabétique — 'en' avant
              // 'fr' — donc explicite ici plutôt que réutilisée telle quelle).
              supportedLocales: const [Locale('fr'), Locale('en')],
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              // Filtre chaud / assombrissement sur toute l'app.
              builder: (context, child) => ComfortFilter(child: child!),
              home: const MainScreen(),
            );
          },
        );
      },
    );
  }
}
