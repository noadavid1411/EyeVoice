import 'package:eyevoice/core/models/screen_zone.dart';
import 'package:eyevoice/domain/expert/letter_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LetterGroup', () {
    test('couvre tout l\'alphabet A-Z sans doublon', () {
      final allLetters = LetterGroup.values.expand((g) => g.letters).toList();

      expect(allLetters.length, 26);
      expect(allLetters.toSet().length, 26, reason: 'aucune lettre en double');

      const alphabet = [
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
        'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
      ];
      expect(allLetters.toSet(), alphabet.toSet());
    });

    test('respecte la table de zones de la section 8.3', () {
      expect(LetterGroup.aToF.zone, ScreenZone.topLeft);
      expect(LetterGroup.gToL.zone, ScreenZone.topRight);
      expect(LetterGroup.mToR.zone, ScreenZone.bottomLeft);
      expect(LetterGroup.sToZ.zone, ScreenZone.bottomRight);
    });

    test('groupes attendus (A-F, G-L, M-R, S-Z)', () {
      expect(LetterGroup.aToF.letters, ['A', 'B', 'C', 'D', 'E', 'F']);
      expect(LetterGroup.gToL.letters, ['G', 'H', 'I', 'J', 'K', 'L']);
      expect(LetterGroup.mToR.letters, ['M', 'N', 'O', 'P', 'Q', 'R']);
      expect(
        LetterGroup.sToZ.letters,
        ['S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'],
      );
    });

    group('lettersPaged', () {
      test('pagine A-F (6 lettres) en pages de 4 max par défaut', () {
        final pages = LetterGroup.aToF.lettersPaged();

        expect(pages, [
          ['A', 'B', 'C', 'D'],
          ['E', 'F'],
        ]);
        for (final page in pages) {
          expect(page.length, lessThanOrEqualTo(4));
        }
      });

      test('pagine S-Z (8 lettres) en deux pages égales par défaut', () {
        final pages = LetterGroup.sToZ.lettersPaged();

        expect(pages, [
          ['S', 'T', 'U', 'V'],
          ['W', 'X', 'Y', 'Z'],
        ]);
      });

      test('accepte une pageSize personnalisée', () {
        final pages = LetterGroup.aToF.lettersPaged(pageSize: 3);

        expect(pages, [
          ['A', 'B', 'C'],
          ['D', 'E', 'F'],
        ]);
      });

      test('lève une erreur pour une pageSize non positive', () {
        expect(
          () => LetterGroup.aToF.lettersPaged(pageSize: 0),
          throwsArgumentError,
        );
        expect(
          () => LetterGroup.aToF.lettersPaged(pageSize: -1),
          throwsArgumentError,
        );
      });

      test('toutes les pages de tous les groupes respectent la limite de 4 choix', () {
        for (final group in LetterGroup.values) {
          for (final page in group.lettersPaged()) {
            expect(page.length, lessThanOrEqualTo(4));
            expect(page, isNotEmpty);
          }
        }
      });
    });

    group('groupOf', () {
      test('retrouve le bon groupe pour une lettre donnée', () {
        expect(LetterGroup.groupOf('A'), LetterGroup.aToF);
        expect(LetterGroup.groupOf('f'), LetterGroup.aToF);
        expect(LetterGroup.groupOf('G'), LetterGroup.gToL);
        expect(LetterGroup.groupOf('r'), LetterGroup.mToR);
        expect(LetterGroup.groupOf('Z'), LetterGroup.sToZ);
      });

      test('retourne null pour une entrée invalide', () {
        expect(LetterGroup.groupOf(''), isNull);
        expect(LetterGroup.groupOf('AB'), isNull);
        expect(LetterGroup.groupOf('1'), isNull);
        expect(LetterGroup.groupOf(' '), isNull);
      });
    });
  });
}
