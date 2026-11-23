// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'TalkTome';

  @override
  String get miniPlayer_almostDone => 'Presque terminé';

  @override
  String miniPlayer_remainingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min restantes',
      one: '1 min restante',
      zero: 'Presque terminé',
    );
    return '$_temp0';
  }

  @override
  String miniPlayer_remainingHoursMinutes(int h, int m) {
    return '${h}h ${m}m restantes';
  }

  @override
  String get nav_home => 'Accueil';

  @override
  String get nav_library => 'Bibliothèque';

  @override
  String get nav_annotations => 'Annotations';

  @override
  String get nav_profile => 'Profil';

  @override
  String get nav_add => 'Ajouter';

  @override
  String mainScreen_bookAdded(String title) {
    return '« $title » ajouté';
  }

  @override
  String mainScreen_error(String error) {
    return 'Erreur : $error';
  }

  @override
  String get mainScreen_importFile => 'Importer un fichier';

  @override
  String get mainScreen_pdfOrEpub => 'PDF ou EPUB';

  @override
  String get mainScreen_scanWithCamera => 'Scanner avec la caméra';

  @override
  String get mainScreen_scanSubtitle =>
      'Photographier les pages d\'un livre papier';

  @override
  String get mainScreen_bookCreatedFromScan => 'Livre créé à partir du scan';

  @override
  String get mainScreen_addFromUrl => 'Ajouter depuis un site web';

  @override
  String get mainScreen_addFromUrlSubtitle => 'Collez le lien d\'un article';

  @override
  String get mainScreen_urlHint => 'https://exemple.com/article';

  @override
  String get mainScreen_bookCreatedFromUrl =>
      'Livre créé à partir de page(s) web';

  @override
  String get urlImport_addLink => 'Ajouter le lien';

  @override
  String get urlImport_orderHint =>
      'Les liens sont lus dans cet ordre — glissez pour réordonner';

  @override
  String get urlImport_empty =>
      'Collez un lien ci-dessus et appuyez sur + pour l\'ajouter.\nAjoutez-en plusieurs pour les combiner en un seul livre, dans l\'ordre.';

  @override
  String get urlImport_bookTitle => 'Titre du livre';

  @override
  String urlImport_defaultTitle(int count) {
    return '$count pages web';
  }

  @override
  String get urlImport_create => 'Créer le livre';

  @override
  String urlImport_partialFailure(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages n\'ont',
      one: '1 page n\'a',
    );
    return '$_temp0 pas pu être récupérée(s) — les autres ont été ajoutées.';
  }

  @override
  String get urlImport_continuationFound =>
      'Cette page se poursuit sur une autre page — l\'ajouter aussi ?';

  @override
  String get urlImport_add => 'Ajouter';

  @override
  String urlImport_words(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots',
      one: '1 mot',
    );
    return '$_temp0';
  }

  @override
  String get recentScreen_inProgress => 'En cours';

  @override
  String get recentScreen_statistics => 'Statistiques';

  @override
  String get recentScreen_today => 'Aujourd\'hui';

  @override
  String get recentScreen_thisWeek => 'Cette semaine';

  @override
  String get recentScreen_streak => 'Série';

  @override
  String recentScreen_streakDays(int count) {
    return '$count j';
  }

  @override
  String get recentScreen_inProgressAndFinished => 'En cours / Terminés';

  @override
  String recentScreen_countRatio(int inProgress, int finished) {
    return '$inProgress / $finished';
  }

  @override
  String get recentScreen_noBooks => 'Aucun livre';

  @override
  String get recentScreen_addPrompt =>
      'Appuie sur + pour ajouter un PDF ou EPUB';

  @override
  String recentScreen_percentRead(int percent) {
    return '$percent% lu';
  }

  @override
  String get common_retry => 'Réessayer';

  @override
  String get common_close => 'Fermer';

  @override
  String get common_delete => 'Supprimer';

  @override
  String get common_save => 'Enregistrer';

  @override
  String get common_saved => 'Enregistré';

  @override
  String get common_cancel => 'Annuler';

  @override
  String get common_noConnectionDictionary =>
      'Pas de connexion — impossible de chercher ce mot';

  @override
  String get common_noConnectionTranslation =>
      'Pas de connexion — impossible de traduire';

  @override
  String dictionarySheet_alreadyInList(String word) {
    return '« $word » est déjà dans votre liste';
  }

  @override
  String dictionarySheet_searching(String word) {
    return 'Recherche de « $word »…';
  }

  @override
  String get dictionarySheet_listenPronunciation => 'Écouter la prononciation';

  @override
  String get dictionarySheet_definition => 'Définition';

  @override
  String get dictionarySheet_synonyms => 'Synonymes';

  @override
  String get dictionarySheet_quotaExceeded =>
      'Quota temporairement épuisé — réessayez dans un instant';

  @override
  String get dictionarySheet_localModelMissing =>
      'Le modèle d\'IA locale n\'est pas installé sur ce téléphone — le dictionnaire fonctionne entièrement sur l\'appareil';

  @override
  String get dictionarySheet_inThisSentence => 'Dans cette phrase';

  @override
  String dictionarySheet_formOf(String lemma) {
    return 'Forme de « $lemma »';
  }

  @override
  String get dictionarySheet_unexpectedResponse =>
      'Réponse inattendue du service';

  @override
  String get translationSheet_alreadySaved =>
      'Déjà enregistré dans vos traductions';

  @override
  String get translationSheet_originalText => 'Texte original';

  @override
  String get translationSheet_translation => 'Traduction';

  @override
  String get camera_noCameraAvailable =>
      'Aucune caméra disponible sur cet appareil.';

  @override
  String get camera_accessDenied =>
      'L\'accès à la caméra a été refusé. Autorisez-le dans les réglages de l\'application pour scanner des pages.';

  @override
  String camera_unavailableWithReason(String reason) {
    return 'Caméra indisponible : $reason';
  }

  @override
  String camera_captureFailed(String error) {
    return 'Échec de la capture : $error';
  }

  @override
  String camera_importFailed(String error) {
    return 'Import impossible : $error';
  }

  @override
  String get camera_abandonTitle => 'Abandonner le scan ?';

  @override
  String camera_abandonBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages scannées seront perdues.',
      one: '1 page scannée sera perdue.',
    );
    return '$_temp0';
  }

  @override
  String get camera_continueScanning => 'Continuer le scan';

  @override
  String get camera_abandon => 'Abandonner';

  @override
  String get camera_torch => 'Torche';

  @override
  String get camera_processingPhoto => 'Traitement de la photo…';

  @override
  String get camera_importFromGallery => 'Importer depuis la galerie';

  @override
  String get camera_gallery => 'Galerie';

  @override
  String get camera_finish => 'Terminer';

  @override
  String get camera_scanBook => 'Scanner un livre';

  @override
  String camera_pagesScanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages scannées',
      one: '1 page scannée',
    );
    return '$_temp0';
  }

  @override
  String get crop_adjustTextArea => 'Ajuster la zone de texte';

  @override
  String get crop_rotate => 'Pivoter';

  @override
  String get crop_detectingTextArea => 'Détection de la zone de texte…';

  @override
  String get crop_noTextBlockDetected =>
      'Aucun bloc de texte détecté — ajustez les coins à la main.';

  @override
  String crop_detectionFailed(String error) {
    return 'Détection impossible : $error';
  }

  @override
  String get crop_rotating => 'Rotation…';

  @override
  String get crop_cornersOverlap =>
      'Les coins se croisent — remettez-les dans l\'ordre.';

  @override
  String get crop_rectifyingAndReading => 'Redressement et lecture du texte…';

  @override
  String get crop_noTextRecognized => 'Aucun texte reconnu';

  @override
  String crop_processingFailed(String error) {
    return 'Échec du traitement : $error';
  }

  @override
  String get crop_auto => 'Auto';

  @override
  String get crop_all => 'Tout';

  @override
  String get crop_confirm => 'Valider';

  @override
  String get scanReview_correctText => 'Corriger le texte';

  @override
  String get scanReview_noTextFound => 'Aucun texte';

  @override
  String scanReview_defaultTitle(String date) {
    return 'Scan du $date';
  }

  @override
  String get scanReview_bookTitle => 'Titre du livre';

  @override
  String get scanReview_create => 'Créer';

  @override
  String get scanReview_noPagesWithText =>
      'Aucune page ne contient de texte reconnu.';

  @override
  String scanReview_creationFailed(String error) {
    return 'Création impossible : $error';
  }

  @override
  String get scanReview_verifyPages => 'Vérifier les pages';

  @override
  String scanReview_pagesWordsSummary(int pageCount, int wordCount) {
    return '$pageCount page(s) • $wordCount mots reconnus';
  }

  @override
  String get scanReview_createBook => 'Créer le livre';

  @override
  String scanReview_pageWordCount(int index, int words) {
    return 'Page $index • $words mots';
  }

  @override
  String get scanReview_recrop => 'Recadrer';

  @override
  String get annotations_allAnnotations => 'Toutes les annotations';

  @override
  String get annotations_tabHighlights => 'Surlignages';

  @override
  String get annotations_tabDictionary => 'Dictionnaire';

  @override
  String get annotations_tabTranslations => 'Traductions';

  @override
  String get annotations_justNow => 'à l\'instant';

  @override
  String annotations_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
      one: 'il y a 1 min',
    );
    return '$_temp0';
  }

  @override
  String annotations_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
      one: 'il y a 1 h',
    );
    return '$_temp0';
  }

  @override
  String annotations_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count j',
      one: 'il y a 1 j',
    );
    return '$_temp0';
  }

  @override
  String get annotations_noHighlights => 'Aucun passage surligné';

  @override
  String get annotations_noHighlightsHint =>
      'Tenez le doigt sur un mot pendant la lecture pour surligner un passage';

  @override
  String get annotations_noWords => 'Aucun mot enregistré';

  @override
  String get annotations_noWordsHint =>
      'Sélectionnez un mot pendant la lecture, puis appuyez sur Définir';

  @override
  String get annotations_noTranslations => 'Aucune traduction enregistrée';

  @override
  String get annotations_noTranslationsHint =>
      'Sélectionnez un mot ou une phrase pendant la lecture, puis appuyez sur Traduire';

  @override
  String get profileScreen_periodDay => 'Jour';

  @override
  String get profileScreen_periodWeek => 'Semaine';

  @override
  String get profileScreen_periodMonth => 'Mois';

  @override
  String get profileScreen_periodSixMonths => '6 mois';

  @override
  String get profileScreen_periodYear => 'Année';

  @override
  String profileScreen_readingTimeForPeriod(String period) {
    return 'Temps de lecture — $period';
  }

  @override
  String get profileScreen_avgPerWeek => 'Moy. par semaine';

  @override
  String get profileScreen_totalReading => 'Total de lecture';

  @override
  String get profileScreen_breakdown => 'RÉPARTITION';

  @override
  String get profileScreen_noReadingRecorded => 'Aucune lecture enregistrée';

  @override
  String get profileScreen_startReadingHint =>
      'Commence à lire pour voir tes statistiques';

  @override
  String get profileScreen_appearance => 'Apparence';

  @override
  String get profileScreen_expressiveReading => 'Lecture expressive';

  @override
  String get profileScreen_expressiveReadingHint =>
      'La voix adapte son rythme, son ton et ses pauses à l\'émotion de chaque phrase (analyse par l\'IA de l\'ordinateur quand TalkTome Boost est connecté)';

  @override
  String get profileScreen_system => 'Système';

  @override
  String get profileScreen_light => 'Clair';

  @override
  String get profileScreen_dark => 'Sombre';

  @override
  String get profileScreen_text => 'Texte';

  @override
  String get profileScreen_textSize => 'Taille du texte';

  @override
  String profileScreen_pt(int size) {
    return '$size pt';
  }

  @override
  String get profileScreen_font => 'Police';

  @override
  String get profileScreen_readerMargin => 'Marges du texte';

  @override
  String get profileScreen_readerMarginHint =>
      'Espace au-dessus et au-dessous du texte en mode livre, et quand on masque le lecteur (l\'œil)';

  @override
  String get profileScreen_default => 'Défaut';

  @override
  String get profileScreen_serif => 'Serif';

  @override
  String get profileScreen_monospace => 'Monospace';

  @override
  String get profileScreen_dictionaryLanguage => 'Langue du dictionnaire';

  @override
  String get profileScreen_dictionaryLanguageHint =>
      'Langue des définitions pendant la lecture';

  @override
  String get profileScreen_translationLanguage => 'Langue de traduction';

  @override
  String get profileScreen_translationLanguageHint =>
      'Traduction en direct et manuelle pendant la lecture';

  @override
  String get profileScreen_languageSection => 'Langue';

  @override
  String get profileScreen_appLanguageLabel => 'Langue de l\'application';

  @override
  String get home_renameBookTitle => 'Renommer le livre';

  @override
  String get home_titleFieldLabel => 'Titre';

  @override
  String get home_deleteBookTitle => 'Supprimer le livre';

  @override
  String home_deleteBookConfirm(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String home_bookDeleted(String title) {
    return '« $title » supprimé';
  }

  @override
  String get home_deleteBooksTitle => 'Supprimer les livres';

  @override
  String home_deleteSelectedConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count livres sélectionnés ?',
      one: 'Supprimer 1 livre sélectionné ?',
    );
    return '$_temp0';
  }

  @override
  String get home_newFolder => 'Nouveau dossier';

  @override
  String get home_folderNameLabel => 'Nom du dossier';

  @override
  String get home_renameFolderTitle => 'Renommer le dossier';

  @override
  String get home_nameLabel => 'Nom';

  @override
  String get home_deleteFolderTitle => 'Supprimer le dossier';

  @override
  String home_deleteFolderWithBooksConfirm(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Supprimer « $name » ? Les $count livres seront déplacés à la racine.',
      one: 'Supprimer « $name » ? Le livre sera déplacé à la racine.',
    );
    return '$_temp0';
  }

  @override
  String home_deleteFolderEmptyConfirm(String name) {
    return 'Supprimer le dossier « $name » ?';
  }

  @override
  String get home_moveToFolderTitle => 'Déplacer dans un dossier';

  @override
  String get home_noFolderRoot => 'Aucun dossier (racine)';

  @override
  String get home_move => 'Déplacer';

  @override
  String get home_moveToFolderMenu => 'Déplacer dans un dossier';

  @override
  String home_selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
    );
    return '$_temp0';
  }

  @override
  String home_booksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livres',
      one: '1 livre',
    );
    return '$_temp0';
  }

  @override
  String get home_folders => 'Dossiers';

  @override
  String get home_noBooksHere => 'Aucun livre ici';

  @override
  String get home_books => 'Livres';

  @override
  String get home_notStarted => 'Non commencé';

  @override
  String get home_finished => 'Terminé ✓';

  @override
  String home_percentReadSentence(int percent, int pos, int total) {
    return '$percent% lu • phrase $pos / $total';
  }

  @override
  String get home_open => 'Ouvrir';

  @override
  String get home_rename => 'Renommer';

  @override
  String get home_select => 'Sélectionner';

  @override
  String get home_create => 'Créer';

  @override
  String get home_noBooks => 'Aucun livre';

  @override
  String get home_addPrompt => 'Appuyez sur + pour ajouter un PDF ou EPUB';

  @override
  String get reader_define => 'Définir';

  @override
  String get reader_translate => 'Traduire';

  @override
  String get reader_highlight => 'Surligner';

  @override
  String get reader_definitionsLanguage => 'Langue des définitions';

  @override
  String get reader_liveTranslationTitle => 'Traduction en direct';

  @override
  String get reader_enabled => 'Activée';

  @override
  String get reader_translationBubbleHint =>
      'Bulle de traduction pendant la lecture';

  @override
  String get reader_readingSpeed => 'Vitesse de lecture';

  @override
  String get reader_slower => 'Plus lent';

  @override
  String get reader_faster => 'Plus rapide';

  @override
  String get reader_chooseVoice => 'Choisir une voix';

  @override
  String get reader_highQualityNoWordHighlight =>
      'Haute qualité — sans surlignage mot par mot';

  @override
  String get reader_fontCondensed => 'Condensé';

  @override
  String get reader_fontCursive => 'Cursif';

  @override
  String get reader_background => 'FOND';

  @override
  String get reader_textSizeSection => 'TAILLE DU TEXTE';

  @override
  String get reader_fontSection => 'POLICE';

  @override
  String get reader_renameFileTitle => 'Renommer le fichier';

  @override
  String get reader_documentNameHint => 'Nom du document';

  @override
  String get reader_searchHint => 'Rechercher dans le document…';

  @override
  String reader_resultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
    );
    return '$_temp0';
  }

  @override
  String reader_chapterSentence(int chapter, int sentence) {
    return 'Chapitre $chapter · Phrase $sentence';
  }

  @override
  String get reader_tableOfContents => 'Table des matières';

  @override
  String reader_wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots',
      one: '1 mot',
    );
    return '$_temp0';
  }

  @override
  String get reader_options => 'Options';

  @override
  String get reader_annotationsOfThisBook => 'Annotations de ce livre';

  @override
  String get reader_search => 'Rechercher';

  @override
  String get reader_hideReader => 'Masquer le lecteur';

  @override
  String get reader_showReader => 'Afficher le lecteur';

  @override
  String get reader_disableAutoScroll => 'Désactiver défilement auto';

  @override
  String get reader_enableAutoScroll => 'Activer défilement auto';

  @override
  String get reader_showControls => 'Afficher les contrôles';

  @override
  String get reader_previousSentence => 'Phrase précédente';

  @override
  String get reader_nextSentence => 'Phrase suivante';

  @override
  String get reader_readTranslationAloud => 'Lire la traduction à voix haute';

  @override
  String get reader_readTranslationAloudHint =>
      'La voix lit la traduction à la place du texte du livre';

  @override
  String get reader_translationVoice => 'Voix de la traduction';

  @override
  String get reader_noVoiceForLanguage =>
      'Aucune voix installée pour cette langue';

  @override
  String get profileScreen_boostSection => 'Accélération par l\'ordinateur';

  @override
  String get profileScreen_boostOff =>
      'Désactivée — tout se fait sur le téléphone';

  @override
  String get profileScreen_boostSearching => 'Recherche de l\'ordinateur…';

  @override
  String profileScreen_boostConnected(String host) {
    return 'Connecté à $host — voix et IA sur l\'ordinateur';
  }

  @override
  String get profileScreen_boostUnreachable =>
      'Ordinateur introuvable — le téléphone prend le relais';

  @override
  String get profileScreen_boostEnable =>
      'Utiliser l\'ordinateur quand il est joignable';

  @override
  String get profileScreen_boostHosts => 'Adresses de l\'ordinateur';

  @override
  String get profileScreen_boostHostsHint =>
      'Wi-Fi et Tailscale, séparées par des virgules';

  @override
  String get profileScreen_boostCode => 'Code d\'appairage (6 chiffres)';

  @override
  String get profileScreen_boostTest => 'Tester';

  @override
  String get reader_pageColor => 'COULEUR DE PAGE';

  @override
  String get reader_pageAuto => 'Auto';

  @override
  String get reader_pageWhite => 'Blanc';

  @override
  String get reader_pagePaper => 'Papier';

  @override
  String get reader_pageGreen => 'Vert';

  @override
  String get reader_pageGray => 'Gris';

  @override
  String get reader_pageNight => 'Nuit';

  @override
  String get reader_warmth => 'Filtre chaud';

  @override
  String get reader_dim => 'Assombrir';

  @override
  String get reader_voicePitch => 'Timbre de la voix';

  @override
  String get reader_pitchDeeper => 'Plus grave';

  @override
  String get reader_pitchLighter => 'Plus aiguë';

  @override
  String get reader_pitchNormal => 'Normal';

  @override
  String get reader_bookMode => 'Mode livre (pages)';

  @override
  String get reader_scrollMode => 'Mode défilement';

  @override
  String get reader_pageTurn => 'Animation de page';

  @override
  String get reader_pageTurnCurl => 'Page qui tourne';

  @override
  String get reader_pageTurnSlide => 'Glissement';

  @override
  String reader_pageOf(int page, int total) {
    return 'Page $page sur $total';
  }

  @override
  String get reader_pause => 'Pause';

  @override
  String get reader_play => 'Lecture';

  @override
  String audioHandler_sentenceProgress(int current, int total) {
    return 'Phrase $current / $total';
  }

  @override
  String get voiceDownloads_title => 'Voix IA';

  @override
  String get voiceDownloads_manage => 'Voix IA';

  @override
  String get voiceDownloads_section => 'Voix IA';

  @override
  String voiceDownloads_tileSubtitle(int installed, int total) {
    return '$installed / $total modèles installés sur ce téléphone';
  }

  @override
  String get voiceDownloads_intro =>
      'Les voix IA fonctionnent hors ligne, directement sur le téléphone. Téléchargez celles que vous voulez — le Wi-Fi est conseillé, et gardez l\'application ouverte pendant l\'installation.';

  @override
  String voiceDownloads_installAll(int size) {
    return 'Tout télécharger (~$size Mo)';
  }

  @override
  String get voiceDownloads_installed => 'Installé';

  @override
  String get voiceDownloads_download => 'Télécharger';

  @override
  String voiceDownloads_downloading(int percent) {
    return 'Téléchargement… $percent %';
  }

  @override
  String get voiceDownloads_extracting => 'Installation… (quelques minutes)';

  @override
  String get voiceDownloads_failed =>
      'Échec du téléchargement — touchez pour réessayer';

  @override
  String get voiceDownloads_delete => 'Supprimer';

  @override
  String voiceDownloads_deleteConfirm(String name) {
    return 'Supprimer $name de ce téléphone ? Vous pourrez le retélécharger plus tard.';
  }

  @override
  String get voiceDownloads_cancel => 'Annuler';

  @override
  String voiceDownloads_sizeMb(int size) {
    return '~$size Mo';
  }

  @override
  String get voice_pcRequiredTitle => 'Voix réservée à l\'ordinateur';

  @override
  String get voice_pcRequiredBody =>
      'Cette voix (Qwen3-TTS) est générée par votre ordinateur avec TalkTome Boost, qui ne répond pas pour l\'instant. Allumez l\'ordinateur, vérifiez Profil → TalkTome Boost, ou choisissez une voix marquée « téléphone ».';
}
