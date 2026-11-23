import 'package:flutter_test/flutter_test.dart';
import 'package:talktome/services/sentence_mood.dart';

void main() {
  test('emotion words decide the mood (fr / en / pt)', () {
    expect(MoodRules.classify('Elle pleurait en silence.'), Mood.sad);
    expect(MoodRules.classify('He was terrified of the dark.'), Mood.scared);
    expect(MoodRules.classify('— Va-t’en ! hurla-t-il.'), Mood.angry);
    expect(MoodRules.classify('Ela sorriu para ele.'), Mood.happy);
    expect(MoodRules.classify('She whispered his name.'), Mood.calm);
    expect(MoodRules.classify('Ele gritou com raiva.'), Mood.angry);
  });

  test('punctuation and shouting', () {
    expect(MoodRules.classify('We won!'), Mood.excited);
    expect(MoodRules.classify('Noooo, come back.'), Mood.excited);
    expect(MoodRules.classify('I said STOP right there.'), Mood.excited);
    expect(MoodRules.classify('Je ne sais pas…'), Mood.calm);
    expect(MoodRules.classify('The train left at noon.'), Mood.neutral);
  });

  test('no false positives on lookalike words', () {
    expect(MoodRules.classify('He finished his chores.'), Mood.neutral);
    expect(MoodRules.classify('The crystal was blue.'), Mood.neutral);
  });

  test('AI answers are parsed line by line, unknown labels give null', () {
    expect(parseMoodLines('1: sad\n2: EXCITED\n3. joyful\n4: banana', 5),
        [Mood.sad, Mood.excited, Mood.happy, null, null]);
  });

  test('profiles stay subtle and neutral changes nothing', () {
    expect(Mood.neutral.profile.speedFactor, 1.0);
    expect(Mood.neutral.profile.volume, 1.0);
    for (final m in Mood.values) {
      expect(m.profile.speedFactor, inInclusiveRange(0.85, 1.15));
      expect(m.profile.volume, inInclusiveRange(0.8, 1.0));
    }
  });
}
