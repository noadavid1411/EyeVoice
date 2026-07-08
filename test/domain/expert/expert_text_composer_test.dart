import 'package:eyevoice/domain/expert/expert_text_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpertTextComposer', () {
    test('texte initial vide', () {
      expect(ExpertTextComposer().text, '');
    });

    test('addLetter ajoute des lettres en minuscule', () {
      final composer = ExpertTextComposer()
        ..addLetter('D')
        ..addLetter('o')
        ..addLetter('C');

      expect(composer.text, 'doc');
    });

    test('addLetter rejette une entrée invalide', () {
      final composer = ExpertTextComposer();

      expect(() => composer.addLetter(''), throwsArgumentError);
      expect(() => composer.addLetter('AB'), throwsArgumentError);
      expect(() => composer.addLetter('1'), throwsArgumentError);
      expect(() => composer.addLetter(' '), throwsArgumentError);
    });

    test('deleteLastLetter retire le dernier caractère', () {
      final composer = ExpertTextComposer()
        ..addLetter('A')
        ..addLetter('B')
        ..deleteLastLetter();

      expect(composer.text, 'a');
    });

    test('deleteLastLetter ne fait rien sur un texte vide', () {
      final composer = ExpertTextComposer();

      expect(() => composer.deleteLastLetter(), returnsNormally);
      expect(composer.text, '');
    });

    test('addSpace ajoute un espace après un mot', () {
      final composer = ExpertTextComposer()
        ..addLetter('A')
        ..addSpace();

      expect(composer.text, 'a ');
    });

    test('addSpace ignore les espaces multiples et en début de texte', () {
      final composer = ExpertTextComposer();
      composer.addSpace();
      expect(composer.text, '', reason: 'pas d\'espace en début de texte');

      composer.addLetter('A');
      composer.addSpace();
      composer.addSpace();
      expect(composer.text, 'a ', reason: 'pas de double espace');
    });

    test('currentWord retourne le mot après le dernier espace', () {
      final composer = ExpertTextComposer();
      expect(composer.currentWord, '');

      composer.addLetter('D');
      composer.addLetter('O');
      expect(composer.currentWord, 'do');

      composer.addSpace();
      expect(composer.currentWord, '');

      composer.addLetter('A');
      expect(composer.currentWord, 'a');
    });

    group('applySuggestion', () {
      test('complète le premier mot et ajoute un espace', () {
        final composer = ExpertTextComposer()
          ..addLetter('D')
          ..addLetter('O')
          ..applySuggestion('douleur');

        expect(composer.text, 'douleur ');
        expect(composer.currentWord, '');
      });

      test('remplace uniquement le mot en cours après un mot déjà validé', () {
        final composer = ExpertTextComposer()
          ..addLetter('J')
          ..addLetter('A')
          ..addLetter('I')
          ..addSpace()
          ..addLetter('M')
          ..applySuggestion('mal');

        expect(composer.text, 'jai mal ');
      });

      test('ignore une suggestion vide', () {
        final composer = ExpertTextComposer()..addLetter('A');

        composer.applySuggestion('');

        expect(composer.text, 'a');
      });
    });

    test('reset vide le texte composé', () {
      final composer = ExpertTextComposer()
        ..addLetter('A')
        ..addSpace()
        ..addLetter('B')
        ..reset();

      expect(composer.text, '');
      expect(composer.currentWord, '');
    });
  });
}
