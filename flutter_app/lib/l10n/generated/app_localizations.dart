import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// Nom de l'application
  ///
  /// In fr, this message translates to:
  /// **'TalkTome'**
  String get appTitle;

  /// No description provided for @miniPlayer_almostDone.
  ///
  /// In fr, this message translates to:
  /// **'Presque terminé'**
  String get miniPlayer_almostDone;

  /// No description provided for @miniPlayer_remainingMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Presque terminé} one{1 min restante} other{{count} min restantes}}'**
  String miniPlayer_remainingMinutes(int count);

  /// No description provided for @miniPlayer_remainingHoursMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{h}h {m}m restantes'**
  String miniPlayer_remainingHoursMinutes(int h, int m);

  /// No description provided for @nav_home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get nav_home;

  /// No description provided for @nav_library.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque'**
  String get nav_library;

  /// No description provided for @nav_annotations.
  ///
  /// In fr, this message translates to:
  /// **'Annotations'**
  String get nav_annotations;

  /// No description provided for @nav_profile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get nav_profile;

  /// No description provided for @nav_add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get nav_add;

  /// No description provided for @mainScreen_bookAdded.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » ajouté'**
  String mainScreen_bookAdded(String title);

  /// No description provided for @mainScreen_error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String mainScreen_error(String error);

  /// No description provided for @mainScreen_importFile.
  ///
  /// In fr, this message translates to:
  /// **'Importer un fichier'**
  String get mainScreen_importFile;

  /// No description provided for @mainScreen_pdfOrEpub.
  ///
  /// In fr, this message translates to:
  /// **'PDF ou EPUB'**
  String get mainScreen_pdfOrEpub;

  /// No description provided for @mainScreen_scanWithCamera.
  ///
  /// In fr, this message translates to:
  /// **'Scanner avec la caméra'**
  String get mainScreen_scanWithCamera;

  /// No description provided for @mainScreen_scanSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Photographier les pages d\'un livre papier'**
  String get mainScreen_scanSubtitle;

  /// No description provided for @mainScreen_bookCreatedFromScan.
  ///
  /// In fr, this message translates to:
  /// **'Livre créé à partir du scan'**
  String get mainScreen_bookCreatedFromScan;

  /// No description provided for @mainScreen_addFromUrl.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter depuis un site web'**
  String get mainScreen_addFromUrl;

  /// No description provided for @mainScreen_addFromUrlSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Collez le lien d\'un article'**
  String get mainScreen_addFromUrlSubtitle;

  /// No description provided for @mainScreen_urlHint.
  ///
  /// In fr, this message translates to:
  /// **'https://exemple.com/article'**
  String get mainScreen_urlHint;

  /// No description provided for @mainScreen_bookCreatedFromUrl.
  ///
  /// In fr, this message translates to:
  /// **'Livre créé à partir de page(s) web'**
  String get mainScreen_bookCreatedFromUrl;

  /// No description provided for @urlImport_addLink.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le lien'**
  String get urlImport_addLink;

  /// No description provided for @urlImport_orderHint.
  ///
  /// In fr, this message translates to:
  /// **'Les liens sont lus dans cet ordre — glissez pour réordonner'**
  String get urlImport_orderHint;

  /// No description provided for @urlImport_empty.
  ///
  /// In fr, this message translates to:
  /// **'Collez un lien ci-dessus et appuyez sur + pour l\'ajouter.\nAjoutez-en plusieurs pour les combiner en un seul livre, dans l\'ordre.'**
  String get urlImport_empty;

  /// No description provided for @urlImport_bookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre du livre'**
  String get urlImport_bookTitle;

  /// No description provided for @urlImport_defaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'{count} pages web'**
  String urlImport_defaultTitle(int count);

  /// No description provided for @urlImport_create.
  ///
  /// In fr, this message translates to:
  /// **'Créer le livre'**
  String get urlImport_create;

  /// No description provided for @urlImport_partialFailure.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 page n\'a} other{{count} pages n\'ont}} pas pu être récupérée(s) — les autres ont été ajoutées.'**
  String urlImport_partialFailure(int count);

  /// No description provided for @urlImport_continuationFound.
  ///
  /// In fr, this message translates to:
  /// **'Cette page se poursuit sur une autre page — l\'ajouter aussi ?'**
  String get urlImport_continuationFound;

  /// No description provided for @urlImport_add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get urlImport_add;

  /// No description provided for @urlImport_words.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 mot} other{{count} mots}}'**
  String urlImport_words(int count);

  /// No description provided for @tomy_greetMorning.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour !'**
  String get tomy_greetMorning;

  /// No description provided for @tomy_greetAfternoon.
  ///
  /// In fr, this message translates to:
  /// **'Bon après-midi !'**
  String get tomy_greetAfternoon;

  /// No description provided for @tomy_greetEvening.
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir !'**
  String get tomy_greetEvening;

  /// No description provided for @tomy_greetNight.
  ///
  /// In fr, this message translates to:
  /// **'Encore debout ?'**
  String get tomy_greetNight;

  /// No description provided for @tomy_continue.
  ///
  /// In fr, this message translates to:
  /// **'On reprend « {title} » ? Je suis prêt à te le lire.'**
  String tomy_continue(String title);

  /// No description provided for @tomy_streak.
  ///
  /// In fr, this message translates to:
  /// **'{count} jours d\'affilée, ne casse pas la série !'**
  String tomy_streak(int count);

  /// No description provided for @tomy_idle.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un livre dans ta bibliothèque et je te le lis à voix haute.'**
  String get tomy_idle;

  /// No description provided for @recentScreen_inProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get recentScreen_inProgress;

  /// No description provided for @recentScreen_statistics.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get recentScreen_statistics;

  /// No description provided for @recentScreen_today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get recentScreen_today;

  /// No description provided for @recentScreen_thisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get recentScreen_thisWeek;

  /// No description provided for @recentScreen_streak.
  ///
  /// In fr, this message translates to:
  /// **'Série'**
  String get recentScreen_streak;

  /// No description provided for @recentScreen_streakDays.
  ///
  /// In fr, this message translates to:
  /// **'{count} j'**
  String recentScreen_streakDays(int count);

  /// No description provided for @recentScreen_inProgressAndFinished.
  ///
  /// In fr, this message translates to:
  /// **'En cours / Terminés'**
  String get recentScreen_inProgressAndFinished;

  /// No description provided for @recentScreen_countRatio.
  ///
  /// In fr, this message translates to:
  /// **'{inProgress} / {finished}'**
  String recentScreen_countRatio(int inProgress, int finished);

  /// No description provided for @recentScreen_noBooks.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre'**
  String get recentScreen_noBooks;

  /// No description provided for @recentScreen_addPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Appuie sur + pour ajouter un PDF ou EPUB'**
  String get recentScreen_addPrompt;

  /// No description provided for @recentScreen_percentRead.
  ///
  /// In fr, this message translates to:
  /// **'{percent}% lu'**
  String recentScreen_percentRead(int percent);

  /// No description provided for @common_retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get common_retry;

  /// No description provided for @common_close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get common_close;

  /// No description provided for @common_delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get common_delete;

  /// No description provided for @common_save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get common_save;

  /// No description provided for @common_saved.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré'**
  String get common_saved;

  /// No description provided for @common_cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get common_cancel;

  /// No description provided for @common_noConnectionDictionary.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion — impossible de chercher ce mot'**
  String get common_noConnectionDictionary;

  /// No description provided for @common_noConnectionTranslation.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion — impossible de traduire'**
  String get common_noConnectionTranslation;

  /// No description provided for @dictionarySheet_alreadyInList.
  ///
  /// In fr, this message translates to:
  /// **'« {word} » est déjà dans votre liste'**
  String dictionarySheet_alreadyInList(String word);

  /// No description provided for @dictionarySheet_searching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de « {word} »…'**
  String dictionarySheet_searching(String word);

  /// No description provided for @dictionarySheet_listenPronunciation.
  ///
  /// In fr, this message translates to:
  /// **'Écouter la prononciation'**
  String get dictionarySheet_listenPronunciation;

  /// No description provided for @dictionarySheet_definition.
  ///
  /// In fr, this message translates to:
  /// **'Définition'**
  String get dictionarySheet_definition;

  /// No description provided for @dictionarySheet_synonyms.
  ///
  /// In fr, this message translates to:
  /// **'Synonymes'**
  String get dictionarySheet_synonyms;

  /// No description provided for @dictionarySheet_quotaExceeded.
  ///
  /// In fr, this message translates to:
  /// **'Quota temporairement épuisé — réessayez dans un instant'**
  String get dictionarySheet_quotaExceeded;

  /// No description provided for @dictionarySheet_localModelMissing.
  ///
  /// In fr, this message translates to:
  /// **'Le modèle d\'IA locale n\'est pas installé sur ce téléphone — le dictionnaire fonctionne entièrement sur l\'appareil'**
  String get dictionarySheet_localModelMissing;

  /// No description provided for @dictionarySheet_inThisSentence.
  ///
  /// In fr, this message translates to:
  /// **'Dans cette phrase'**
  String get dictionarySheet_inThisSentence;

  /// No description provided for @dictionarySheet_formOf.
  ///
  /// In fr, this message translates to:
  /// **'Forme de « {lemma} »'**
  String dictionarySheet_formOf(String lemma);

  /// No description provided for @dictionarySheet_unexpectedResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse inattendue du service'**
  String get dictionarySheet_unexpectedResponse;

  /// No description provided for @translationSheet_alreadySaved.
  ///
  /// In fr, this message translates to:
  /// **'Déjà enregistré dans vos traductions'**
  String get translationSheet_alreadySaved;

  /// No description provided for @translationSheet_originalText.
  ///
  /// In fr, this message translates to:
  /// **'Texte original'**
  String get translationSheet_originalText;

  /// No description provided for @translationSheet_translation.
  ///
  /// In fr, this message translates to:
  /// **'Traduction'**
  String get translationSheet_translation;

  /// No description provided for @camera_noCameraAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caméra disponible sur cet appareil.'**
  String get camera_noCameraAvailable;

  /// No description provided for @camera_accessDenied.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès à la caméra a été refusé. Autorisez-le dans les réglages de l\'application pour scanner des pages.'**
  String get camera_accessDenied;

  /// No description provided for @camera_unavailableWithReason.
  ///
  /// In fr, this message translates to:
  /// **'Caméra indisponible : {reason}'**
  String camera_unavailableWithReason(String reason);

  /// No description provided for @camera_captureFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec de la capture : {error}'**
  String camera_captureFailed(String error);

  /// No description provided for @camera_importFailed.
  ///
  /// In fr, this message translates to:
  /// **'Import impossible : {error}'**
  String camera_importFailed(String error);

  /// No description provided for @camera_abandonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner le scan ?'**
  String get camera_abandonTitle;

  /// No description provided for @camera_abandonBody.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 page scannée sera perdue.} other{{count} pages scannées seront perdues.}}'**
  String camera_abandonBody(int count);

  /// No description provided for @camera_continueScanning.
  ///
  /// In fr, this message translates to:
  /// **'Continuer le scan'**
  String get camera_continueScanning;

  /// No description provided for @camera_abandon.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get camera_abandon;

  /// No description provided for @camera_torch.
  ///
  /// In fr, this message translates to:
  /// **'Torche'**
  String get camera_torch;

  /// No description provided for @camera_processingPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Traitement de la photo…'**
  String get camera_processingPhoto;

  /// No description provided for @camera_importFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Importer depuis la galerie'**
  String get camera_importFromGallery;

  /// No description provided for @camera_gallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get camera_gallery;

  /// No description provided for @camera_finish.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get camera_finish;

  /// No description provided for @camera_scanBook.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un livre'**
  String get camera_scanBook;

  /// No description provided for @camera_pagesScanned.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 page scannée} other{{count} pages scannées}}'**
  String camera_pagesScanned(int count);

  /// No description provided for @crop_adjustTextArea.
  ///
  /// In fr, this message translates to:
  /// **'Ajuster la zone de texte'**
  String get crop_adjustTextArea;

  /// No description provided for @crop_rotate.
  ///
  /// In fr, this message translates to:
  /// **'Pivoter'**
  String get crop_rotate;

  /// No description provided for @crop_detectingTextArea.
  ///
  /// In fr, this message translates to:
  /// **'Détection de la zone de texte…'**
  String get crop_detectingTextArea;

  /// No description provided for @crop_noTextBlockDetected.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bloc de texte détecté — ajustez les coins à la main.'**
  String get crop_noTextBlockDetected;

  /// No description provided for @crop_detectionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Détection impossible : {error}'**
  String crop_detectionFailed(String error);

  /// No description provided for @crop_rotating.
  ///
  /// In fr, this message translates to:
  /// **'Rotation…'**
  String get crop_rotating;

  /// No description provided for @crop_cornersOverlap.
  ///
  /// In fr, this message translates to:
  /// **'Les coins se croisent — remettez-les dans l\'ordre.'**
  String get crop_cornersOverlap;

  /// No description provided for @crop_rectifyingAndReading.
  ///
  /// In fr, this message translates to:
  /// **'Redressement et lecture du texte…'**
  String get crop_rectifyingAndReading;

  /// No description provided for @crop_noTextRecognized.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte reconnu'**
  String get crop_noTextRecognized;

  /// No description provided for @crop_processingFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec du traitement : {error}'**
  String crop_processingFailed(String error);

  /// No description provided for @crop_auto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get crop_auto;

  /// No description provided for @crop_all.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get crop_all;

  /// No description provided for @crop_confirm.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get crop_confirm;

  /// No description provided for @scanReview_correctText.
  ///
  /// In fr, this message translates to:
  /// **'Corriger le texte'**
  String get scanReview_correctText;

  /// No description provided for @scanReview_noTextFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte'**
  String get scanReview_noTextFound;

  /// No description provided for @scanReview_defaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scan du {date}'**
  String scanReview_defaultTitle(String date);

  /// No description provided for @scanReview_bookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre du livre'**
  String get scanReview_bookTitle;

  /// No description provided for @scanReview_create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get scanReview_create;

  /// No description provided for @scanReview_noPagesWithText.
  ///
  /// In fr, this message translates to:
  /// **'Aucune page ne contient de texte reconnu.'**
  String get scanReview_noPagesWithText;

  /// No description provided for @scanReview_creationFailed.
  ///
  /// In fr, this message translates to:
  /// **'Création impossible : {error}'**
  String scanReview_creationFailed(String error);

  /// No description provided for @scanReview_verifyPages.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier les pages'**
  String get scanReview_verifyPages;

  /// No description provided for @scanReview_pagesWordsSummary.
  ///
  /// In fr, this message translates to:
  /// **'{pageCount} page(s) • {wordCount} mots reconnus'**
  String scanReview_pagesWordsSummary(int pageCount, int wordCount);

  /// No description provided for @scanReview_createBook.
  ///
  /// In fr, this message translates to:
  /// **'Créer le livre'**
  String get scanReview_createBook;

  /// No description provided for @scanReview_pageWordCount.
  ///
  /// In fr, this message translates to:
  /// **'Page {index} • {words} mots'**
  String scanReview_pageWordCount(int index, int words);

  /// No description provided for @scanReview_recrop.
  ///
  /// In fr, this message translates to:
  /// **'Recadrer'**
  String get scanReview_recrop;

  /// No description provided for @annotations_allAnnotations.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les annotations'**
  String get annotations_allAnnotations;

  /// No description provided for @annotations_tabHighlights.
  ///
  /// In fr, this message translates to:
  /// **'Surlignages'**
  String get annotations_tabHighlights;

  /// No description provided for @annotations_tabDictionary.
  ///
  /// In fr, this message translates to:
  /// **'Dictionnaire'**
  String get annotations_tabDictionary;

  /// No description provided for @annotations_tabTranslations.
  ///
  /// In fr, this message translates to:
  /// **'Traductions'**
  String get annotations_tabTranslations;

  /// No description provided for @annotations_justNow.
  ///
  /// In fr, this message translates to:
  /// **'à l\'instant'**
  String get annotations_justNow;

  /// No description provided for @annotations_minutesAgo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{il y a 1 min} other{il y a {count} min}}'**
  String annotations_minutesAgo(int count);

  /// No description provided for @annotations_hoursAgo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{il y a 1 h} other{il y a {count} h}}'**
  String annotations_hoursAgo(int count);

  /// No description provided for @annotations_daysAgo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{il y a 1 j} other{il y a {count} j}}'**
  String annotations_daysAgo(int count);

  /// No description provided for @annotations_noHighlights.
  ///
  /// In fr, this message translates to:
  /// **'Aucun passage surligné'**
  String get annotations_noHighlights;

  /// No description provided for @annotations_noHighlightsHint.
  ///
  /// In fr, this message translates to:
  /// **'Tenez le doigt sur un mot pendant la lecture pour surligner un passage'**
  String get annotations_noHighlightsHint;

  /// No description provided for @annotations_noWords.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mot enregistré'**
  String get annotations_noWords;

  /// No description provided for @annotations_noWordsHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un mot pendant la lecture, puis appuyez sur Définir'**
  String get annotations_noWordsHint;

  /// No description provided for @annotations_noTranslations.
  ///
  /// In fr, this message translates to:
  /// **'Aucune traduction enregistrée'**
  String get annotations_noTranslations;

  /// No description provided for @annotations_noTranslationsHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un mot ou une phrase pendant la lecture, puis appuyez sur Traduire'**
  String get annotations_noTranslationsHint;

  /// No description provided for @profileScreen_periodDay.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get profileScreen_periodDay;

  /// No description provided for @profileScreen_periodWeek.
  ///
  /// In fr, this message translates to:
  /// **'Semaine'**
  String get profileScreen_periodWeek;

  /// No description provided for @profileScreen_periodMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get profileScreen_periodMonth;

  /// No description provided for @profileScreen_periodSixMonths.
  ///
  /// In fr, this message translates to:
  /// **'6 mois'**
  String get profileScreen_periodSixMonths;

  /// No description provided for @profileScreen_periodYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get profileScreen_periodYear;

  /// No description provided for @profileScreen_readingTimeForPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Temps de lecture — {period}'**
  String profileScreen_readingTimeForPeriod(String period);

  /// No description provided for @profileScreen_avgPerWeek.
  ///
  /// In fr, this message translates to:
  /// **'Moy. par semaine'**
  String get profileScreen_avgPerWeek;

  /// No description provided for @profileScreen_totalReading.
  ///
  /// In fr, this message translates to:
  /// **'Total de lecture'**
  String get profileScreen_totalReading;

  /// No description provided for @profileScreen_breakdown.
  ///
  /// In fr, this message translates to:
  /// **'RÉPARTITION'**
  String get profileScreen_breakdown;

  /// No description provided for @profileScreen_noReadingRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Aucune lecture enregistrée'**
  String get profileScreen_noReadingRecorded;

  /// No description provided for @profileScreen_startReadingHint.
  ///
  /// In fr, this message translates to:
  /// **'Commence à lire pour voir tes statistiques'**
  String get profileScreen_startReadingHint;

  /// No description provided for @profileScreen_appearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get profileScreen_appearance;

  /// No description provided for @profileScreen_expressiveReading.
  ///
  /// In fr, this message translates to:
  /// **'Lecture expressive'**
  String get profileScreen_expressiveReading;

  /// No description provided for @profileScreen_expressiveReadingHint.
  ///
  /// In fr, this message translates to:
  /// **'La voix adapte son rythme, son ton et ses pauses à l\'émotion de chaque phrase (analyse par l\'IA de l\'ordinateur quand TalkTome Boost est connecté)'**
  String get profileScreen_expressiveReadingHint;

  /// No description provided for @profileScreen_system.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get profileScreen_system;

  /// No description provided for @profileScreen_light.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get profileScreen_light;

  /// No description provided for @profileScreen_dark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get profileScreen_dark;

  /// No description provided for @profileScreen_text.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get profileScreen_text;

  /// No description provided for @profileScreen_textSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille du texte'**
  String get profileScreen_textSize;

  /// No description provided for @profileScreen_pt.
  ///
  /// In fr, this message translates to:
  /// **'{size} pt'**
  String profileScreen_pt(int size);

  /// No description provided for @profileScreen_font.
  ///
  /// In fr, this message translates to:
  /// **'Police'**
  String get profileScreen_font;

  /// No description provided for @profileScreen_readerMargin.
  ///
  /// In fr, this message translates to:
  /// **'Marges du texte'**
  String get profileScreen_readerMargin;

  /// No description provided for @profileScreen_readerMarginHint.
  ///
  /// In fr, this message translates to:
  /// **'Espace au-dessus et au-dessous du texte en mode livre, et quand on masque le lecteur (l\'œil)'**
  String get profileScreen_readerMarginHint;

  /// No description provided for @profileScreen_default.
  ///
  /// In fr, this message translates to:
  /// **'Défaut'**
  String get profileScreen_default;

  /// No description provided for @profileScreen_serif.
  ///
  /// In fr, this message translates to:
  /// **'Serif'**
  String get profileScreen_serif;

  /// No description provided for @profileScreen_monospace.
  ///
  /// In fr, this message translates to:
  /// **'Monospace'**
  String get profileScreen_monospace;

  /// No description provided for @profileScreen_dictionaryLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue du dictionnaire'**
  String get profileScreen_dictionaryLanguage;

  /// No description provided for @profileScreen_dictionaryLanguageHint.
  ///
  /// In fr, this message translates to:
  /// **'Langue des définitions pendant la lecture'**
  String get profileScreen_dictionaryLanguageHint;

  /// No description provided for @profileScreen_translationLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue de traduction'**
  String get profileScreen_translationLanguage;

  /// No description provided for @profileScreen_translationLanguageHint.
  ///
  /// In fr, this message translates to:
  /// **'Traduction en direct et manuelle pendant la lecture'**
  String get profileScreen_translationLanguageHint;

  /// No description provided for @profileScreen_languageSection.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get profileScreen_languageSection;

  /// No description provided for @profileScreen_appLanguageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'application'**
  String get profileScreen_appLanguageLabel;

  /// No description provided for @home_renameBookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le livre'**
  String get home_renameBookTitle;

  /// No description provided for @home_titleFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get home_titleFieldLabel;

  /// No description provided for @home_deleteBookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le livre'**
  String get home_deleteBookTitle;

  /// No description provided for @home_deleteBookConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {title} » ?'**
  String home_deleteBookConfirm(String title);

  /// No description provided for @home_bookDeleted.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » supprimé'**
  String home_bookDeleted(String title);

  /// No description provided for @home_deleteBooksTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer les livres'**
  String get home_deleteBooksTitle;

  /// No description provided for @home_deleteSelectedConfirm.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Supprimer 1 livre sélectionné ?} other{Supprimer {count} livres sélectionnés ?}}'**
  String home_deleteSelectedConfirm(int count);

  /// No description provided for @home_newFolder.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau dossier'**
  String get home_newFolder;

  /// No description provided for @home_folderNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du dossier'**
  String get home_folderNameLabel;

  /// No description provided for @home_renameFolderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le dossier'**
  String get home_renameFolderTitle;

  /// No description provided for @home_nameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get home_nameLabel;

  /// No description provided for @home_deleteFolderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le dossier'**
  String get home_deleteFolderTitle;

  /// No description provided for @home_deleteFolderWithBooksConfirm.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Supprimer « {name} » ? Le livre sera déplacé à la racine.} other{Supprimer « {name} » ? Les {count} livres seront déplacés à la racine.}}'**
  String home_deleteFolderWithBooksConfirm(int count, String name);

  /// No description provided for @home_deleteFolderEmptyConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le dossier « {name} » ?'**
  String home_deleteFolderEmptyConfirm(String name);

  /// No description provided for @home_moveToFolderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer dans un dossier'**
  String get home_moveToFolderTitle;

  /// No description provided for @home_noFolderRoot.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dossier (racine)'**
  String get home_noFolderRoot;

  /// No description provided for @home_move.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer'**
  String get home_move;

  /// No description provided for @home_moveToFolderMenu.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer dans un dossier'**
  String get home_moveToFolderMenu;

  /// No description provided for @home_selectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 sélectionné} other{{count} sélectionnés}}'**
  String home_selectedCount(int count);

  /// No description provided for @home_booksCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 livre} other{{count} livres}}'**
  String home_booksCount(int count);

  /// No description provided for @home_folders.
  ///
  /// In fr, this message translates to:
  /// **'Dossiers'**
  String get home_folders;

  /// No description provided for @home_noBooksHere.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre ici'**
  String get home_noBooksHere;

  /// No description provided for @home_books.
  ///
  /// In fr, this message translates to:
  /// **'Livres'**
  String get home_books;

  /// No description provided for @home_notStarted.
  ///
  /// In fr, this message translates to:
  /// **'Non commencé'**
  String get home_notStarted;

  /// No description provided for @home_finished.
  ///
  /// In fr, this message translates to:
  /// **'Terminé ✓'**
  String get home_finished;

  /// No description provided for @home_percentReadSentence.
  ///
  /// In fr, this message translates to:
  /// **'{percent}% lu • phrase {pos} / {total}'**
  String home_percentReadSentence(int percent, int pos, int total);

  /// No description provided for @home_open.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get home_open;

  /// No description provided for @home_rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get home_rename;

  /// No description provided for @home_select.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner'**
  String get home_select;

  /// No description provided for @home_create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get home_create;

  /// No description provided for @home_noBooks.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre'**
  String get home_noBooks;

  /// No description provided for @home_addPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur + pour ajouter un PDF ou EPUB'**
  String get home_addPrompt;

  /// No description provided for @reader_define.
  ///
  /// In fr, this message translates to:
  /// **'Définir'**
  String get reader_define;

  /// No description provided for @reader_translate.
  ///
  /// In fr, this message translates to:
  /// **'Traduire'**
  String get reader_translate;

  /// No description provided for @reader_highlight.
  ///
  /// In fr, this message translates to:
  /// **'Surligner'**
  String get reader_highlight;

  /// No description provided for @reader_definitionsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue des définitions'**
  String get reader_definitionsLanguage;

  /// No description provided for @reader_liveTranslationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Traduction en direct'**
  String get reader_liveTranslationTitle;

  /// No description provided for @reader_enabled.
  ///
  /// In fr, this message translates to:
  /// **'Activée'**
  String get reader_enabled;

  /// No description provided for @reader_translationBubbleHint.
  ///
  /// In fr, this message translates to:
  /// **'Bulle de traduction pendant la lecture'**
  String get reader_translationBubbleHint;

  /// No description provided for @reader_readingSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get reader_readingSpeed;

  /// No description provided for @reader_slower.
  ///
  /// In fr, this message translates to:
  /// **'Plus lent'**
  String get reader_slower;

  /// No description provided for @reader_faster.
  ///
  /// In fr, this message translates to:
  /// **'Plus rapide'**
  String get reader_faster;

  /// No description provided for @reader_chooseVoice.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une voix'**
  String get reader_chooseVoice;

  /// No description provided for @reader_highQualityNoWordHighlight.
  ///
  /// In fr, this message translates to:
  /// **'Haute qualité — sans surlignage mot par mot'**
  String get reader_highQualityNoWordHighlight;

  /// No description provided for @reader_fontCondensed.
  ///
  /// In fr, this message translates to:
  /// **'Condensé'**
  String get reader_fontCondensed;

  /// No description provided for @reader_fontCursive.
  ///
  /// In fr, this message translates to:
  /// **'Cursif'**
  String get reader_fontCursive;

  /// No description provided for @reader_background.
  ///
  /// In fr, this message translates to:
  /// **'FOND'**
  String get reader_background;

  /// No description provided for @reader_textSizeSection.
  ///
  /// In fr, this message translates to:
  /// **'TAILLE DU TEXTE'**
  String get reader_textSizeSection;

  /// No description provided for @reader_fontSection.
  ///
  /// In fr, this message translates to:
  /// **'POLICE'**
  String get reader_fontSection;

  /// No description provided for @reader_renameFileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le fichier'**
  String get reader_renameFileTitle;

  /// No description provided for @reader_documentNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom du document'**
  String get reader_documentNameHint;

  /// No description provided for @reader_searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans le document…'**
  String get reader_searchHint;

  /// No description provided for @reader_resultCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 résultat} other{{count} résultats}}'**
  String reader_resultCount(int count);

  /// No description provided for @reader_chapterSentence.
  ///
  /// In fr, this message translates to:
  /// **'Chapitre {chapter} · Phrase {sentence}'**
  String reader_chapterSentence(int chapter, int sentence);

  /// No description provided for @reader_tableOfContents.
  ///
  /// In fr, this message translates to:
  /// **'Table des matières'**
  String get reader_tableOfContents;

  /// No description provided for @reader_wordCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 mot} other{{count} mots}}'**
  String reader_wordCount(int count);

  /// No description provided for @reader_options.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get reader_options;

  /// No description provided for @reader_annotationsOfThisBook.
  ///
  /// In fr, this message translates to:
  /// **'Annotations de ce livre'**
  String get reader_annotationsOfThisBook;

  /// No description provided for @reader_search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get reader_search;

  /// No description provided for @reader_hideReader.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le lecteur'**
  String get reader_hideReader;

  /// No description provided for @reader_showReader.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le lecteur'**
  String get reader_showReader;

  /// No description provided for @reader_disableAutoScroll.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver défilement auto'**
  String get reader_disableAutoScroll;

  /// No description provided for @reader_enableAutoScroll.
  ///
  /// In fr, this message translates to:
  /// **'Activer défilement auto'**
  String get reader_enableAutoScroll;

  /// No description provided for @reader_showControls.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les contrôles'**
  String get reader_showControls;

  /// No description provided for @reader_previousSentence.
  ///
  /// In fr, this message translates to:
  /// **'Phrase précédente'**
  String get reader_previousSentence;

  /// No description provided for @reader_nextSentence.
  ///
  /// In fr, this message translates to:
  /// **'Phrase suivante'**
  String get reader_nextSentence;

  /// No description provided for @reader_readTranslationAloud.
  ///
  /// In fr, this message translates to:
  /// **'Lire la traduction à voix haute'**
  String get reader_readTranslationAloud;

  /// No description provided for @reader_readTranslationAloudHint.
  ///
  /// In fr, this message translates to:
  /// **'La voix lit la traduction à la place du texte du livre'**
  String get reader_readTranslationAloudHint;

  /// No description provided for @reader_translationVoice.
  ///
  /// In fr, this message translates to:
  /// **'Voix de la traduction'**
  String get reader_translationVoice;

  /// No description provided for @reader_noVoiceForLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune voix installée pour cette langue'**
  String get reader_noVoiceForLanguage;

  /// No description provided for @profileScreen_boostSection.
  ///
  /// In fr, this message translates to:
  /// **'Accélération par l\'ordinateur'**
  String get profileScreen_boostSection;

  /// No description provided for @profileScreen_boostOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivée — tout se fait sur le téléphone'**
  String get profileScreen_boostOff;

  /// No description provided for @profileScreen_boostSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de l\'ordinateur…'**
  String get profileScreen_boostSearching;

  /// No description provided for @profileScreen_boostConnected.
  ///
  /// In fr, this message translates to:
  /// **'Connecté à {host} — voix et IA sur l\'ordinateur'**
  String profileScreen_boostConnected(String host);

  /// No description provided for @profileScreen_boostUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Ordinateur introuvable — le téléphone prend le relais'**
  String get profileScreen_boostUnreachable;

  /// No description provided for @profileScreen_boostEnable.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser l\'ordinateur quand il est joignable'**
  String get profileScreen_boostEnable;

  /// No description provided for @profileScreen_boostHosts.
  ///
  /// In fr, this message translates to:
  /// **'Adresses de l\'ordinateur'**
  String get profileScreen_boostHosts;

  /// No description provided for @profileScreen_boostHostsHint.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi et Tailscale, séparées par des virgules'**
  String get profileScreen_boostHostsHint;

  /// No description provided for @profileScreen_boostCode.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'appairage (6 chiffres)'**
  String get profileScreen_boostCode;

  /// No description provided for @profileScreen_boostTest.
  ///
  /// In fr, this message translates to:
  /// **'Tester'**
  String get profileScreen_boostTest;

  /// No description provided for @reader_pageColor.
  ///
  /// In fr, this message translates to:
  /// **'COULEUR DE PAGE'**
  String get reader_pageColor;

  /// No description provided for @reader_pageAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get reader_pageAuto;

  /// No description provided for @reader_pageWhite.
  ///
  /// In fr, this message translates to:
  /// **'Blanc'**
  String get reader_pageWhite;

  /// No description provided for @reader_pagePaper.
  ///
  /// In fr, this message translates to:
  /// **'Papier'**
  String get reader_pagePaper;

  /// No description provided for @reader_pageGreen.
  ///
  /// In fr, this message translates to:
  /// **'Vert'**
  String get reader_pageGreen;

  /// No description provided for @reader_pageGray.
  ///
  /// In fr, this message translates to:
  /// **'Gris'**
  String get reader_pageGray;

  /// No description provided for @reader_pageNight.
  ///
  /// In fr, this message translates to:
  /// **'Nuit'**
  String get reader_pageNight;

  /// No description provided for @reader_warmth.
  ///
  /// In fr, this message translates to:
  /// **'Filtre chaud'**
  String get reader_warmth;

  /// No description provided for @reader_dim.
  ///
  /// In fr, this message translates to:
  /// **'Assombrir'**
  String get reader_dim;

  /// No description provided for @reader_voicePitch.
  ///
  /// In fr, this message translates to:
  /// **'Timbre de la voix'**
  String get reader_voicePitch;

  /// No description provided for @reader_pitchDeeper.
  ///
  /// In fr, this message translates to:
  /// **'Plus grave'**
  String get reader_pitchDeeper;

  /// No description provided for @reader_pitchLighter.
  ///
  /// In fr, this message translates to:
  /// **'Plus aiguë'**
  String get reader_pitchLighter;

  /// No description provided for @reader_pitchNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get reader_pitchNormal;

  /// No description provided for @reader_bookMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode livre (pages)'**
  String get reader_bookMode;

  /// No description provided for @reader_scrollMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode défilement'**
  String get reader_scrollMode;

  /// No description provided for @reader_pageTurn.
  ///
  /// In fr, this message translates to:
  /// **'Animation de page'**
  String get reader_pageTurn;

  /// No description provided for @reader_pageTurnCurl.
  ///
  /// In fr, this message translates to:
  /// **'Page qui tourne'**
  String get reader_pageTurnCurl;

  /// No description provided for @reader_pageTurnSlide.
  ///
  /// In fr, this message translates to:
  /// **'Glissement'**
  String get reader_pageTurnSlide;

  /// No description provided for @reader_pageOf.
  ///
  /// In fr, this message translates to:
  /// **'Page {page} sur {total}'**
  String reader_pageOf(int page, int total);

  /// No description provided for @reader_pause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get reader_pause;

  /// No description provided for @reader_play.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get reader_play;

  /// No description provided for @audioHandler_sentenceProgress.
  ///
  /// In fr, this message translates to:
  /// **'Phrase {current} / {total}'**
  String audioHandler_sentenceProgress(int current, int total);

  /// No description provided for @voiceDownloads_title.
  ///
  /// In fr, this message translates to:
  /// **'Voix IA'**
  String get voiceDownloads_title;

  /// No description provided for @voiceDownloads_manage.
  ///
  /// In fr, this message translates to:
  /// **'Voix IA'**
  String get voiceDownloads_manage;

  /// No description provided for @voiceDownloads_section.
  ///
  /// In fr, this message translates to:
  /// **'Voix IA'**
  String get voiceDownloads_section;

  /// No description provided for @voiceDownloads_tileSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{installed} / {total} modèles installés sur ce téléphone'**
  String voiceDownloads_tileSubtitle(int installed, int total);

  /// No description provided for @voiceDownloads_intro.
  ///
  /// In fr, this message translates to:
  /// **'Les voix IA fonctionnent hors ligne, directement sur le téléphone. Téléchargez celles que vous voulez — le Wi-Fi est conseillé, et gardez l\'application ouverte pendant l\'installation.'**
  String get voiceDownloads_intro;

  /// No description provided for @voiceDownloads_installAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout télécharger (~{size} Mo)'**
  String voiceDownloads_installAll(int size);

  /// No description provided for @voiceDownloads_installed.
  ///
  /// In fr, this message translates to:
  /// **'Installé'**
  String get voiceDownloads_installed;

  /// No description provided for @voiceDownloads_download.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get voiceDownloads_download;

  /// No description provided for @voiceDownloads_downloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement… {percent} %'**
  String voiceDownloads_downloading(int percent);

  /// No description provided for @voiceDownloads_extracting.
  ///
  /// In fr, this message translates to:
  /// **'Installation… (quelques minutes)'**
  String get voiceDownloads_extracting;

  /// No description provided for @voiceDownloads_failed.
  ///
  /// In fr, this message translates to:
  /// **'Échec du téléchargement — touchez pour réessayer'**
  String get voiceDownloads_failed;

  /// No description provided for @voiceDownloads_delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get voiceDownloads_delete;

  /// No description provided for @voiceDownloads_deleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {name} de ce téléphone ? Vous pourrez le retélécharger plus tard.'**
  String voiceDownloads_deleteConfirm(String name);

  /// No description provided for @voiceDownloads_cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get voiceDownloads_cancel;

  /// No description provided for @voiceDownloads_sizeMb.
  ///
  /// In fr, this message translates to:
  /// **'~{size} Mo'**
  String voiceDownloads_sizeMb(int size);

  /// No description provided for @voice_pcRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Voix réservée à l\'ordinateur'**
  String get voice_pcRequiredTitle;

  /// No description provided for @voice_pcRequiredBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette voix (Qwen3-TTS) est générée par votre ordinateur avec TalkTome Boost, qui ne répond pas pour l\'instant. Allumez l\'ordinateur, vérifiez Profil → TalkTome Boost, ou choisissez une voix marquée « téléphone ».'**
  String get voice_pcRequiredBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
