import 'package:flutter_test/flutter_test.dart';
import 'package:talktome/services/sentence_mood.dart';

/// Phrases étiquetées à la main (français, anglais, portugais), avec des
/// pièges : négations, faux amis, points d'exclamation de colère.
const _labelled = <String, Mood>{
  // ── Français ──
  'Elle pleurait en silence dans sa chambre.': Mood.sad,
  'Il ne pleurait pas, il serrait seulement les dents.': Mood.neutral,
  '« Va-t’en ! » hurla-t-il, furieux.': Mood.angry,
  'Elle éclata de rire en voyant le chien.': Mood.happy,
  'Il tremblait de peur derrière la porte.': Mood.scared,
  '« Viens, » murmura-t-elle doucement.': Mood.calm,
  'Le train partit à midi.': Mood.neutral,
  '« On a gagné ! »': Mood.excited,
  'Sans sourire, il referma le livre.': Mood.neutral,
  'Les larmes coulaient sur ses joues.': Mood.sad,
  'Elle était terrifiée par le silence de la maison.': Mood.scared,
  'Il sourit et lui tendit la main.': Mood.happy,
  '« Je te déteste ! » cria-t-elle avec rage.': Mood.angry,
  'La pièce était grande et lumineuse.': Mood.neutral,
  'Paisible, le lac reflétait les montagnes.': Mood.calm,
  // ── English ──
  'She cried until she fell asleep.': Mood.sad,
  "He didn't laugh at the joke.": Mood.neutral,
  '"Get out!" he shouted angrily.': Mood.angry,
  'They laughed and danced all night.': Mood.happy,
  'He was terrified of the dark.': Mood.scared,
  'She whispered his name softly.': Mood.calm,
  'The meeting started at nine.': Mood.neutral,
  '"We did it!"': Mood.excited,
  'Nobody smiled when he walked in.': Mood.neutral,
  'Tears ran down her face as she read the letter.': Mood.sad,
  'Panic gripped him when the lights went out.': Mood.scared,
  'She smiled happily at the children.': Mood.happy,
  '"How dare you!" she yelled.': Mood.angry,
  'He finished his chores before dinner.': Mood.neutral,
  'The sea was calm that morning.': Mood.calm,
  // ── Português ──
  'Ela chorou a noite inteira.': Mood.sad,
  'Ele não chorou no funeral.': Mood.neutral,
  '"Sai daqui!" gritou ele com raiva.': Mood.angry,
  'As crianças riram muito com o palhaço.': Mood.happy,
  'Ele tremia de medo no escuro.': Mood.scared,
  'Ela sussurrou baixinho o nome dele.': Mood.calm,
  'O comboio partiu ao meio-dia.': Mood.neutral,
  '"Ganhámos!"': Mood.excited,
  'Ela sorriu e abraçou a mãe.': Mood.happy,
  'As lágrimas caíam-lhe pelo rosto.': Mood.sad,
  'Estava assustada com o barulho lá fora.': Mood.scared,
  'Nunca sorria quando falava do pai.': Mood.neutral,
  'O quarto era pequeno e escuro.': Mood.neutral,
  'Falou suavemente para não acordar o bebé.': Mood.calm,
  '"Que raiva!" disse ela.': Mood.angry,
};

void main() {
  test('rules recognise most hand-labelled sentences (fr / en / pt)', () {
    final wrong = <String>[];
    _labelled.forEach((sentence, expected) {
      final got = MoodRules.classify(sentence);
      if (got != expected) wrong.add('$sentence → ${got.name} (attendu ${expected.name})');
    });
    final accuracy = 1 - wrong.length / _labelled.length;
    // ignore: avoid_print
    print('Règles : ${(accuracy * 100).round()} % justes sur ${_labelled.length}'
        '${wrong.isEmpty ? '' : '\n  ${wrong.join('\n  ')}'}');
    expect(accuracy, greaterThanOrEqualTo(0.9));
  });

  test('negation cancels the emotion word', () {
    expect(MoodRules.classify("He didn't cry."), Mood.neutral);
    expect(MoodRules.classify('Elle ne riait jamais.'), Mood.neutral);
    expect(MoodRules.classify('Não teve medo nenhum.'), Mood.neutral);
    // Une autre émotion, elle, reste détectée.
    expect(MoodRules.classify("He didn't smile; he wept."), Mood.sad);
  });

  test('strength: several cues or shouting make it strong', () {
    expect(MoodRules.read('She cried.').strength, 0.6);
    expect(MoodRules.read('She cried and sobbed.').strength, 1.0);
    expect(MoodRules.read('Stop it!!').strength, 1.0);
    expect(MoodRules.read('I said STOP right there.').strength, 1.0);
    expect(MoodRules.read('Nice!').strength, 0.6);
    expect(MoodRules.read('The train left.'), const MoodReading(Mood.neutral, 0));
  });

  test('AI answers with strength, and older cached values stay readable', () {
    expect(parseMoodReadings('1: sad 2\n2: happy 1\n3: calm\n4: banana 2', 5), [
      const MoodReading(Mood.sad, 1.0),
      const MoodReading(Mood.happy, 0.6),
      const MoodReading(Mood.calm, 0.8),
      null,
      null,
    ]);
    expect(decodeMoodReading('sad'), const MoodReading(Mood.sad, 0.8));
    expect(decodeMoodReading(encodeMoodReading(const MoodReading(Mood.angry, 1.0))),
        const MoodReading(Mood.angry, 1.0));
    expect(decodeMoodReading('neutral:2'), const MoodReading(Mood.neutral, 0));
  });

  test('dialogue is told apart from narration', () {
    expect(isDialogue('"Where are you going?" she asked.'), isTrue);
    expect(isDialogue('— Va-t’en ! hurla-t-il.'), isTrue);
    expect(isDialogue('« Viens, » dit-elle.'), isTrue);
    expect(isDialogue('The rain kept falling.'), isFalse);
  });

  test('planner: narration steadier, isolated outliers softened', () {
    const sad = MoodReading(Mood.sad, 1.0);
    const neutral = MoodReading(Mood.neutral, 0);
    expect(MoodPlanner.intensity(here: sad, dialogue: true), 1.0);
    expect(MoodPlanner.intensity(here: sad, dialogue: false), 0.5);
    // Seule phrase triste entre deux neutres : atténuée.
    expect(MoodPlanner.intensity(here: sad, previous: neutral, next: neutral, dialogue: true),
        closeTo(0.6, 1e-9));
    // Dans une scène triste : pleine intensité.
    expect(MoodPlanner.intensity(here: sad, previous: sad, next: neutral, dialogue: true), 1.0);
    expect(MoodPlanner.intensity(here: neutral, dialogue: true), 0);
    // Réglage de l'utilisateur.
    expect(MoodPlanner.intensity(here: sad, dialogue: true, userIntensity: 0.5), 0.5);
  });

  test('planner: profiles blend from neutral and speed changes gradually', () {
    final full = MoodPlanner.blend(Mood.sad, 1);
    expect(full.speedFactor, Mood.sad.profile.speedFactor);
    final none = MoodPlanner.blend(Mood.sad, 0);
    expect(none.speedFactor, 1.0);
    expect(none.volume, 1.0);
    expect(none.pauseAfterMs, 0);
    final half = MoodPlanner.blend(Mood.sad, 0.5);
    expect(half.speedFactor, closeTo(0.95, 1e-9));
    expect(MoodPlanner.ramp(0.90, 1.0), closeTo(0.96, 1e-9));
    expect(MoodPlanner.ramp(1.02, 1.0), 1.02);
    expect(MoodPlanner.ramp(1.08, null), 1.08);
  });

  test('emotional voices keep the volume and only a little rhythm', () {
    final p = MoodPlanner.forEmotionalVoice(Mood.sad.profile);
    expect(p.volume, 1.0);
    expect(p.speedFactor, closeTo(0.96, 1e-9));
    expect(p.pauseAfterMs, Mood.sad.profile.pauseAfterMs);
  });
}
