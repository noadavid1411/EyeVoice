import 'package:eyevoice/domain/expert/word_predictor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WordPredictor', () {
    test('suggère un préfixe vide sans résultat', () {
      const predictor = WordPredictor();

      expect(predictor.suggest(''), isEmpty);
    });

    test('exemple de la section 8.5 : "do" -> douleur, dormir, docteur', () {
      const predictor = WordPredictor();

      expect(predictor.suggest('do'), ['douleur', 'dormir', 'docteur']);
    });

    test('exemple de la section 8.5 : "inf" -> infirmière', () {
      const predictor = WordPredictor();

      expect(predictor.suggest('inf'), ['infirmière']);
    });

    test('insensible à la casse', () {
      const predictor = WordPredictor();

      expect(predictor.suggest('DO'), ['douleur', 'dormir', 'docteur']);
      expect(predictor.suggest('Do'), ['douleur', 'dormir', 'docteur']);
    });

    test('limite le nombre de suggestions via maxSuggestions', () {
      const predictor = WordPredictor();

      expect(predictor.suggest('do', maxSuggestions: 2), ['douleur', 'dormir']);
      expect(predictor.suggest('do', maxSuggestions: 1), ['douleur']);
    });

    test('retourne une liste vide sans correspondance', () {
      const predictor = WordPredictor();

      expect(predictor.suggest('xyz123'), isEmpty);
    });

    test('accepte un vocabulaire personnalisé', () {
      const predictor = WordPredictor(
        vocabulary: ['chat', 'chien', 'chaise'],
      );

      expect(predictor.suggest('ch'), ['chat', 'chien', 'chaise']);
      expect(predictor.suggest('do'), isEmpty);
    });

    test('le vocabulaire par défaut contient au moins une trentaine de mots', () {
      expect(defaultPatientVocabulary.length, greaterThanOrEqualTo(30));
      expect(defaultPatientVocabulary.toSet().length, defaultPatientVocabulary.length,
          reason: 'pas de doublon dans le vocabulaire par défaut');
    });
  });
}
