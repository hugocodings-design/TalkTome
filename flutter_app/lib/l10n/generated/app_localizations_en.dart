// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TalkTome';

  @override
  String get miniPlayer_almostDone => 'Almost done';

  @override
  String miniPlayer_remainingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min left',
      one: '1 min left',
      zero: 'Almost done',
    );
    return '$_temp0';
  }

  @override
  String miniPlayer_remainingHoursMinutes(int h, int m) {
    return '${h}h ${m}m left';
  }

  @override
  String get nav_home => 'Home';

  @override
  String get nav_library => 'Library';

  @override
  String get nav_annotations => 'Annotations';

  @override
  String get nav_profile => 'Profile';

  @override
  String get nav_add => 'Add';

  @override
  String mainScreen_bookAdded(String title) {
    return '\"$title\" added';
  }

  @override
  String mainScreen_error(String error) {
    return 'Error: $error';
  }

  @override
  String get mainScreen_importFile => 'Import a file';

  @override
  String get mainScreen_pdfOrEpub => 'PDF or EPUB';

  @override
  String get mainScreen_scanWithCamera => 'Scan with camera';

  @override
  String get mainScreen_scanSubtitle => 'Photograph the pages of a paper book';

  @override
  String get mainScreen_bookCreatedFromScan => 'Book created from scan';

  @override
  String get mainScreen_addFromUrl => 'Add from a website';

  @override
  String get mainScreen_addFromUrlSubtitle => 'Paste a link to an article';

  @override
  String get mainScreen_urlHint => 'https://example.com/article';

  @override
  String get mainScreen_bookCreatedFromUrl => 'Book created from web page(s)';

  @override
  String get urlImport_addLink => 'Add link';

  @override
  String get urlImport_orderHint =>
      'Links are read in this order — drag to reorder';

  @override
  String get urlImport_empty =>
      'Paste a link above and tap + to add it.\nAdd several to combine them into a single book, in order.';

  @override
  String get urlImport_bookTitle => 'Book title';

  @override
  String urlImport_defaultTitle(int count) {
    return '$count web pages';
  }

  @override
  String get urlImport_create => 'Create book';

  @override
  String urlImport_partialFailure(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0 could not be fetched — the rest were added.';
  }

  @override
  String get urlImport_continuationFound =>
      'This page continues on another page — add it too?';

  @override
  String get urlImport_add => 'Add';

  @override
  String urlImport_words(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String get recentScreen_inProgress => 'In progress';

  @override
  String get recentScreen_statistics => 'Statistics';

  @override
  String get recentScreen_today => 'Today';

  @override
  String get recentScreen_thisWeek => 'This week';

  @override
  String get recentScreen_streak => 'Streak';

  @override
  String recentScreen_streakDays(int count) {
    return '$count d';
  }

  @override
  String get recentScreen_inProgressAndFinished => 'In progress / Finished';

  @override
  String recentScreen_countRatio(int inProgress, int finished) {
    return '$inProgress / $finished';
  }

  @override
  String get recentScreen_noBooks => 'No books';

  @override
  String get recentScreen_addPrompt => 'Tap + to add a PDF or EPUB';

  @override
  String recentScreen_percentRead(int percent) {
    return '$percent% read';
  }

  @override
  String get common_retry => 'Retry';

  @override
  String get common_close => 'Close';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_save => 'Save';

  @override
  String get common_saved => 'Saved';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_noConnectionDictionary =>
      'No connection — can\'t look up this word';

  @override
  String get common_noConnectionTranslation =>
      'No connection — can\'t translate';

  @override
  String dictionarySheet_alreadyInList(String word) {
    return '\"$word\" is already in your list';
  }

  @override
  String dictionarySheet_searching(String word) {
    return 'Looking up \"$word\"…';
  }

  @override
  String get dictionarySheet_listenPronunciation => 'Listen to pronunciation';

  @override
  String get dictionarySheet_definition => 'Definition';

  @override
  String get dictionarySheet_synonyms => 'Synonyms';

  @override
  String get dictionarySheet_quotaExceeded =>
      'Quota temporarily exhausted — try again in a moment';

  @override
  String get dictionarySheet_localModelMissing =>
      'The local AI model isn\'t installed on this phone — the dictionary runs entirely on the device';

  @override
  String get dictionarySheet_inThisSentence => 'In this sentence';

  @override
  String dictionarySheet_formOf(String lemma) {
    return 'Form of “$lemma”';
  }

  @override
  String get dictionarySheet_unexpectedResponse =>
      'Unexpected response from the service';

  @override
  String get translationSheet_alreadySaved =>
      'Already saved in your translations';

  @override
  String get translationSheet_originalText => 'Original text';

  @override
  String get translationSheet_translation => 'Translation';

  @override
  String get camera_noCameraAvailable => 'No camera available on this device.';

  @override
  String get camera_accessDenied =>
      'Camera access was denied. Allow it in the app settings to scan pages.';

  @override
  String camera_unavailableWithReason(String reason) {
    return 'Camera unavailable: $reason';
  }

  @override
  String camera_captureFailed(String error) {
    return 'Capture failed: $error';
  }

  @override
  String camera_importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get camera_abandonTitle => 'Abandon the scan?';

  @override
  String camera_abandonBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scanned pages will be lost.',
      one: '1 scanned page will be lost.',
    );
    return '$_temp0';
  }

  @override
  String get camera_continueScanning => 'Continue scanning';

  @override
  String get camera_abandon => 'Abandon';

  @override
  String get camera_torch => 'Flashlight';

  @override
  String get camera_processingPhoto => 'Processing photo…';

  @override
  String get camera_importFromGallery => 'Import from gallery';

  @override
  String get camera_gallery => 'Gallery';

  @override
  String get camera_finish => 'Finish';

  @override
  String get camera_scanBook => 'Scan a book';

  @override
  String camera_pagesScanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages scanned',
      one: '1 page scanned',
    );
    return '$_temp0';
  }

  @override
  String get crop_adjustTextArea => 'Adjust the text area';

  @override
  String get crop_rotate => 'Rotate';

  @override
  String get crop_detectingTextArea => 'Detecting text area…';

  @override
  String get crop_noTextBlockDetected =>
      'No text block detected — adjust the corners manually.';

  @override
  String crop_detectionFailed(String error) {
    return 'Detection failed: $error';
  }

  @override
  String get crop_rotating => 'Rotating…';

  @override
  String get crop_cornersOverlap =>
      'The corners overlap — put them back in order.';

  @override
  String get crop_rectifyingAndReading => 'Straightening and reading the text…';

  @override
  String get crop_noTextRecognized => 'No text recognized';

  @override
  String crop_processingFailed(String error) {
    return 'Processing failed: $error';
  }

  @override
  String get crop_auto => 'Auto';

  @override
  String get crop_all => 'All';

  @override
  String get crop_confirm => 'Confirm';

  @override
  String get scanReview_correctText => 'Correct the text';

  @override
  String get scanReview_noTextFound => 'No text';

  @override
  String scanReview_defaultTitle(String date) {
    return 'Scan of $date';
  }

  @override
  String get scanReview_bookTitle => 'Book title';

  @override
  String get scanReview_create => 'Create';

  @override
  String get scanReview_noPagesWithText => 'No page contains recognized text.';

  @override
  String scanReview_creationFailed(String error) {
    return 'Creation failed: $error';
  }

  @override
  String get scanReview_verifyPages => 'Review pages';

  @override
  String scanReview_pagesWordsSummary(int pageCount, int wordCount) {
    return '$pageCount page(s) • $wordCount words recognized';
  }

  @override
  String get scanReview_createBook => 'Create the book';

  @override
  String scanReview_pageWordCount(int index, int words) {
    return 'Page $index • $words words';
  }

  @override
  String get scanReview_recrop => 'Recrop';

  @override
  String get annotations_allAnnotations => 'All annotations';

  @override
  String get annotations_tabHighlights => 'Highlights';

  @override
  String get annotations_tabDictionary => 'Dictionary';

  @override
  String get annotations_tabTranslations => 'Translations';

  @override
  String get annotations_justNow => 'just now';

  @override
  String annotations_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String annotations_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
      one: '1 h ago',
    );
    return '$_temp0';
  }

  @override
  String annotations_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count d ago',
      one: '1 d ago',
    );
    return '$_temp0';
  }

  @override
  String get annotations_noHighlights => 'No highlighted passages';

  @override
  String get annotations_noHighlightsHint =>
      'Hold your finger on a word while reading to highlight a passage';

  @override
  String get annotations_noWords => 'No saved words';

  @override
  String get annotations_noWordsHint =>
      'Select a word while reading, then tap Define';

  @override
  String get annotations_noTranslations => 'No saved translations';

  @override
  String get annotations_noTranslationsHint =>
      'Select a word or sentence while reading, then tap Translate';

  @override
  String get profileScreen_periodDay => 'Day';

  @override
  String get profileScreen_periodWeek => 'Week';

  @override
  String get profileScreen_periodMonth => 'Month';

  @override
  String get profileScreen_periodSixMonths => '6 months';

  @override
  String get profileScreen_periodYear => 'Year';

  @override
  String profileScreen_readingTimeForPeriod(String period) {
    return 'Reading time — $period';
  }

  @override
  String get profileScreen_avgPerWeek => 'Avg. per week';

  @override
  String get profileScreen_totalReading => 'Total reading';

  @override
  String get profileScreen_breakdown => 'BREAKDOWN';

  @override
  String get profileScreen_noReadingRecorded => 'No reading recorded';

  @override
  String get profileScreen_startReadingHint =>
      'Start reading to see your stats';

  @override
  String get profileScreen_appearance => 'Appearance';

  @override
  String get profileScreen_expressiveReading => 'Expressive reading';

  @override
  String get profileScreen_expressiveReadingHint =>
      'The voice adapts its pace, tone and pauses to each sentence\'s emotion (analyzed by your computer\'s AI when TalkTome Boost is connected)';

  @override
  String get profileScreen_system => 'System';

  @override
  String get profileScreen_light => 'Light';

  @override
  String get profileScreen_dark => 'Dark';

  @override
  String get profileScreen_text => 'Text';

  @override
  String get profileScreen_textSize => 'Text size';

  @override
  String profileScreen_pt(int size) {
    return '$size pt';
  }

  @override
  String get profileScreen_font => 'Font';

  @override
  String get profileScreen_readerMargin => 'Text margins';

  @override
  String get profileScreen_readerMarginHint =>
      'Space above and below the text in book mode, and when you hide the player (the eye icon)';

  @override
  String get profileScreen_default => 'Default';

  @override
  String get profileScreen_serif => 'Serif';

  @override
  String get profileScreen_monospace => 'Monospace';

  @override
  String get profileScreen_dictionaryLanguage => 'Dictionary language';

  @override
  String get profileScreen_dictionaryLanguageHint =>
      'Language of definitions while reading';

  @override
  String get profileScreen_translationLanguage => 'Translation language';

  @override
  String get profileScreen_translationLanguageHint =>
      'Live and manual translation while reading';

  @override
  String get profileScreen_languageSection => 'Language';

  @override
  String get profileScreen_appLanguageLabel => 'App language';

  @override
  String get home_renameBookTitle => 'Rename book';

  @override
  String get home_titleFieldLabel => 'Title';

  @override
  String get home_deleteBookTitle => 'Delete book';

  @override
  String home_deleteBookConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String home_bookDeleted(String title) {
    return '\"$title\" deleted';
  }

  @override
  String get home_deleteBooksTitle => 'Delete books';

  @override
  String home_deleteSelectedConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count selected books?',
      one: 'Delete 1 selected book?',
    );
    return '$_temp0';
  }

  @override
  String get home_newFolder => 'New folder';

  @override
  String get home_folderNameLabel => 'Folder name';

  @override
  String get home_renameFolderTitle => 'Rename folder';

  @override
  String get home_nameLabel => 'Name';

  @override
  String get home_deleteFolderTitle => 'Delete folder';

  @override
  String home_deleteFolderWithBooksConfirm(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete \"$name\"? The $count books will be moved to the root.',
      one: 'Delete \"$name\"? The book will be moved to the root.',
    );
    return '$_temp0';
  }

  @override
  String home_deleteFolderEmptyConfirm(String name) {
    return 'Delete folder \"$name\"?';
  }

  @override
  String get home_moveToFolderTitle => 'Move to a folder';

  @override
  String get home_noFolderRoot => 'No folder (root)';

  @override
  String get home_move => 'Move';

  @override
  String get home_moveToFolderMenu => 'Move to a folder';

  @override
  String home_selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String home_booksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String get home_folders => 'Folders';

  @override
  String get home_noBooksHere => 'No books here';

  @override
  String get home_books => 'Books';

  @override
  String get home_notStarted => 'Not started';

  @override
  String get home_finished => 'Finished ✓';

  @override
  String home_percentReadSentence(int percent, int pos, int total) {
    return '$percent% read • sentence $pos / $total';
  }

  @override
  String get home_open => 'Open';

  @override
  String get home_rename => 'Rename';

  @override
  String get home_select => 'Select';

  @override
  String get home_create => 'Create';

  @override
  String get home_noBooks => 'No books';

  @override
  String get home_addPrompt => 'Tap + to add a PDF or EPUB';

  @override
  String get reader_define => 'Define';

  @override
  String get reader_translate => 'Translate';

  @override
  String get reader_highlight => 'Highlight';

  @override
  String get reader_definitionsLanguage => 'Definitions language';

  @override
  String get reader_liveTranslationTitle => 'Live translation';

  @override
  String get reader_enabled => 'Enabled';

  @override
  String get reader_translationBubbleHint => 'Translation bubble while reading';

  @override
  String get reader_readingSpeed => 'Reading speed';

  @override
  String get reader_slower => 'Slower';

  @override
  String get reader_faster => 'Faster';

  @override
  String get reader_chooseVoice => 'Choose a voice';

  @override
  String get reader_highQualityNoWordHighlight =>
      'High quality — no word-by-word highlighting';

  @override
  String get reader_fontCondensed => 'Condensed';

  @override
  String get reader_fontCursive => 'Cursive';

  @override
  String get reader_background => 'BACKGROUND';

  @override
  String get reader_textSizeSection => 'TEXT SIZE';

  @override
  String get reader_fontSection => 'FONT';

  @override
  String get reader_renameFileTitle => 'Rename file';

  @override
  String get reader_documentNameHint => 'Document name';

  @override
  String get reader_searchHint => 'Search in the document…';

  @override
  String reader_resultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String reader_chapterSentence(int chapter, int sentence) {
    return 'Chapter $chapter · Sentence $sentence';
  }

  @override
  String get reader_tableOfContents => 'Table of contents';

  @override
  String reader_wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String get reader_options => 'Options';

  @override
  String get reader_annotationsOfThisBook => 'Annotations for this book';

  @override
  String get reader_search => 'Search';

  @override
  String get reader_hideReader => 'Hide reader';

  @override
  String get reader_showReader => 'Show reader';

  @override
  String get reader_disableAutoScroll => 'Disable auto-scroll';

  @override
  String get reader_enableAutoScroll => 'Enable auto-scroll';

  @override
  String get reader_showControls => 'Show controls';

  @override
  String get reader_previousSentence => 'Previous sentence';

  @override
  String get reader_nextSentence => 'Next sentence';

  @override
  String get reader_readTranslationAloud => 'Read the translation aloud';

  @override
  String get reader_readTranslationAloudHint =>
      'The voice reads the translation instead of the book\'s text';

  @override
  String get reader_translationVoice => 'Translation voice';

  @override
  String get reader_noVoiceForLanguage =>
      'No voice installed for this language';

  @override
  String get profileScreen_boostSection => 'Computer acceleration';

  @override
  String get profileScreen_boostOff => 'Off — everything runs on the phone';

  @override
  String get profileScreen_boostSearching => 'Looking for the computer…';

  @override
  String profileScreen_boostConnected(String host) {
    return 'Connected to $host — voices and AI on the computer';
  }

  @override
  String get profileScreen_boostUnreachable =>
      'Computer not found — the phone takes over';

  @override
  String get profileScreen_boostEnable =>
      'Use the computer when it\'s reachable';

  @override
  String get profileScreen_boostHosts => 'Computer addresses';

  @override
  String get profileScreen_boostHostsHint =>
      'Wi-Fi and Tailscale, comma-separated';

  @override
  String get profileScreen_boostCode => 'Pairing code (6 digits)';

  @override
  String get profileScreen_boostTest => 'Test';

  @override
  String get reader_pageColor => 'PAGE COLOR';

  @override
  String get reader_pageAuto => 'Auto';

  @override
  String get reader_pageWhite => 'White';

  @override
  String get reader_pagePaper => 'Paper';

  @override
  String get reader_pageGreen => 'Green';

  @override
  String get reader_pageGray => 'Gray';

  @override
  String get reader_pageNight => 'Night';

  @override
  String get reader_warmth => 'Warm filter';

  @override
  String get reader_dim => 'Dim';

  @override
  String get reader_voicePitch => 'Voice tone';

  @override
  String get reader_pitchDeeper => 'Deeper';

  @override
  String get reader_pitchLighter => 'Lighter';

  @override
  String get reader_pitchNormal => 'Normal';

  @override
  String get reader_bookMode => 'Book mode (pages)';

  @override
  String get reader_scrollMode => 'Scroll mode';

  @override
  String get reader_pageTurn => 'Page animation';

  @override
  String get reader_pageTurnCurl => 'Page turn';

  @override
  String get reader_pageTurnSlide => 'Slide';

  @override
  String reader_pageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get reader_pause => 'Pause';

  @override
  String get reader_play => 'Play';

  @override
  String audioHandler_sentenceProgress(int current, int total) {
    return 'Sentence $current / $total';
  }

  @override
  String get voiceDownloads_title => 'AI voices';

  @override
  String get voiceDownloads_manage => 'AI voices';

  @override
  String get voiceDownloads_section => 'AI voices';

  @override
  String voiceDownloads_tileSubtitle(int installed, int total) {
    return '$installed / $total models installed on this phone';
  }

  @override
  String get voiceDownloads_intro =>
      'AI voices run offline, right on your phone. Download the ones you want — Wi-Fi is recommended, and keep the app open while they install.';

  @override
  String voiceDownloads_installAll(int size) {
    return 'Download all (~$size MB)';
  }

  @override
  String get voiceDownloads_installed => 'Installed';

  @override
  String get voiceDownloads_download => 'Download';

  @override
  String voiceDownloads_downloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get voiceDownloads_extracting => 'Installing… (a few minutes)';

  @override
  String get voiceDownloads_failed => 'Download failed — tap to retry';

  @override
  String get voiceDownloads_delete => 'Delete';

  @override
  String voiceDownloads_deleteConfirm(String name) {
    return 'Delete $name from this phone? You can download it again later.';
  }

  @override
  String get voiceDownloads_cancel => 'Cancel';

  @override
  String voiceDownloads_sizeMb(int size) {
    return '~$size MB';
  }

  @override
  String get voice_pcRequiredTitle => 'Computer-only voice';

  @override
  String get voice_pcRequiredBody =>
      'This voice (Qwen3-TTS) is generated by your computer through TalkTome Boost, which isn\'t responding right now. Turn the computer on, check Profile → TalkTome Boost, or pick a voice marked \"téléphone\" (phone).';
}
