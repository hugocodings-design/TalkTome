import 'package:flutter_test/flutter_test.dart';
import 'package:talktome/services/speech_text_normalizer.dart';

const _dictionary = {
  'wait', 'good', 'god', 'no', 'so', 'because', 'cool', 'col', 'hello', 'what',
  'the', 'is', 'and', 'book', 'please', 'bien', 'oui', 'quoi', 'homme', 'hug', 'huge',
  'cat', 'car', 'cut', 'reading', 'she', 'said',
};

Future<Set<String>> _known(Set<String> words, String lang) async =>
    words.where(_dictionary.contains).toSet();

Future<Set<String>> _noDictionary(Set<String> words, String lang) async => {};

int _wordCount(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

void main() {
  final n = SpeechTextNormalizer(_known);

  test('stretched words become the dictionary word', () async {
    expect(await n.normalize('waaaiiit', 'en'), 'wait');
    expect(await n.normalize('goooood', 'en'), 'good');
    expect(await n.normalize('coool', 'en'), 'cool');
    expect(await n.normalize('noooo', 'en'), 'no');
    expect(await n.normalize('ouiiii', 'fr'), 'oui');
  });

  test('case is kept', () async {
    expect(await n.normalize('Noooo!', 'en'), 'No!');
    expect(await n.normalize('WAAAIT', 'en'), 'WAIT');
  });

  test('a typo with exactly one possible fix is corrected', () async {
    expect(await n.normalize('It was becuase of you.', 'en'), 'It was because of you.');
  });

  test('ambiguous typos and names are left alone', () async {
    // « hugr » could be « hug » or « huge » : no guessing.
    expect(await n.normalize('the hugr', 'en'), 'the hugr');
    expect(await n.normalize('Hugo said', 'en'), 'Hugo said');
  });

  test('parts of compound words are never touched', () async {
    expect(await n.normalize("l'homme et aujourd'hui", 'fr'), "l'homme et aujourd'hui");
    expect(await n.normalize('peut-êtrr', 'fr'), 'peut-êtrr');
  });

  test('punctuation and spacing are preserved, word count never changes', () async {
    const s = '  “Waaaiiit…” she said,   becuase   it was sooo good!  ';
    final out = await n.normalize(s, 'en');
    expect(out, '  “Wait…” she said,   because   it was so good!  ');
    expect(_wordCount(out), _wordCount(s));
  });

  test('without a dictionary, stretched letters are collapsed and nothing else changes', () async {
    final bare = SpeechTextNormalizer(_noDictionary);
    expect(await bare.normalize('noooo becuase', 'en'), 'no becuase');
  });

  test('stretch candidates prefer doubles first', () {
    expect(SpeechTextNormalizer.stretchCandidates('waaaiiit'),
        ['waaiit', 'waiit', 'waait', 'wait']);
  });
}
