import 'package:flutter_test/flutter_test.dart';
import 'package:talktome/services/speech_expander.dart';

String say(String text, String lang) => SpeechExpander.expand(text, lang).text;

void main() {
  test('English: abbreviations, numerals, numbers, symbols', () {
    expect(say('Dr. Smith met Mr. Jones and Mrs. Brown.', 'en-US'),
        'Doctor Smith met Mister Jones and Missus Brown.');
    expect(say('Einstein wrote E = mc².', 'en-US'), 'Einstein wrote E equals m c squared.');
    expect(say('Einstein wrote E=mc².', 'en-US'), 'Einstein wrote E equals m c squared.');
    expect(say('It costs \$5.99, about 20% more.', 'en-US'),
        'It costs five dollars and ninety-nine cents, about twenty percent more.');
    expect(say('Meet me at 7:45 p.m. on May 3rd.', 'en-US'),
        'Meet me at seven forty-five P M on May third.');
    expect(say('Louis XIV ruled France.', 'en-US'), 'Louis the fourteenth ruled France.');
    expect(say('Chapter IV begins in 1987.', 'en-US'), 'Chapter four begins in nineteen eighty-seven.');
    expect(say('It was 25°C outside.', 'en-US'), 'It was twenty-five degrees Celsius outside.');
    expect(say('3 + 4 = 7, and 10 − 2 = 8.', 'en-US'),
        'three plus four equals seven, and ten minus two equals eight.');
    expect(say('See St. Paul\'s, e.g. on Fig. 2.', 'en-US'),
        'See Saint Paul\'s, for example on Figure two.');
    expect(say('Visit www.example.com today.', 'en-US'), 'Visit double-u double-u double-u dot example dot com today.');
    expect(say('Write to anna@mail.com now.', 'en-US'), 'Write to anna at mail dot com now.');
    expect(say('I went home.', 'en-US'), 'I went home.');
    expect(say('World War II ended.', 'en-US'), 'World War two ended.');
    expect(say('He lived in Washington DC.', 'en-US'), 'He lived in Washington DC.');
  });

  test('French', () {
    expect(say('Le Dr Martin et M. Dupont sont arrivés.', 'fr-FR'),
        'Le Docteur Martin et Monsieur Dupont sont arrivés.');
    expect(say('Einstein a écrit E = mc².', 'fr-FR'), 'Einstein a écrit e égale èm cé au carré.');
    expect(say('Ça coûte 5,99 €, environ 20 % de plus.', 'fr-FR'),
        'Ça coûte cinq euros quatre-vingt-dix-neuf, environ vingt pour cent de plus.');
    expect(say('Rendez-vous à 19h45 le 1er mai.', 'fr-FR'),
        'Rendez-vous à dix-neuf heures quarante-cinq le premier mai.');
    expect(say('Louis XIV régnait sur la France.', 'fr-FR'), 'Louis quatorze régnait sur la France.');
    expect(say('Il faisait 25 °C dehors.', 'fr-FR'), 'Il faisait vingt-cinq degrés Celsius dehors.');
    expect(say('Le XIXe siècle commence.', 'fr-FR'), 'Le dix-neuvième siècle commence.');
    expect(say('Mme Durand et Mlle Petit, etc.', 'fr-FR'), 'Madame Durand et Mademoiselle Petit, etcétéra.');
    expect(say('Il y a 1 000 000 d’habitants.', 'fr-FR'), 'Il y a un million d’habitants.');
    expect(say('Le chat et De Gaulle.', 'fr-FR'), 'Le chat et De Gaulle.');
    expect(say('François Ier arriva.', 'fr-FR'), 'François premier arriva.');
  });

  test('Portuguese (Brazil and Portugal)', () {
    expect(say('O Dr. Silva e a Sra. Costa chegaram.', 'pt-BR'),
        'O Doutor Silva e a Senhora Costa chegaram.');
    expect(say('x + y = 3', 'pt-BR'), 'xis mais ípsilon igual a três');
    expect(say('Il a dit à Paul.', 'fr-FR'), 'Il a dit à Paul.');
    expect(say('Einstein escreveu E = mc².', 'pt-BR'), 'Einstein escreveu é igual a eme cê ao quadrado.');
    expect(say('Custa 5,99 €, cerca de 20% mais.', 'pt-PT'),
        'Custa cinco euros e noventa e nove cêntimos, cerca de vinte por cento mais.');
    expect(say('Encontro às 19h45 no dia 1º de maio.', 'pt-PT'),
        'Encontro às dezanove horas e quarenta e cinco no dia primeiro de maio.');
    expect(say('D. Pedro II governou o Brasil.', 'pt-BR'), 'Dom Pedro segundo governou o Brasil.');
    expect(say('Custa R\$ 10,50.', 'pt-BR'), 'Custa dez reais e cinquenta centavos.');
  });

  test('pauses: dashes, mid-sentence ellipsis, parentheses', () {
    expect(say('She paused — then smiled.', 'en-US'), 'She paused [[pause:350]] then smiled.');
    expect(say('Well...yes, I think.', 'en-US'), 'Well [[pause:500]] yes, I think.');
    expect(say('He waited… and waited.', 'en-US'), 'He waited [[pause:500]] and waited.');
    expect(say('The key (old and rusty) fit.', 'en-US'),
        'The key [[pause:180]] old and rusty [[pause:180]] fit.');
    expect(say('— Va-t’en ! hurla-t-il.', 'fr-FR'), 'Va-t’en ! hurla-t-il.');
  });

  test('end-of-sentence pauses follow punctuation', () {
    expect(SpeechExpander.trailingPauseMs('Well…'), 750);
    expect(SpeechExpander.trailingPauseMs('"Really?"'), 420);
    expect(SpeechExpander.trailingPauseMs('He left.'), 340);
    expect(SpeechExpander.trailingPauseMs('and then'), 140);
  });

  test('word map keeps highlighting on the book words', () {
    final s = SpeechExpander.expand('Einstein wrote E = mc².', 'en-US');
    // Einstein wrote E equals m c squared.
    expect(s.sourceWord, [0, 1, 2, 3, 4, 4, 4]);
    expect(s.mapStarts([0, 0.5, 1.0, 1.2, 1.5, 1.6, 1.8]), [0, 0.5, 1.0, 1.2, 1.5]);
    final t = SpeechExpander.expand('Il y a 1 000 habitants.', 'fr-FR');
    expect(t.originalWordCount, 6);
    // « 1 000 » → « mille » : un seul mot dit pour deux mots du livre.
    expect(t.mapStarts([0, 0.2, 0.3, 0.5, 0.8]), [0, 0.2, 0.3, 0.5, 0.5, 0.8]);
  });

  test('sentence splits after abbreviations are re-joined', () {
    expect(SpeechExpander.continuesAfter('Dr. Smith met Mr.', 'Jones and Mrs. Brown.'), isTrue);
    expect(SpeechExpander.continuesAfter('Mr.', 'Thompson didn’t answer.'), isTrue);
    expect(SpeechExpander.continuesAfter('Le Dr Martin et M.', 'Dupont sont arrivés.'), isTrue);
    expect(SpeechExpander.continuesAfter('See it, e.g.', 'the second one.'), isTrue);
    expect(SpeechExpander.continuesAfter('J.', 'K. Rowling wrote it.'), isTrue);
    expect(SpeechExpander.continuesAfter('We used plan A.', 'Then we left.'), isFalse);
    expect(SpeechExpander.continuesAfter('He left.', 'She stayed.'), isFalse);
    expect(SpeechExpander.continuesAfter('And so on, etc.', 'Next day came.'), isFalse);
  });
}
