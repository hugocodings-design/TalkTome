// Test de lecture sur un vrai Android (émulateur sur GitHub) : lance la vraie
// app, installe les voix du téléphone, ouvre un livre anglais et le fait lire
// à voix haute avec chaque moteur. Échoue si la lecture n'avance pas, si des
// phrases sont sautées, ou si l'app plante (le test s'arrête alors net).
//
// Lancé par .github/workflows/android-reading-test.yml ; pas en local.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:talktome/main.dart' as app;
import 'package:talktome/models/chapter.dart';
import 'package:talktome/models/ebook.dart';
import 'package:talktome/screens/reader_screen.dart';
import 'package:talktome/services/sherpa_tts_service.dart';
import 'package:talktome/services/voice_model_downloader.dart';

/// Passage anglais typique : dialogues, guillemets, chiffres, abréviations,
/// phrases d'un mot (cas qui faisaient dérailler Pocket).
const _passage = '''
Chapter One.

"Where are you going?" she asked, pulling her coat tighter against the wind. Mr. Thompson didn't answer; he simply pointed toward the old lighthouse — the one nobody had visited since 1987.

"Yes."

"What?"

The rain kept falling, steady and cold, as if the sky itself had decided to stay for the night… It was 7:45 p.m. when they finally reached the door, and the lock (rusted, of course) wouldn't move.

"Well," he said at last, "I suppose we'll have to break it." She laughed — a short, nervous laugh — and stepped back. Nothing happened. Then, slowly, the door creaked open by itself, revealing a narrow staircase that spiraled up into darkness. They looked at each other for a long moment before either of them dared to speak again. Somewhere above, a floorboard groaned. "Did you hear that?" she whispered. He nodded, and together they began to climb.

The stairs were steeper than they looked. At the top, a small round room opened before them, its windows black with rain. A lamp stood on a table in the middle, still warm, as if someone had left only a minute ago. "Hello?" he called. No one answered. On the table lay a letter, folded twice and sealed with red wax. She picked it up, turned it over, and read the name written on the back in careful, old-fashioned handwriting. It was her own.
''';

/// Voix testées : une par moteur du téléphone.
const _voices = [
  'sherpa-kokoro-af_heart',
  'sherpa-supertonic-en-m1',
  'sherpa-pocket-alba',
];

/// Lecture exigée par voix : phrases réellement jouées, sans saut.
const _sentencesToPlay = 20;
const _perVoiceTimeout = Duration(minutes: 10);

void log(String s) => debugPrint('[READING-TEST] $s');

Future<void> _wait(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await tester.pump();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reads an English book aloud on every phone engine', (tester) async {
    // L'app remplace l'affichage d'erreur de Flutter au démarrage ; le cadre
    // de test exige qu'on le remette en place à la fin.
    final originalErrorBuilder = ErrorWidget.builder;
    app.main();
    // Démarrage : Hive ouvert et lecteur audio prêt.
    for (var i = 0; i < 240 && (app.audioHandler == null || !Hive.isBoxOpen('ebooks')); i++) {
      await _wait(tester, const Duration(milliseconds: 500));
    }
    expect(app.audioHandler, isNotNull, reason: 'lecteur audio non initialisé');
    log('app démarrée');

    // Voix du téléphone : téléchargées comme depuis l'écran « Voix IA ».
    for (final id in {for (final v in _voices) SherpaTtsService.voiceByName(v)!.modelId}) {
      final sw = Stopwatch()..start();
      await tester.runAsync(() => VoiceModelDownloader.instance.install(id));
      final ok = await tester.runAsync(() => SherpaTtsService.instance.isModelInstalled(id));
      log('modèle $id installé=$ok en ${sw.elapsed.inSeconds} s '
          '(${VoiceModelDownloader.instance.states.value[id]?.error ?? ''})');
      expect(ok, isTrue, reason: 'installation du modèle $id');
    }

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    final handler = app.audioHandler!;

    for (final voice in _voices) {
      final book = Ebook(
        id: 'reading-test-$voice',
        title: 'Reading test ($voice)',
        chapters: [
          Chapter(
            id: 'reading-test-ch1',
            title: 'Chapter One',
            textContent: _passage,
            wordCount: _passage.split(RegExp(r'\s+')).length,
            pageNumber: 1,
          ),
        ],
        uploadedAt: DateTime.now(),
        fileFormat: 'epub',
        selectedVoiceName: voice,
      );
      await Hive.box<Ebook>('ebooks').put(book.id, book);

      unawaited(navigator.push(MaterialPageRoute(builder: (_) => ReaderScreen(ebook: book))));
      await _wait(tester, const Duration(seconds: 4));

      // Phrases réellement jouées (texte prononcé) et sauts éventuels.
      final played = <int>{};
      void onSpoken() {
        if (handler.spokenTextNotifier.value != null) {
          played.add(handler.currentIndexNotifier.value);
        }
      }

      handler.spokenTextNotifier.addListener(onSpoken);
      log('$voice : lecture');
      await tester.runAsync(() => handler.play());

      final sw = Stopwatch()..start();
      while (played.length < _sentencesToPlay && sw.elapsed < _perVoiceTimeout) {
        await _wait(tester, const Duration(seconds: 1));
      }
      final reached = handler.currentIndexNotifier.value;
      handler.spokenTextNotifier.removeListener(onSpoken);
      await tester.runAsync(() => handler.pause());
      log('$voice : ${played.length} phrases jouées, position $reached, '
          '${sw.elapsed.inSeconds} s');

      expect(played.length, greaterThanOrEqualTo(_sentencesToPlay),
          reason: '$voice : la lecture n\'avance pas');
      final skipped = [for (var i = 0; i <= reached; i++) if (!played.contains(i)) i];
      expect(skipped, isEmpty, reason: '$voice : phrases sautées $skipped');

      navigator.pop();
      await _wait(tester, const Duration(seconds: 2));
    }
    log('TOUT EST OK');
    // Vérifié par le cadre de test avant tout nettoyage : à remettre ici.
    ErrorWidget.builder = originalErrorBuilder;
  }, timeout: const Timeout(Duration(minutes: 45)));
}
