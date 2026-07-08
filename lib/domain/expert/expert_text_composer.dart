import 'package:eyevoice/domain/expert/letter_group.dart';

/// État de composition de texte du mode expert
/// (SPECIFICATIONS_FONCTIONNELLES.md section 8, en particulier 8.6).
///
/// Ce composeur est volontairement un état mutable simple (pas de
/// `copyWith` immuable, pas de `ChangeNotifier`/`Stream`) : le câblage
/// réactif (Riverpod `Notifier`/`StateNotifier`) sera ajouté par
/// flutter-ui-engineer autour de cette classe, comme cela a été fait pour
/// `ActionResolver`/`NavigationHistory` en Phase 1a/2. `ExpertTextComposer`
/// n'a aucune dépendance Flutter, UI ou minuterie : il expose uniquement
/// des opérations atomiques (ajouter une lettre, effacer, espacer,
/// réinitialiser) et un texte courant lisible à tout instant via [text].
///
/// Le mot ou la phrase composée est le texte à transmettre à `SpeakAction`
/// (`lib/domain/actions/action_result.dart`) lorsque le patient valide
/// (section 8.6 : "valider le mot ou la phrase") — cette validation
/// elle-même (construire le `SpeakAction` et déclencher le TTS) reste du
/// ressort de l'appelant UI, pas de ce composeur.
class ExpertTextComposer {
  String _text = '';

  /// Texte composé courant (mots + espaces).
  String get text => _text;

  /// Mot en cours de saisie : portion de [text] après le dernier espace.
  ///
  /// Sert de préfixe à `WordPredictor` (section 8.5). Vide si [text] est
  /// vide ou se termine déjà par un espace.
  String get currentWord {
    final lastSpace = _text.lastIndexOf(' ');
    return lastSpace == -1 ? _text : _text.substring(lastSpace + 1);
  }

  /// Ajoute [letter] au texte courant (section 8.6 : "ajouter une
  /// lettre").
  ///
  /// [letter] doit être une unique lettre A-Z (insensible à la casse),
  /// cohérente avec les groupes de [LetterGroup] — c'est cette même
  /// contrainte que valide [LetterGroup.groupOf]. Les lettres sont
  /// stockées en minuscule pour produire un texte directement
  /// lisible/prononçable (ex. "douleur" plutôt que "DOULEUR").
  void addLetter(String letter) {
    if (LetterGroup.groupOf(letter) == null) {
      throw ArgumentError.value(
        letter,
        'letter',
        'doit être une lettre A-Z unique',
      );
    }
    _text += letter.toLowerCase();
  }

  /// Efface le dernier caractère (lettre ou espace) du texte courant
  /// (section 8.6 : "effacer la dernière lettre").
  ///
  /// Ne fait rien si [text] est déjà vide, pour rester cohérent avec le
  /// comportement volontairement tolérant de `NavigationHistory.pop` : un
  /// patient fatigué ne doit jamais se retrouver bloqué par une action
  /// sans effet observable.
  void deleteLastLetter() {
    if (_text.isEmpty) return;
    _text = _text.substring(0, _text.length - 1);
  }

  /// Insère un espace pour terminer le mot courant (section 8.6 :
  /// "insérer un espace").
  ///
  /// Ignoré si [text] est vide ou se termine déjà par un espace, pour
  /// éviter les espaces multiples ou un espace en début de phrase.
  void addSpace() {
    if (_text.isEmpty || _text.endsWith(' ')) return;
    _text += ' ';
  }

  /// Remplace le mot en cours de saisie ([currentWord]) par [suggestion]
  /// complète, puis ajoute un espace pour préparer le mot suivant.
  ///
  /// C'est le mécanisme qui traduit la prédiction de mots (section 8.5,
  /// `WordPredictor`) en gain réel de sélections : le patient choisit une
  /// suggestion au lieu de continuer lettre par lettre. Ignoré si
  /// [suggestion] est vide.
  void applySuggestion(String suggestion) {
    if (suggestion.isEmpty) return;
    final lastSpace = _text.lastIndexOf(' ');
    final prefix = lastSpace == -1 ? '' : _text.substring(0, lastSpace + 1);
    _text = '$prefix$suggestion ';
  }

  /// Réinitialise le texte composé (nouvelle phrase).
  void reset() {
    _text = '';
  }

  @override
  String toString() => 'ExpertTextComposer(text: $_text)';
}
