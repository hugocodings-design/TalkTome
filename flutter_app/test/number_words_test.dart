import 'package:flutter_test/flutter_test.dart';
import 'package:talktome/services/number_words.dart';

void main() {
  test('English cardinals, years and ordinals', () {
    expect(NumberWords.cardinal(0, 'en'), 'zero');
    expect(NumberWords.cardinal(21, 'en'), 'twenty-one');
    expect(NumberWords.cardinal(105, 'en'), 'one hundred five');
    expect(NumberWords.cardinal(1999, 'en'), 'one thousand nine hundred ninety-nine');
    expect(NumberWords.cardinal(2500000, 'en'), 'two million five hundred thousand');
    expect(NumberWords.year(1987, 'en'), 'nineteen eighty-seven');
    expect(NumberWords.year(2005, 'en'), 'two thousand five');
    expect(NumberWords.year(1905, 'en'), 'nineteen oh five');
    expect(NumberWords.year(1900, 'en'), 'nineteen hundred');
    expect(NumberWords.year(2026, 'en'), 'twenty twenty-six');
    expect(NumberWords.ordinal(1, 'en'), 'first');
    expect(NumberWords.ordinal(3, 'en'), 'third');
    expect(NumberWords.ordinal(12, 'en'), 'twelfth');
    expect(NumberWords.ordinal(14, 'en'), 'fourteenth');
    expect(NumberWords.ordinal(20, 'en'), 'twentieth');
    expect(NumberWords.ordinal(21, 'en'), 'twenty-first');
  });

  test('French cardinals and ordinals', () {
    expect(NumberWords.cardinal(21, 'fr'), 'vingt et un');
    expect(NumberWords.cardinal(71, 'fr'), 'soixante et onze');
    expect(NumberWords.cardinal(77, 'fr'), 'soixante-dix-sept');
    expect(NumberWords.cardinal(80, 'fr'), 'quatre-vingts');
    expect(NumberWords.cardinal(81, 'fr'), 'quatre-vingt-un');
    expect(NumberWords.cardinal(99, 'fr'), 'quatre-vingt-dix-neuf');
    expect(NumberWords.cardinal(100, 'fr'), 'cent');
    expect(NumberWords.cardinal(200, 'fr'), 'deux cents');
    expect(NumberWords.cardinal(201, 'fr'), 'deux cent un');
    expect(NumberWords.cardinal(1000, 'fr'), 'mille');
    expect(NumberWords.cardinal(1987, 'fr'), 'mille neuf cent quatre-vingt-sept');
    expect(NumberWords.cardinal(2000, 'fr'), 'deux mille');
    expect(NumberWords.cardinal(200000, 'fr'), 'deux cent mille');
    expect(NumberWords.cardinal(2000000, 'fr'), 'deux millions');
    expect(NumberWords.cardinal(1, 'fr', feminine: true), 'une');
    expect(NumberWords.ordinal(1, 'fr'), 'premier');
    expect(NumberWords.ordinal(1, 'fr', feminine: true), 'première');
    expect(NumberWords.ordinal(2, 'fr'), 'deuxième');
    expect(NumberWords.ordinal(5, 'fr'), 'cinquième');
    expect(NumberWords.ordinal(9, 'fr'), 'neuvième');
    expect(NumberWords.ordinal(19, 'fr'), 'dix-neuvième');
    expect(NumberWords.ordinal(21, 'fr'), 'vingt et unième');
    expect(NumberWords.ordinal(80, 'fr'), 'quatre-vingtième');
  });

  test('Portuguese (Brazil and Portugal)', () {
    expect(NumberWords.cardinal(16, 'pt-BR'), 'dezesseis');
    expect(NumberWords.cardinal(16, 'pt-PT'), 'dezasseis');
    expect(NumberWords.cardinal(19, 'pt-PT'), 'dezanove');
    expect(NumberWords.cardinal(21, 'pt'), 'vinte e um');
    expect(NumberWords.cardinal(100, 'pt'), 'cem');
    expect(NumberWords.cardinal(101, 'pt'), 'cento e um');
    expect(NumberWords.cardinal(345, 'pt'), 'trezentos e quarenta e cinco');
    expect(NumberWords.cardinal(1001, 'pt'), 'mil e um');
    expect(NumberWords.cardinal(1100, 'pt'), 'mil e cem');
    expect(NumberWords.cardinal(1234, 'pt'), 'mil duzentos e trinta e quatro');
    expect(NumberWords.cardinal(2000000, 'pt'), 'dois milhões');
    expect(NumberWords.cardinal(2, 'pt', feminine: true), 'duas');
    expect(NumberWords.cardinal(200, 'pt', feminine: true), 'duzentas');
    expect(NumberWords.ordinal(2, 'pt'), 'segundo');
    expect(NumberWords.ordinal(21, 'pt'), 'vigésimo primeiro');
    expect(NumberWords.ordinal(1, 'pt', feminine: true), 'primeira');
  });

  test('decimals', () {
    expect(NumberWords.decimals('14', 'en'), 'one four');
    expect(NumberWords.decimals('14', 'fr'), 'quatorze');
    expect(NumberWords.decimals('05', 'fr'), 'zéro cinq');
    expect(NumberWords.decimals('5', 'pt'), 'cinco');
  });
}
