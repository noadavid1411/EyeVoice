/// Vocabulaire patient par défaut pour la prédiction de mots du mode
/// expert (SPECIFICATIONS_FONCTIONNELLES.md section 8.5).
///
/// L'ordre est **significatif** : [WordPredictor.suggest] filtre en
/// préservant l'ordre de cette liste, qui reflète une pertinence/fréquence
/// plausible des besoins exprimés par un patient hospitalisé peu mobile
/// (douleur et besoins vitaux en tête). Cet ordre reprend en particulier
/// exactement l'exemple de la section 8.5 : pour le préfixe "do", la liste
/// place `douleur` avant `dormir` avant `docteur`.
///
/// Une trentaine de mots suffit pour ce spike ; ce vocabulaire est
/// remplaçable via `WordPredictor(vocabulary: ...)` par une version
/// suivante qui personnaliserait la liste par patient (section 10.4,
/// 20.2/20.3).
const List<String> defaultPatientVocabulary = [
  'douleur',
  'mal',
  'soif',
  'faim',
  'dormir',
  'fatigué',
  'docteur',
  'infirmière',
  'aide',
  'merci',
  'oui',
  'non',
  'froid',
  'chaud',
  'respirer',
  'tousser',
  'nausée',
  'vomir',
  'uriner',
  'toilettes',
  'position',
  'tourner',
  'redresser',
  'oreiller',
  'couverture',
  'lumière',
  'bruit',
  'silence',
  'famille',
  'seul',
  'peur',
  'stress',
  'calme',
  'sommeil',
  'réveil',
  'eau',
  'manger',
  'boire',
  'médicament',
  'piqûre',
];

/// Service de prédiction de mots du mode expert (section 8.5).
///
/// Objectif de la spec : "réduire le nombre de sélections nécessaires" en
/// proposant, à partir du préfixe en cours de saisie, jusqu'à quelques
/// mots complets que le patient peut valider directement plutôt que de
/// continuer lettre par lettre (voir `ExpertTextComposer.applySuggestion`).
///
/// Algorithme volontairement simple pour ce spike : un filtrage par
/// préfixe (insensible à la casse) sur [defaultPatientVocabulary] (ou un
/// vocabulaire injecté), qui préserve l'ordre du vocabulaire source. Il
/// n'y a ni score de fréquence dynamique ni apprentissage des usages —
/// affinable en version suivante (section 20.2/20.3, ex. historique
/// d'usage par patient, vocabulaire personnalisé par l'aidant).
class WordPredictor {
  final List<String> _vocabulary;

  /// Utilise [vocabulary] si fourni, sinon [defaultPatientVocabulary].
  ///
  /// Le paramètre existe pour permettre à une version suivante d'injecter
  /// un vocabulaire personnalisé par patient (section 10.4) sans changer
  /// cette classe.
  const WordPredictor({List<String>? vocabulary})
      : _vocabulary = vocabulary ?? defaultPatientVocabulary;

  /// Retourne jusqu'à [maxSuggestions] mots du vocabulaire commençant par
  /// [prefix] (insensible à la casse), dans l'ordre de pertinence du
  /// vocabulaire source.
  ///
  /// Retourne une liste vide pour un [prefix] vide : les suggestions ne
  /// s'affichent qu'une fois au moins une lettre saisie (cohérent avec les
  /// exemples "do"/"inf" de la section 8.5, jamais un préfixe vide).
  List<String> suggest(String prefix, {int maxSuggestions = 3}) {
    if (prefix.isEmpty) return const [];
    final normalized = prefix.toLowerCase();
    final matches = <String>[];
    for (final word in _vocabulary) {
      if (word.startsWith(normalized)) {
        matches.add(word);
        if (matches.length == maxSuggestions) break;
      }
    }
    return matches;
  }
}
